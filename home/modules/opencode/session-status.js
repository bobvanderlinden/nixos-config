import * as net from "net";

export const SessionStatusPlugin = async ({ $ }) => {
  const uid = process.getuid?.() ?? (await $`id -u`.quiet().text()).trim();
  const socketPath = `/run/user/${uid}/statebus-pub.sock`;
  const windowAddress = process.env.HYPR_WINDOW_ADDRESS ?? null;

  // In-memory session state: sessionId -> { info, status, hasError, pendingPermissions, question, todos }
  // pendingPermissions is a Set of permission IDs waiting for a reply.
  // question is "pending" while the AI's "question" tool call is pending/running, otherwise null.
  // todos is the latest array of Todo objects from todo.updated events.
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
          todos: session.todos ?? [],
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

  // State priority: error > permission > question > retry > busy > idle
  function deriveState(session) {
    if (session.hasError)                          return "error";
    if (session.pendingPermissions?.size > 0)      return "permission";
    if (session.question === "pending")            return "question";
    return session.status?.type ?? "idle";
  }

  async function updateSession(sessionId, updates) {
    const merged = { ...sessions.get(sessionId), ...updates };
    for (const key of Object.keys(merged)) {
      if (merged[key] === null) delete merged[key];
    }
    sessions.set(sessionId, merged);
    const session = sessions.get(sessionId);
    send({
      type: "update",
      key: sessionId,
      windowAddress,
      state: deriveState(session),
      title: session.info?.title ?? "",
      todos: session.todos ?? [],
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
          // Also clear question on busy/retry as a safety net (the question tool's
          // completed state should handle this, but guard against missed events).
          const updates = { status, hasError: false };
          if (status.type === "busy" || status.type === "retry") {
            updates.question = null;
          }
          await updateSession(sessionID, updates);
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
        case "message.part.updated": {
          // The AI calls the built-in "question" tool when it asks the user something.
          // Track its ToolPart status: pending/running = waiting for answer, completed/error = done.
          const { part } = event.properties;
          if (part.type === "tool" && part.tool === "question") {
            const isPending = part.state.status === "pending" || part.state.status === "running";
            await updateSession(part.sessionID, { question: isPending ? "pending" : null });
          }
          break;
        }
        case "todo.updated": {
          const { sessionID, todos } = event.properties;
          await updateSession(sessionID, { todos });
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
