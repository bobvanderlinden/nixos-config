import { spawn } from "child_process";

/**
 * Holds a systemd sleep inhibitor lock while any OpenCode session is actively
 * running, preventing the system from suspending or hibernating mid-task
 * (including on laptop lid close). Only sleep is inhibited, not idle, so the
 * screen is still free to dim, blank and lock while an agent runs.
 *
 * A session is considered active when it is busy or retrying AND it is not
 * waiting for the user to answer a question. When the AI uses the "question"
 * tool the agent is paused - the user must respond - so the lock is released.
 *
 * The lock is acquired by spawning `systemd-inhibit ... cat` with a pipe on
 * stdin. systemd grants the inhibitor for the lifetime of the wrapped command
 * (`cat`). `cat` exits when its stdin reaches EOF, which happens when the
 * write end of the pipe is closed - either explicitly by releaseInhibitLock()
 * or automatically by the kernel when the parent process dies (even SIGKILL).
 * This ensures the lock is always released, even on a hard kill.
 */
export const SystemdInhibitPlugin = async ({ client }) => {
  // Per-session state: sessionId -> { isBusy: boolean, hasQuestion: boolean, pendingPermissions: Set<string> }
  const sessions = new Map();
  const ignoredSessionIds = new Set();

  let inhibitorProcess = null;

  function isSessionActive({ isBusy, hasQuestion, pendingPermissions }) {
    return isBusy && !hasQuestion && pendingPermissions.size === 0;
  }

  function setRootSession(sessionId, updates) {
    ignoredSessionIds.delete(sessionId);
    const current = sessions.get(sessionId) ?? {
      isBusy: false,
      hasQuestion: false,
      pendingPermissions: new Set(),
    };
    sessions.set(sessionId, { ...current, ...updates });
    update();
  }

  function removeSession(sessionId) {
    sessions.delete(sessionId);
    update();
  }

  async function hydrateRootSession(sessionId, updates) {
    if (ignoredSessionIds.has(sessionId)) return;

    try {
      const { data: info } = await client.session.get({
        path: { id: sessionId },
        throwOnError: true,
      });
      if (info.parentID) {
        ignoredSessionIds.add(sessionId);
        removeSession(sessionId);
        return;
      }

      setRootSession(sessionId, updates);
    } catch {
      // Ignore sessions that disappeared between the event and the lookup.
    }
  }

  function updateOrHydrateRootSession(sessionId, updates) {
    const session = sessions.get(sessionId);
    if (session) {
      setRootSession(sessionId, updates(session));
      return true;
    }

    if (ignoredSessionIds.has(sessionId)) return true;
    void hydrateRootSession(sessionId, updates(null));
    return false;
  }

  function acquireInhibitLock() {
    if (inhibitorProcess !== null) return;

    inhibitorProcess = spawn(
      "systemd-inhibit",
      [
        "--what=sleep",
        "--who=opencode",
        "--why=AI agent is running",
        "--mode=block",
        "cat",
      ],
      // "pipe" on stdin: we hold the write end open. When this process dies
      // (including SIGKILL), the kernel closes the write end -> cat gets EOF
      // -> exits -> systemd-inhibit releases the inhibitor lock.
      { stdio: ["pipe", "ignore", "ignore"], detached: false },
    );

    inhibitorProcess.on("exit", () => {
      // Unexpected exit - clear the reference so a future busy event
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
          const isBusy = status.type === "busy" || status.type === "retry";

          updateOrHydrateRootSession(sessionID, (session) => ({
            isBusy,
            // Mirror session-status.js: clear question state on a new busy/retry
            // status as a safety net in case the question tool's completed event
            // was missed.
            hasQuestion: session && !isBusy ? session.hasQuestion : false,
            pendingPermissions: session && isBusy ? session.pendingPermissions : new Set(),
          }));
          break;
        }

        case "session.created":
        case "session.updated": {
          const { info } = event.properties;
          if (info.parentID) {
            ignoredSessionIds.add(info.id);
            removeSession(info.id);
            break;
          }

          const current = sessions.get(info.id);
          setRootSession(info.id, {
            isBusy: current?.isBusy ?? false,
            hasQuestion: current?.hasQuestion ?? false,
            pendingPermissions: current?.pendingPermissions ?? new Set(),
          });
          break;
        }

        case "message.part.updated": {
          const { part } = event.properties;
          if (part.type !== "tool" || part.tool !== "question") break;

          const hasQuestion =
            part.state.status === "pending" || part.state.status === "running";
          updateOrHydrateRootSession(part.sessionID, () => ({ hasQuestion }));
          break;
        }

        case "session.idle": {
          const { sessionID } = event.properties;
          ignoredSessionIds.delete(sessionID);
          removeSession(sessionID);
          break;
        }

        case "permission.asked": {
          const { sessionID, id } = event.properties;
          updateOrHydrateRootSession(sessionID, (session) => {
            const pendingPermissions = new Set(session?.pendingPermissions ?? []);
            pendingPermissions.add(id);
            return { pendingPermissions };
          });
          break;
        }

        case "permission.replied": {
          const { sessionID, requestID } = event.properties;
          const session = sessions.get(sessionID);
          if (!session) break;

          const pendingPermissions = new Set(session.pendingPermissions);
          pendingPermissions.delete(requestID);
          setRootSession(sessionID, { pendingPermissions });
          break;
        }

        case "session.deleted": {
          const { info } = event.properties;
          ignoredSessionIds.delete(info.id);
          removeSession(info.id);
          break;
        }
      }
    },
  };
};
