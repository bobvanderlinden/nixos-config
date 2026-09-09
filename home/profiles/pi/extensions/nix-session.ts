import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent"
import {
  createBashTool,
  createLocalBashOperations,
} from "@earendil-works/pi-coding-agent"
import { StringEnum } from "@earendil-works/pi-ai"
import { Text } from "@earendil-works/pi-tui"
import { spawn } from "node:child_process"
import { Type, type Static } from "typebox"

const CUSTOM_ENTRY_TYPE = "nix-session-packages"
const VOLATILE_ENV_KEYS = new Set(["_", "OLDPWD", "PWD", "SHLVL"])

const nixSessionSchema = Type.Object({
  action: StringEnum(["add", "remove", "list", "clear"] as const),
  packages: Type.Optional(
    Type.Array(
      Type.String({
        description:
          "Nixpkgs package attribute names without the nixpkgs# prefix, for example sqlite, jq, or python312Packages.black.",
      }),
    ),
  ),
})

type NixSessionInput = Static<typeof nixSessionSchema>

type CommandResult = {
  code: number | null
  stdout: Buffer
  stderr: string
}

type NixEnvironment = {
  baseEnv: Record<string, string | undefined>
  overlayEnv: Record<string, string>
}

function normalizePackageName(packageName: string): string {
  let normalized = packageName.trim()
  if (normalized.startsWith("nixpkgs#")) {
    normalized = normalized.slice("nixpkgs#".length)
  }

  if (!/^[A-Za-z0-9][A-Za-z0-9._+-]*$/.test(normalized)) {
    throw new Error(
      `Invalid Nix package name: ${packageName}. Use a nixpkgs attribute name without nixpkgs#, for example sqlite or python312Packages.black.`,
    )
  }

  return normalized
}

function packageReferences(packages: Iterable<string>): string[] {
  return [...packages].map((packageName) => `nixpkgs#${packageName}`)
}

function parseNulEnvironment(stdout: Buffer): Record<string, string> {
  const environment: Record<string, string> = {}

  for (const entry of stdout.toString("utf8").split("\0")) {
    if (!entry) continue
    const separatorIndex = entry.indexOf("=")
    if (separatorIndex === -1) continue

    const key = entry.slice(0, separatorIndex)
    const value = entry.slice(separatorIndex + 1)
    environment[key] = value
  }

  return environment
}

function runCommand(
  command: string,
  argumentsList: string[],
  env: NodeJS.ProcessEnv,
  signal?: AbortSignal,
): Promise<CommandResult> {
  return new Promise((resolve) => {
    const childProcess = spawn(command, argumentsList, {
      env,
      stdio: ["ignore", "pipe", "pipe"],
      signal,
    })

    const stdoutChunks: Buffer[] = []
    let stderr = ""

    childProcess.stdout.on("data", (chunk: Buffer) => {
      stdoutChunks.push(chunk)
    })

    childProcess.stderr.setEncoding("utf8")
    childProcess.stderr.on("data", (chunk) => {
      stderr += chunk
    })

    childProcess.on("error", (error) => {
      resolve({
        code: 1,
        stdout: Buffer.concat(stdoutChunks),
        stderr: stderr || error.message,
      })
    })

    childProcess.on("close", (code) => {
      resolve({ code, stdout: Buffer.concat(stdoutChunks), stderr })
    })
  })
}

async function resolveNixEnvironment(
  packages: Set<string>,
  signal?: AbortSignal,
): Promise<NixEnvironment> {
  if (packages.size === 0) {
    return { baseEnv: {}, overlayEnv: {} }
  }

  const baseEnv = { ...process.env }
  const result = await runCommand(
    "nix",
    [
      "--extra-experimental-features",
      "nix-command flakes",
      "shell",
      ...packageReferences(packages),
      "--command",
      "env",
      "-0",
    ],
    baseEnv,
    signal,
  )

  if (result.code !== 0) {
    throw new Error(
      `nix shell failed for ${[...packages].join(", ")}\n${result.stderr.trim()}`,
    )
  }

  const nixEnv = parseNulEnvironment(result.stdout)
  const overlayEnv: Record<string, string> = {}

  for (const [key, value] of Object.entries(nixEnv)) {
    if (VOLATILE_ENV_KEYS.has(key)) continue
    if (baseEnv[key] === value) continue
    overlayEnv[key] = value
  }

  return { baseEnv, overlayEnv }
}

function materializeEnvironment(
  environment: NodeJS.ProcessEnv,
  nixEnvironment: NixEnvironment,
): NodeJS.ProcessEnv {
  const nextEnvironment: NodeJS.ProcessEnv = { ...environment }

  for (const [key, overlayValue] of Object.entries(nixEnvironment.overlayEnv)) {
    const baseValue = nixEnvironment.baseEnv[key]
    const runtimeValue = environment[key]

    if (baseValue && runtimeValue && overlayValue.includes(baseValue)) {
      nextEnvironment[key] = overlayValue.split(baseValue).join(runtimeValue)
      continue
    }

    nextEnvironment[key] = overlayValue
  }

  return nextEnvironment
}

function formatPackageList(packages: Set<string>): string {
  return packages.size === 0 ? "none" : [...packages].sort().join(", ")
}

function formatAction(input: NixSessionInput): string {
  const action = {
    add: "Adding",
    remove: "Removing",
    list: "Listing",
    clear: "Clearing",
  }[input.action]
  const packages = input.packages?.join(", ")

  return packages ? `${action} ${packages}` : action
}

function updateStatus(context: ExtensionContext, packages: Set<string>) {
  if (!context.hasUI) return
  context.ui.setStatus(
    "nix-session",
    packages.size === 0 ? undefined : `nix: ${formatPackageList(packages)}`,
  )
}

function restorePackagesFromSession(context: ExtensionContext): Set<string> {
  const packages = new Set<string>()

  for (const entry of context.sessionManager.getBranch()) {
    if (entry.type !== "custom" || entry.customType !== CUSTOM_ENTRY_TYPE) continue

    const data = entry.data as { packages?: unknown }
    if (!Array.isArray(data.packages)) continue

    packages.clear()
    for (const packageName of data.packages) {
      if (typeof packageName !== "string") continue
      try {
        packages.add(normalizePackageName(packageName))
      } catch {
        // Ignore stale invalid entries from older extension versions.
      }
    }
  }

  return packages
}

function parseCommandArguments(argumentsText: string): NixSessionInput {
  const parts = argumentsText.split(/\s+/).filter(Boolean)
  const firstPart = parts[0]

  if (!firstPart) return { action: "list" }
  if (firstPart === "list") return { action: "list" }
  if (firstPart === "clear") return { action: "clear" }
  if (firstPart === "add" || firstPart === "remove") {
    return { action: firstPart, packages: parts.slice(1) }
  }

  return { action: "add", packages: parts }
}

export default function (pi: ExtensionAPI) {
  let activePackages = new Set<string>()
  let nixEnvironment: NixEnvironment = { baseEnv: {}, overlayEnv: {} }

  const refreshEnvironment = async (signal?: AbortSignal) => {
    nixEnvironment = await resolveNixEnvironment(activePackages, signal)
  }

  const persistPackages = () => {
    pi.appendEntry(CUSTOM_ENTRY_TYPE, { packages: [...activePackages].sort() })
  }

  const applyAction = async (
    input: NixSessionInput,
    signal?: AbortSignal,
    persist = true,
  ): Promise<string> => {
    const previousPackages = new Set(activePackages)
    const requestedPackages = (input.packages ?? []).map(normalizePackageName)

    if (input.action === "add" && requestedPackages.length === 0) {
      throw new Error("nix_session add requires at least one package name")
    }

    if (input.action === "remove" && requestedPackages.length === 0) {
      throw new Error("nix_session remove requires at least one package name")
    }

    if (input.action === "list") {
      return `Active Nix session packages: ${formatPackageList(activePackages)}`
    }

    if (input.action === "clear") {
      activePackages = new Set()
    }

    if (input.action === "add") {
      activePackages = new Set([...activePackages, ...requestedPackages])
    }

    if (input.action === "remove") {
      activePackages = new Set(activePackages)
      for (const packageName of requestedPackages) {
        activePackages.delete(packageName)
      }
    }

    try {
      await refreshEnvironment(signal)
    } catch (error) {
      activePackages = previousPackages
      nixEnvironment = await resolveNixEnvironment(activePackages, signal).catch(() => ({
        baseEnv: {},
        overlayEnv: {},
      }))
      throw error
    }

    if (persist) persistPackages()
    return `Active Nix session packages: ${formatPackageList(activePackages)}`
  }

  const bashTool = createBashTool(process.cwd(), {
    spawnHook: ({ command, cwd, env }) => ({
      command,
      cwd,
      env: materializeEnvironment(env, nixEnvironment),
    }),
  })

  pi.registerTool({
    ...bashTool,
    execute: async (toolCallId, params, signal, onUpdate) => {
      return bashTool.execute(toolCallId, params, signal, onUpdate)
    },
  })

  pi.registerTool({
    name: "nix_session",
    label: "Nix Session",
    description:
      "Add, remove, list, or clear Nix packages for this Pi session. Use package attribute names without nixpkgs#, for example sqlite, jq, or python312Packages.black. Added packages are injected into future agent bash commands and user ! commands.",
    promptSnippet:
      "Add temporary Nix packages to this Pi session by package name without nixpkgs#",
    promptGuidelines: [
      "Use nix_session when a needed command is missing and can be provided by a Nix package; pass package names without the nixpkgs# prefix.",
    ],
    parameters: nixSessionSchema,
    renderCall(input, theme) {
      return new Text(
        `${theme.fg("toolTitle", theme.bold("Nix Session"))} ${theme.fg("muted", formatAction(input))}`,
        0,
        0,
      )
    },
    async execute(_toolCallId, params, signal, _onUpdate, context) {
      const message = await applyAction(params, signal)
      updateStatus(context, activePackages)

      return {
        content: [
          {
            type: "text",
            text: `${message}\nInjected environment keys: ${Object.keys(nixEnvironment.overlayEnv).sort().join(", ") || "none"}`,
          },
        ],
        details: {
          packages: [...activePackages].sort(),
          environmentKeys: Object.keys(nixEnvironment.overlayEnv).sort(),
        },
      }
    },
  })

  pi.registerCommand("nix-session", {
    description:
      "Manage temporary Nix packages for this Pi session. Usage: /nix-session [add] sqlite jq | remove sqlite | list | clear",
    handler: async (argumentsText, context) => {
      const input = parseCommandArguments(argumentsText)
      const message = await applyAction(input, context.signal)
      updateStatus(context, activePackages)
      context.ui.notify(message, "info")
    },
  })

  pi.on("session_start", async (_event, context) => {
    activePackages = restorePackagesFromSession(context)

    if (activePackages.size > 0) {
      try {
        await refreshEnvironment(context.signal)
      } catch (error) {
        if (context.hasUI) {
          context.ui.notify(
            `nix-session: failed to restore packages: ${error instanceof Error ? error.message : String(error)}`,
            "error",
          )
        }
      }
    }

    updateStatus(context, activePackages)
  })

  pi.on("user_bash", () => {
    const localBashOperations = createLocalBashOperations()

    return {
      operations: {
        exec(command, cwd, options) {
          return localBashOperations.exec(command, cwd, {
            ...options,
            env: materializeEnvironment(options.env ?? process.env, nixEnvironment),
          })
        },
      },
    }
  })
}
