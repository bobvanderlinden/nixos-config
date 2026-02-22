import * as net from "net";

export const SessionStatusPlugin = async ({ $ }) => {
  const uid = process.getuid?.() ?? (await $`id -u`.quiet().text()).trim();
  const socketPath = `/run/user/${uid}/opencode-sessions.sock`;
  const windowAddress = process.env.HYPR_WINDOW_ADDRESS ?? null;

  // In-memory session state: sessionId -> { info, status }
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
          sessionId,
          windowAddress,
          state: session.status?.type ?? "idle",
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

  async function updateSession(sessionId, updates) {
    sessions.set(sessionId, { ...sessions.get(sessionId), ...updates });
    const session = sessions.get(sessionId);
    send({
      type: "update",
      sessionId,
      windowAddress,
      state: session.status?.type ?? "idle",
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
          await updateSession(event.properties.sessionID, { status: event.properties.status });
          break;
        }
        case "session.deleted": {
          const id = event.properties.info.id;
          sessions.delete(id);
          send({ type: "remove", sessionId: id });
          break;
        }
      }
    },
  };
};
