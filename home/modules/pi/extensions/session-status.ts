import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent"
import { StringEnum } from "@earendil-works/pi-ai"
import * as net from "node:net"
import { basename } from "node:path"
import { Type } from "typebox"

const RECONNECT_DELAY_MS = 2_000
const MAX_DESCRIPTION_LENGTH = 240
const MAX_LABEL_LENGTH = 32
const STORE_SYMBOL = Symbol.for("bobvanderlinden.pi.sessionStatusStore")

type AgentStatus = "busy" | "idle" | "error"

export type SessionStatusName = "working" | "waiting" | "done" | "error" | "idle"

export type SessionStatusInfo = {
  status: SessionStatusName
  label?: string
  description: string
}

export type SessionStatusListener = (
  statusInfo: SessionStatusInfo | null,
  context: ExtensionContext,
) => void

export type SessionStatusStore = {
  get(): SessionStatusInfo | null
  set(statusInfo: SessionStatusInfo | null, context: ExtensionContext): void
  subscribe(listener: SessionStatusListener): () => void
}

type PublishedSession = {
  key: string
  windowAddress: string | null
  agentStatus: AgentStatus
  title: string
  label: string
  cwd: string
  sessionStatus: SessionStatusName | null
  sessionDescription: string
  updatedAt: number
  todos: unknown[]
}

type GlobalWithSessionStatusStore = typeof globalThis & {
  [STORE_SYMBOL]?: SessionStatusStore
}

export function statusLabel(status: SessionStatusName): string {
  switch (status) {
    case "working":
      return "Working"
    case "waiting":
      return "Waiting"
    case "done":
      return "Done"
    case "error":
      return "Error"
    case "idle":
      return "Idle"
  }
}

export function truncateSessionStatusText(text: string, maxLength = MAX_DESCRIPTION_LENGTH): string {
  const normalizedText = text.replace(/\s+/g, " ").trim()
  if (normalizedText.length <= maxLength) return normalizedText
  return `${normalizedText.slice(0, maxLength - 1).trimEnd()}…`
}

export function formatSessionStatusInfo(statusInfo: SessionStatusInfo): string {
  return `${statusLabel(statusInfo.status)} — ${statusInfo.description}`
}

export function getSessionStatusStore(): SessionStatusStore {
  const globalObject = globalThis as GlobalWithSessionStatusStore
  if (globalObject[STORE_SYMBOL]) return globalObject[STORE_SYMBOL]

  let currentStatusInfo: SessionStatusInfo | null = null
  const listeners = new Set<SessionStatusListener>()

  const store: SessionStatusStore = {
    get() {
      return currentStatusInfo
    },

    set(statusInfo, context) {
      currentStatusInfo = statusInfo
      for (const listener of listeners) listener(currentStatusInfo, context)
    },

    subscribe(listener) {
      listeners.add(listener)
      return () => {
        listeners.delete(listener)
      }
    },
  }

  globalObject[STORE_SYMBOL] = store
  return store
}

export default function (pi: ExtensionAPI) {
  const uid = process.getuid?.() ?? Number(process.env.UID ?? 0)
  const socketPath = `/run/user/${uid}/statebus-pub.sock`
  const windowAddress = process.env.HYPR_WINDOW_ADDRESS ?? null
  const statusStore = getSessionStatusStore()

  let socket: net.Socket | null = null
  let reconnectTimer: NodeJS.Timeout | null = null
  let currentSession: PublishedSession | null = null
  let currentStatusInfo = statusStore.get()
  let currentLabel = ""
  let shuttingDown = false

  function sessionKey(context: ExtensionContext): string {
    return context.sessionManager.getSessionFile() ?? `${context.cwd}:${process.pid}`
  }

  function sessionTitle(context: ExtensionContext): string {
    return pi.getSessionName() ?? basename(context.cwd) ?? ""
  }

  function sessionLabel(context: ExtensionContext): string {
    if (!currentLabel) currentLabel = basename(context.cwd) ?? ""
    return currentLabel
  }

  function updateTerminalTitle(context: ExtensionContext) {
    if (context.mode !== "tui") return

    context.ui.setTitle(["pi", sessionTitle(context)].filter(Boolean).join(" — "))
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
      state: currentSession.agentStatus,
      agentStatus: currentSession.agentStatus,
      // Legacy name used by the previous quickshell integration.
      agentState: currentSession.agentStatus,
      title: currentSession.title,
      label: currentSession.label,
      cwd: currentSession.cwd,
      sessionStatus: currentSession.sessionStatus,
      // Legacy name used by the previous quickshell integration.
      sessionState: currentSession.sessionStatus,
      sessionDescription: currentSession.sessionDescription,
      updatedAt: currentSession.updatedAt,
      // Legacy field for existing quickshell versions.
      description: currentSession.sessionDescription,
      todos: currentSession.todos,
    })
  }

  function updateSession(context: ExtensionContext, agentStatus: AgentStatus) {
    currentSession = {
      key: sessionKey(context),
      windowAddress,
      agentStatus,
      title: sessionTitle(context),
      label: sessionLabel(context),
      cwd: context.cwd,
      sessionStatus: currentStatusInfo?.status ?? null,
      sessionDescription: currentStatusInfo?.description ?? "",
      updatedAt: Date.now(),
      todos: currentSession?.todos ?? [],
    }
    updateTerminalTitle(context)
    publishCurrentSession()
  }

  function updateSessionStatusInfo(
    context: ExtensionContext,
    statusInfo: SessionStatusInfo | null,
  ) {
    currentStatusInfo = statusInfo
    if (statusInfo?.label) currentLabel = statusInfo.label
    if (!currentSession) return

    currentSession = {
      ...currentSession,
      key: sessionKey(context),
      title: sessionTitle(context),
      label: sessionLabel(context),
      cwd: context.cwd,
      sessionStatus: currentStatusInfo?.status ?? null,
      sessionDescription: currentStatusInfo?.description ?? "",
      updatedAt: Date.now(),
    }
    updateTerminalTitle(context)
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
    unsubscribeFromSessionStatus()
    if (reconnectTimer) {
      clearTimeout(reconnectTimer)
      reconnectTimer = null
    }
    removeCurrentSession()
    socket?.destroy()
    socket = null
  }

  const unsubscribeFromSessionStatus = statusStore.subscribe((statusInfo, context) => {
    updateSessionStatusInfo(context, statusInfo)
  })

  pi.registerTool({
    name: "set_session_status",
    label: "Set Session Status",
    description: "Set the current session status, compact label, and user-facing progress summary.",
    promptSnippet: "Set the current session status and a short user-facing summary.",
    promptGuidelines: [
      "Use set_session_status before finishing a user request when a concise user-facing status summary would be useful.",
      "The label is optional. Use it for a short stable session name shown in compact UI.",
      "The set_session_status description should be written for the user and summarize what the session is doing, waiting for, or just completed in one short sentence.",
    ],
    parameters: Type.Object({
      status: StringEnum(["working", "waiting", "done", "error", "idle"] as const, {
        description: "Current user-facing status of the session.",
      }),
      label: Type.Optional(Type.String({
        description: "Short stable label for this session, used in compact UI. Omit it to keep the current label.",
        maxLength: MAX_LABEL_LENGTH,
      })),
      description: Type.String({
        description: "Short user-facing description of the current session status.",
        maxLength: MAX_DESCRIPTION_LENGTH,
      }),
    }),
    async execute(_toolCallId, parameters, _signal, _onUpdate, context) {
      const statusInfo: SessionStatusInfo = {
        status: parameters.status,
        label: parameters.label?.trim() || undefined,
        description: truncateSessionStatusText(parameters.description),
      }
      statusStore.set(statusInfo, context)

      return {
        content: [
          {
            type: "text",
            text: `Session status set to ${formatSessionStatusInfo(statusInfo)}`,
          },
        ],
        details: statusInfo,
      }
    },
  })

  pi.on("session_start", async (_event, context) => {
    currentLabel = basename(context.cwd) ?? ""
    statusStore.set(null, context)
    connect()
    updateSession(context, "idle")
  })

  pi.on("session_info_changed", async (_event, context) => {
    updateSession(context, currentSession?.agentStatus ?? "idle")
  })

  pi.on("agent_start", async (_event, context) => {
    updateSession(context, "busy")
  })

  pi.on("agent_end", async (_event, context) => {
    updateSession(context, "idle")
  })

  pi.on("session_shutdown", async () => {
    shutdown()
  })
}
