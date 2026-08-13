import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent"
import { pathToFileURL } from "node:url"

function reportCurrentDirectory(context: ExtensionContext) {
  // OSC 7 lets supporting terminal emulators associate this terminal with the
  // current process directory. pathToFileURL encodes spaces, control characters,
  // and escape bytes so an unusual directory name cannot alter the terminal stream.
  const directoryUrl = pathToFileURL(context.cwd).href
  process.stdout.write(`\u001B]7;${directoryUrl}\u0007`)
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, context) => {
    // Do not corrupt output produced by print or JSON modes. Pi currently has no
    // working-directory-change lifecycle event; its cwd is fixed for a process.
    if (context.mode !== "tui") return
    reportCurrentDirectory(context)
  })
}
