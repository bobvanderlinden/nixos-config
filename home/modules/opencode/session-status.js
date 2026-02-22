import * as fs from "fs";
import * as path from "path";

export const SessionStatusPlugin = async ({ $ }) => {
  // Each running OpenCode instance writes a JSON file here:
  //   /run/user/<uid>/agent-sessions/<sessionId>.json
  // Content: { sessionId, windowAddress, state, title }
  // state mirrors SessionStatus.type: "idle", "busy", or "retry".
  const uid = process.getuid?.() ?? (await $`id -u`.quiet().text()).trim();
  const agentDir = `/run/user/${uid}/agent-sessions`;
  const windowAddress = process.env.HYPR_WINDOW_ADDRESS ?? null;

  // In-memory session state: sessionId -> { info: Session, status: SessionStatus }
  const sessions = new Map();

  // Track files written by this instance for cleanup on exit.
  const ownFiles = new Set();

  // Synchronous cleanup — must be sync to run in exit handlers.
  function deleteOwnFiles() {
    for (const file of ownFiles) {
      try { fs.unlinkSync(file); } catch { }
    }
  }

  process.on("exit",    deleteOwnFiles);
  process.on("SIGINT",  () => { deleteOwnFiles(); process.exit(0); });
  process.on("SIGTERM", () => { deleteOwnFiles(); process.exit(0); });

  async function updateSession(sessionId, updates) {
    sessions.set(sessionId, { ...sessions.get(sessionId), ...updates });
    const session = sessions.get(sessionId);
    try {
      fs.mkdirSync(agentDir, { recursive: true });
      const data = JSON.stringify({
        sessionId,
        windowAddress,
        state: session.status?.type ?? "idle",
        title: session.info?.title ?? "",
      });
      const file = path.join(agentDir, `${sessionId}.json`);
      fs.writeFileSync(file, data);
      ownFiles.add(file);
      // Touch to update mtime — AgentState.qml uses mtime to detect stale files.
      const now = new Date();
      fs.utimesSync(file, now, now);
    } catch (e) {
      console.error("[session-status] updateSession failed:", e);
    }
  }

  return {
    event: async ({ event }) => {
      switch (event.type) {
        case "session.created":
        case "session.updated": {
          await updateSession(event.properties.info.id, { info: event.properties.info });
          break;
        }
        case "session.status": {
          await updateSession(event.properties.sessionID, { status: event.properties.status });
          break;
        }
        case "session.deleted": {
          const id = event.properties.info.id;
          sessions.delete(id);
          const file = path.join(agentDir, `${id}.json`);
          ownFiles.delete(file);
          try {
            fs.unlinkSync(file);
          } catch (e) {
            console.error("[session-status] session.deleted unlink failed:", e);
          }
          break;
        }
      }
    },
  };
};
