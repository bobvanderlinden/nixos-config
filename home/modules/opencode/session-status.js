import * as net from "net";

export const SessionStatusPlugin = async ({ $ }) => {
  const uid = process.getuid?.() ?? (await $`id -u`.quiet().text()).trim();
  const socketPath = `/run/user/${uid}/statebus-pub.sock`;
  const windowAddress = process.env.HYPR_WINDOW_ADDRESS ?? null;

  // In-memory session state: sessionId -> { info, status, hasError, pendingPermissions }
  // pendingPermissions is a Set of permission IDs waiting for a reply.
  const sessions = new Map();

  let socket = null;

  function send(msg) {
    if (socket?.writable) {
      socket.write(JSON.stringify(msg) + "\n");
    }
  }

  function connect() {
    const s = net.createConnection(socketPath);

    s.on("connect", () => {
      socket = s;
      // Re-publish all known sessions on (re)connect.
      for (const [sessionId, session] of sessions) {
        s.write(JSON.stringify({
          type: "update",
          key: sessionId,
          windowAddress,
          state: deriveState(session),
          title: session.info?.title ?? "",
        }) + "\n");
      }
    });

    s.on("close", () => {
      socket = null;
      // Retry connection after a short delay.
      setTimeout(connect, 2000);
    });

    s.on("error", () => {
      // error always precedes close, so just let close handle retry.
    });
  }

  connect();

  process.on("exit", () => { socket?.destroy(); });
  process.on("SIGINT",  () => { socket?.destroy(); process.exit(0); });
  process.on("SIGTERM", () => { socket?.destroy(); process.exit(0); });

  // State priority: error > permission > retry > busy > idle
  function deriveState(session) {
    if (session.hasError)                          return "error";
    if (session.pendingPermissions?.size > 0)      return "permission";
    return session.status?.type ?? "idle";
  }

  async function updateSession(sessionId, updates) {
    sessions.set(sessionId, { ...sessions.get(sessionId), ...updates });
    const session = sessions.get(sessionId);
    send({
      type: "update",
      key: sessionId,
      windowAddress,
      state: deriveState(session),
      title: session.info?.title ?? "",
    });
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
          const { sessionID, status } = event.properties;
          // A new status event means the session is responsive again — clear any error.
          await updateSession(sessionID, { status, hasError: false });
          break;
        }
        case "session.error": {
          const sessionId = event.properties.sessionID;
          if (!sessionId) break;
          await updateSession(sessionId, { hasError: true });
          break;
        }
        case "permission.updated": {
          const { sessionID, id } = event.properties;
          const session = sessions.get(sessionID) ?? {};
          const permissions = new Set(session.pendingPermissions);
          permissions.add(id);
          await updateSession(sessionID, { pendingPermissions: permissions });
          break;
        }
        case "permission.replied": {
          const { sessionID, permissionID } = event.properties;
          const session = sessions.get(sessionID) ?? {};
          const permissions = new Set(session.pendingPermissions);
          permissions.delete(permissionID);
          await updateSession(sessionID, { pendingPermissions: permissions });
          break;
        }
        case "session.deleted": {
          const id = event.properties.info.id;
          sessions.delete(id);
          send({ type: "remove", key: id });
          break;
        }
      }
    },
  };
};
