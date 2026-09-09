import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"
import { spawn, type ChildProcess } from "node:child_process"

export default function (pi: ExtensionAPI) {
  let inhibitorProcess: ChildProcess | null = null

  function acquireInhibitLock() {
    if (inhibitorProcess !== null) return

    inhibitorProcess = spawn(
      "systemd-inhibit",
      [
        "--what=sleep",
        "--who=pi",
        "--why=AI agent is running",
        "--mode=block",
        "cat",
      ],
      {
        // Hold the write end of stdin open. When it closes, cat receives EOF and
        // systemd-inhibit releases the sleep inhibitor lock.
        stdio: ["pipe", "ignore", "ignore"],
        detached: false,
      },
    )

    inhibitorProcess.on("exit", () => {
      inhibitorProcess = null
    })
  }

  function releaseInhibitLock() {
    if (inhibitorProcess === null) return

    inhibitorProcess.stdin?.destroy()
    inhibitorProcess = null
  }

  pi.on("agent_start", async () => {
    acquireInhibitLock()
  })

  pi.on("agent_end", async () => {
    releaseInhibitLock()
  })

  pi.on("session_shutdown", async () => {
    releaseInhibitLock()
  })
}
