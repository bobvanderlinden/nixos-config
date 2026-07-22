import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent"
import { basename } from "node:path"

const NOTIFY_TIMEOUT_MS = 2_000
const FALLBACK_NOTIFY_ID = 42424242

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

  await pi.exec("hypr-notify", argumentsList, { timeout: NOTIFY_TIMEOUT_MS })
}

export default function (pi: ExtensionAPI) {
  pi.on("agent_end", async (_event, context) => {
    if (await isWindowFocused(pi)) return

    const key = sessionKey(context)
    await sendDesktopNotification(
      pi,
      deriveNotifyId(key),
      "Pi finished",
      sessionTitle(pi, context),
      true,
    )
  })
}
