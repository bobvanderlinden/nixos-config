import * as fs from "fs/promises";
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

  async function updateSession(sessionId, updates) {
    sessions.set(sessionId, { ...sessions.get(sessionId), ...updates });
    const session = sessions.get(sessionId);
    try {
      await fs.mkdir(agentDir, { recursive: true });
      const data = JSON.stringify({
        sessionId,
        windowAddress,
        state: session.status?.type ?? "idle",
        title: session.info?.title ?? "",
      });
      const file = path.join(agentDir, `${sessionId}.json`);
      await fs.writeFile(file, data);
      // Touch to update mtime — AgentState.qml uses mtime to detect stale files.
      const now = new Date();
      await fs.utimes(file, now, now);
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
          try {
            await fs.unlink(path.join(agentDir, `${id}.json`));
          } catch (e) {
            console.error("[session-status] session.deleted unlink failed:", e);
          }
          break;
        }
      }
    },
  };
};
