import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent"
import { StringEnum } from "@earendil-works/pi-ai"
import { spawn } from "node:child_process"
import { basename } from "node:path"
import { Type } from "typebox"

const NOTIFY_TIMEOUT_MS = 2_000
const FALLBACK_NOTIFY_ID = 42424242
const MAX_BODY_LENGTH = 240

type NotificationState = "working" | "waiting" | "done" | "error" | "idle"

type SessionNotification = {
  state: NotificationState
  description: string
}

function deriveNotifyId(text: string): number {
  let notifyId = 0
  for (const character of text) {
    notifyId = (notifyId * 31 + character.charCodeAt(0)) >>> 0
  }
  return notifyId === 0 ? FALLBACK_NOTIFY_ID : notifyId
}

function sessionKey(context: ExtensionContext): string {
  return context.sessionManager.getSessionFile() ?? `${context.cwd}:${process.pid}`
}

function sessionTitle(pi: ExtensionAPI, context: ExtensionContext): string {
  return pi.getSessionName() ?? basename(context.cwd) ?? ""
}

function stateLabel(state: NotificationState): string {
  switch (state) {
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

function truncateText(text: string, maxLength = MAX_BODY_LENGTH): string {
  const normalizedText = text.replace(/\s+/g, " ").trim()
  if (normalizedText.length <= maxLength) return normalizedText
  return `${normalizedText.slice(0, maxLength - 1).trimEnd()}…`
}

function textFromContent(content: unknown): string {
  if (typeof content === "string") return content
  if (!Array.isArray(content)) return ""

  return content
    .map((part) => {
      if (typeof part === "string") return part
      if (!part || typeof part !== "object") return ""
      const maybeText = (part as { text?: unknown }).text
      return typeof maybeText === "string" ? maybeText : ""
    })
    .filter(Boolean)
    .join(" ")
}

function latestUserPrompt(context: ExtensionContext): string {
  const entries = context.sessionManager.getBranch()
  for (let index = entries.length - 1; index >= 0; index -= 1) {
    const entry = entries[index]
    if (entry.type !== "message" || entry.message.role !== "user") continue
    const text = textFromContent(entry.message.content)
    if (text.trim()) return text
  }
  return ""
}

function fallbackDescription(pi: ExtensionAPI, context: ExtensionContext): string {
  return sessionTitle(pi, context) || latestUserPrompt(context) || "Session is idle"
}

function notificationBody(
  pi: ExtensionAPI,
  context: ExtensionContext,
  notification: SessionNotification | null,
): string {
  const state = notification?.state ?? "idle"
  const description = notification?.description || fallbackDescription(pi, context)
  return truncateText(`${stateLabel(state)} — ${description}`)
}

async function isWindowFocused(pi: ExtensionAPI): Promise<boolean> {
  const windowAddress = process.env.HYPR_WINDOW_ADDRESS
  if (!windowAddress) return false

  try {
    const result = await pi.exec("hyprctl", ["activewindow", "-j"], {
      timeout: NOTIFY_TIMEOUT_MS,
    })
    if (result.code !== 0) return false

    const activeWindow = JSON.parse(result.stdout) as { address?: string }
    const activeAddress = activeWindow.address?.replace(/^0x/, "")
    return activeAddress === windowAddress
  } catch {
    return false
  }
}

async function sendDesktopNotification(
  pi: ExtensionAPI,
  notifyId: number,
  summary: string,
  body: string,
  bell: boolean,
) {
  if (bell) {
    await pi.exec("coin", [], { timeout: NOTIFY_TIMEOUT_MS })
  }

  const argumentsList = ["--app-name", "Pi", "--replace-id", String(notifyId)]
  if (bell) argumentsList.push("--bell")
  argumentsList.push(summary, body)

  // hypr-notify must keep running so it can receive the D-Bus action signal
  // when the notification is clicked. pi.exec would wait for it and time out.
  const child = spawn("hypr-notify", argumentsList, {
    detached: true,
    stdio: "ignore",
  })
  child.on("error", () => {
    // The notification is best-effort. Avoid crashing pi if the helper is missing.
  })
  child.unref()
}

export default function (pi: ExtensionAPI) {
  let notification: SessionNotification | null = null

  pi.registerTool({
    name: "set_session_notification",
    label: "Set Session Notification",
    description:
      "Set a short human-readable description of the current Pi session state for desktop notifications.",
    promptSnippet:
      "Set the current session state and a short description for desktop notifications.",
    promptGuidelines: [
      "Use set_session_notification before finishing a user request when a concise state description would make Pi desktop notifications more useful.",
      "The set_session_notification description should be written for the user and summarize what the session is doing, waiting for, or just completed in one short sentence.",
    ],
    parameters: Type.Object({
      state: StringEnum(["working", "waiting", "done", "error", "idle"] as const, {
        description: "Current state of the session.",
      }),
      description: Type.String({
        description: "Short user-facing description of the current session state.",
        maxLength: MAX_BODY_LENGTH,
      }),
    }),
    async execute(_toolCallId, parameters) {
      notification = {
        state: parameters.state,
        description: truncateText(parameters.description),
      }
      return {
        content: [
          {
            type: "text",
            text: `Session notification set to ${stateLabel(notification.state)} — ${notification.description}`,
          },
        ],
        details: notification,
      }
    },
  })

  pi.on("agent_start", async () => {
    notification = null
  })

  pi.on("tool_result", async (event) => {
    if (!event.isError) return
    notification = {
      state: "error",
      description: `Tool ${event.toolName} failed`,
    }
  })

  pi.on("agent_end", async (_event, context) => {
    if (await isWindowFocused(pi)) return

    const key = sessionKey(context)
    await sendDesktopNotification(
      pi,
      deriveNotifyId(key),
      "Pi session state",
      notificationBody(pi, context, notification),
      true,
    )
  })
}
