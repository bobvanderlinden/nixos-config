import { hostname } from "node:os"
import { pathToFileURL } from "node:url"
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"

export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, context) => {
    if (context.mode !== "tui" || !process.stdout.isTTY) return

    // OSC 7 lets terminals inherit Pi's directory when opening windows and tabs.
    const directory = pathToFileURL(context.cwd)
    directory.hostname = hostname()
    process.stdout.write(`\x1b]7;${directory.href}\x1b\\`)
  })
}
