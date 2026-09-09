import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent"
import { spawn } from "node:child_process"
import { basename } from "node:path"

const NOTIFY_TIMEOUT_MS = 2_000
const FALLBACK_NOTIFY_ID = 42424242
const MAX_DESCRIPTION_LENGTH = 240
const STORE_SYMBOL = Symbol.for("bobvanderlinden.pi.sessionStatusStore")

type SessionStatusName = "working" | "waiting" | "done" | "error" | "idle"

type SessionStatusInfo = {
  status: SessionStatusName
  description: string
}

type SessionStatusStore = {
  get(): SessionStatusInfo | null
}

type GlobalWithSessionStatusStore = typeof globalThis & {
  [STORE_SYMBOL]?: SessionStatusStore
}

function getSessionStatusInfo(): SessionStatusInfo | null {
  return ((globalThis as GlobalWithSessionStatusStore)[STORE_SYMBOL]?.get() ?? null)
}

function statusLabel(status: SessionStatusName): string {
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

function truncateText(text: string, maxLength = MAX_DESCRIPTION_LENGTH): string {
  const normalizedText = text.replace(/\s+/g, " ").trim()
  if (normalizedText.length <= maxLength) return normalizedText
  return `${normalizedText.slice(0, maxLength - 1).trimEnd()}…`
}

function formatStatusInfo(statusInfo: SessionStatusInfo): string {
  return `${statusLabel(statusInfo.status)} — ${statusInfo.description}`
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

function notificationBody(pi: ExtensionAPI, context: ExtensionContext): string {
  const statusInfo = getSessionStatusInfo()
  if (statusInfo) return truncateText(formatStatusInfo(statusInfo))

  return truncateText(`${statusLabel("idle")} — ${fallbackDescription(pi, context)}`)
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
  pi.on("agent_settled", async (_event, context) => {
    if (await isWindowFocused(pi)) return

    const key = sessionKey(context)
    await sendDesktopNotification(
      pi,
      deriveNotifyId(key),
      "Pi session status",
      notificationBody(pi, context),
      true,
    )
  })
}
