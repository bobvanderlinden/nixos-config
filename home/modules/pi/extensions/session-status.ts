import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent"
import * as net from "node:net"
import { basename } from "node:path"

const RECONNECT_DELAY_MS = 2_000

type AgentState = "busy" | "idle" | "error"

type SessionState = {
  key: string
  windowAddress: string | null
  state: AgentState
  title: string
  todos: unknown[]
}

export default function (pi: ExtensionAPI) {
  const uid = process.getuid?.() ?? Number(process.env.UID ?? 0)
  const socketPath = `/run/user/${uid}/statebus-pub.sock`
  const windowAddress = process.env.HYPR_WINDOW_ADDRESS ?? null

  let socket: net.Socket | null = null
  let reconnectTimer: NodeJS.Timeout | null = null
  let currentSession: SessionState | null = null
  let shuttingDown = false

  function sessionKey(context: ExtensionContext): string {
    return context.sessionManager.getSessionFile() ?? `${context.cwd}:${process.pid}`
  }

  function sessionTitle(context: ExtensionContext): string {
    return pi.getSessionName() ?? basename(context.cwd) ?? ""
  }

  function writeMessage(message: unknown) {
    if (!socket?.writable) return
    socket.write(`${JSON.stringify(message)}\n`)
  }

  function publishCurrentSession() {
    if (!currentSession) return
    writeMessage({
      type: "update",
      key: currentSession.key,
      windowAddress: currentSession.windowAddress,
      state: currentSession.state,
      title: currentSession.title,
      todos: currentSession.todos,
    })
  }

  function updateSession(context: ExtensionContext, state: AgentState) {
    currentSession = {
      key: sessionKey(context),
      windowAddress,
      state,
      title: sessionTitle(context),
      todos: currentSession?.todos ?? [],
    }
    publishCurrentSession()
  }

  function removeCurrentSession() {
    if (!currentSession) return
    writeMessage({ type: "remove", key: currentSession.key })
    currentSession = null
  }

  function scheduleReconnect() {
    if (reconnectTimer) return
    reconnectTimer = setTimeout(() => {
      reconnectTimer = null
      connect()
    }, RECONNECT_DELAY_MS)
  }

  function connect() {
    if (socket || reconnectTimer) return

    const nextSocket = net.createConnection(socketPath)

    nextSocket.on("connect", () => {
      socket = nextSocket
      publishCurrentSession()
    })

    nextSocket.on("close", () => {
      if (socket === nextSocket) socket = null
      if (!shuttingDown) scheduleReconnect()
    })

    nextSocket.on("error", () => {
      // The close event handles reconnects.
    })
  }

  function shutdown() {
    shuttingDown = true
    if (reconnectTimer) {
      clearTimeout(reconnectTimer)
      reconnectTimer = null
    }
    removeCurrentSession()
    socket?.destroy()
    socket = null
  }

  pi.on("session_start", async (_event, context) => {
    connect()
    updateSession(context, "idle")
  })

  pi.on("agent_start", async (_event, context) => {
    updateSession(context, "busy")
  })

  pi.on("agent_end", async (_event, context) => {
    updateSession(context, "idle")
  })

  pi.on("tool_result", async (event, context) => {
    if (!event.isError) return
    updateSession(context, "error")
  })

  pi.on("session_shutdown", async () => {
    shutdown()
  })
}
