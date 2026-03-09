import { spawn } from "child_process";

/**
 * Holds a systemd sleep/idle inhibitor lock while any OpenCode session is
 * actively running, preventing the system from suspending or going idle
 * mid-task.
 *
 * A session is considered active when it is busy or retrying AND it is not
 * waiting for the user to answer a question. When the AI uses the "question"
 * tool the agent is paused — the user must respond — so the lock is released.
 *
 * The lock is acquired by spawning `systemd-inhibit ... cat` with a pipe on
 * stdin. systemd grants the inhibitor for the lifetime of the wrapped command
 * (`cat`). `cat` exits when its stdin reaches EOF, which happens when the
 * write end of the pipe is closed — either explicitly by releaseInhibitLock()
 * or automatically by the kernel when the parent process dies (even SIGKILL).
 * This ensures the lock is always released, even on a hard kill.
 */
export const SystemdInhibitPlugin = async () => {
  // Per-session state: sessionId -> { isBusy: boolean, hasQuestion: boolean }
  const sessions = new Map();

  let inhibitorProcess = null;

  function isSessionActive({ isBusy, hasQuestion }) {
    return isBusy && !hasQuestion;
  }

  function acquireInhibitLock() {
    if (inhibitorProcess !== null) return;

    inhibitorProcess = spawn(
      "systemd-inhibit",
      [
        "--what=idle:sleep",
        "--who=opencode",
        "--why=AI agent is running",
        "--mode=block",
        "cat",
      ],
      // "pipe" on stdin: we hold the write end open. When this process dies
      // (including SIGKILL), the kernel closes the write end → cat gets EOF
      // → exits → systemd-inhibit releases the inhibitor lock.
      { stdio: ["pipe", "ignore", "ignore"], detached: false },
    );

    inhibitorProcess.on("exit", () => {
      // Unexpected exit — clear the reference so a future busy event
      // can re-acquire the lock.
      inhibitorProcess = null;
    });
  }

  function releaseInhibitLock() {
    if (inhibitorProcess === null) return;
    // Closing stdin sends EOF to cat, which causes it to exit cleanly.
    inhibitorProcess.stdin.destroy();
    inhibitorProcess = null;
  }

  function update() {
    const anyActive = [...sessions.values()].some(isSessionActive);
    if (anyActive) {
      acquireInhibitLock();
    } else {
      releaseInhibitLock();
    }
  }

  process.on("exit", releaseInhibitLock);
  process.on("SIGINT", () => {
    releaseInhibitLock();
    process.exit(0);
  });
  process.on("SIGTERM", () => {
    releaseInhibitLock();
    process.exit(0);
  });

  return {
    event: async ({ event }) => {
      switch (event.type) {
        case "session.status": {
          const { sessionID, status } = event.properties;
          const session = sessions.get(sessionID) ?? { isBusy: false, hasQuestion: false };
          const isBusy = status.type === "busy" || status.type === "retry";
          // Mirror session-status.js: clear question state on a new busy/retry
          // status as a safety net in case the question tool's completed event
          // was missed.
          const hasQuestion = isBusy ? false : session.hasQuestion;
          sessions.set(sessionID, { isBusy, hasQuestion });
          update();
          break;
        }

        case "message.part.updated": {
          const { part } = event.properties;
          if (part.type === "tool" && part.tool === "question") {
            const session = sessions.get(part.sessionID);
            if (!session) break;
            const hasQuestion =
              part.state.status === "pending" || part.state.status === "running";
            sessions.set(part.sessionID, { ...session, hasQuestion });
            update();
          }
          break;
        }

        case "session.idle": {
          const { sessionID } = event.properties;
          sessions.delete(sessionID);
          update();
          break;
        }

        case "session.deleted": {
          const { info } = event.properties;
          sessions.delete(info.id);
          update();
          break;
        }
      }
    },
  };
};
