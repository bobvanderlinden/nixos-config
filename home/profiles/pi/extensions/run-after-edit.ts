import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"
import { relative, resolve, sep } from "node:path"

const MAX_OUTPUT_LENGTH = 50 * 1024
const COMMAND_TIMEOUT_MS = 10_000

type FileMutationInput = {
  path?: unknown
}

type Reaction = {
  name: string
  command: string
}

function pathFromToolResult(toolName: string, input: unknown): string | null {
  if (toolName !== "edit" && toolName !== "write") return null
  if (typeof input !== "object" || input === null) return null

  const path = (input as FileMutationInput).path
  return typeof path === "string" ? path : null
}

function selectReaction(path: string): Reaction | null {
  if (path === "home/profiles/hypr/hyprland.lua") {
    return {
      name: "Hyprland configuration check",
      command: "hyprctl reload; hyprctl configerrors",
    }
  }

  if (path.startsWith("home/profiles/quickshell/")) {
    return {
      name: "Quickshell restart and log check",
      command: "systemctl --user restart quickshell; restart_status=$?; journalctl --user --unit quickshell --since '1 minute ago' --no-pager --lines 100; exit $restart_status",
    }
  }

  return null
}

function truncateOutput(output: string): string {
  if (Buffer.byteLength(output, "utf8") <= MAX_OUTPUT_LENGTH) return output
  return `${output.slice(0, MAX_OUTPUT_LENGTH)}\n\n[Output truncated at 50KB]`
}

export default function (pi: ExtensionAPI) {
  pi.on("tool_result", async (event, context) => {
    if (event.isError) return

    const editedPath = pathFromToolResult(event.toolName, event.input)
    if (!editedPath) return

    const projectPath = relative(context.cwd, resolve(context.cwd, editedPath)).split(sep).join("/")
    const reaction = selectReaction(projectPath)
    if (!reaction) return

    try {
      const result = await pi.exec("sh", ["-c", reaction.command], {
        signal: context.signal,
        timeout: COMMAND_TIMEOUT_MS,
      })
      const output = truncateOutput(`${result.stdout}${result.stderr}`).trim()
      const status = result.code === 0 ? "succeeded" : `failed with exit code ${result.code}`
      const message = [
        `${reaction.name} ${status} after editing ${projectPath}.`,
        output || "Command produced no output.",
      ].join("\n")

      return {
        content: [...event.content, { type: "text", text: message }],
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error)
      return {
        content: [...event.content, {
          type: "text",
          text: `${reaction.name} could not run after editing ${projectPath}: ${message}`,
        }],
      }
    }
  })
}
