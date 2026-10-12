import { spawn, type ChildProcess } from "node:child_process"
import { createWriteStream, promises as fileSystem } from "node:fs"
import { hostname } from "node:os"
import { join } from "node:path"
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent"
import { StringEnum } from "@earendil-works/pi-ai"
import { Type, type Static } from "typebox"

const STATUS_KEY = "nix-build"
const MESSAGE_TYPE = "nix-build"
const MAX_LOG_LINES = 500
const MAX_REPORTS = 20

const nixBuildSchema = Type.Object({
  action: StringEnum(["start-build", "stop", "status", "logs"] as const),
  host: Type.Optional(
    Type.String({
      description: "NixOS hostname to build. Defaults to the local hostname.",
    }),
  ),
  user: Type.Optional(
    Type.String({
      description: "Home Manager user to build. Defaults to $USER.",
    }),
  ),
  lines: Type.Optional(
    Type.Integer({
      minimum: 1,
      maximum: MAX_LOG_LINES,
      description: "Number of trailing log lines to return for the logs action.",
    }),
  ),
  installables: Type.Optional(
    Type.Array(
      Type.String({
        description: "An installable to build, such as nixpkgs#ltrace or .#nixosConfigurations.host.pkgs.ltrace.",
      }),
      {
        minItems: 1,
        description: "Installables to build. When omitted, builds the configured NixOS and Home Manager outputs.",
      },
    ),
  ),
})

type NixBuildInput = Static<typeof nixBuildSchema>
type IssueKind = "warning" | "failure"

type NixActivity = {
  type: number
  name?: string
  text: string
  derivation?: string
}

type NixProgress = {
  done: number
  expected: number
  running: number
  failed: number
}

type BuildKind = "system" | "expression"

type BuildJob = {
  kind: BuildKind
  childProcess: ChildProcess
  host: string
  user: string
  logPath: string
  outputLink: string
  description: string
  recentLines: string[]
  pendingStdout: string
  pendingStderr: string
  activities: Map<number, NixActivity>
  activeDerivations: Map<number, string>
  transfers: Map<number, { done: number; expected: number }>
  progress?: NixProgress
  reportedIssues: Set<string>
  reportCount: number
  startedAt: number
  stopping: boolean
}

function validateAttributeName(name: string, label: string): string {
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(name)) {
    throw new Error(`${label} must contain only letters, numbers, dots, underscores, and hyphens`)
  }
  return name
}

function shellQuoteAttribute(name: string): string {
  return `"${name.replaceAll("\\", "\\\\").replaceAll("\"", "\\\"")}"`
}

function targetForSystem(host: string): string {
  return `.#nixosConfigurations.${shellQuoteAttribute(host)}.config.system.build.toplevel`
}

function targetForHome(host: string, user: string): string {
  return `.#nixosConfigurations.${shellQuoteAttribute(host)}.config.home-manager.users.${shellQuoteAttribute(user)}.home.activationPackage`
}

function issueKindForLine(line: string): IssueKind | undefined {
  if (/\bwarning:/.test(line)) return "warning"
  if (
    /\berror:/.test(line)
    || /builder for .* failed/.test(line)
    || /failed to build/.test(line)
  ) {
    return "failure"
  }
  return undefined
}

function tail(lines: string[], lineCount: number): string {
  return lines.slice(-lineCount).join("\n")
}

function derivationName(derivation: string): string {
  return derivation.replace(/^\/nix\/store\/[^-]+-/, "").replace(/\.drv$/, "")
}

function activeBuilds(job: BuildJob): string {
  const derivations = [...job.activeDerivations.values()].map(derivationName)
  return derivations.length === 0 ? "" : ` [${derivations.join(", ")}]`
}

function formatBytes(bytes: number): string {
  const units = ["B", "KiB", "MiB", "GiB", "TiB"]
  let value = bytes
  let unit = 0
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024
    unit += 1
  }
  return `${value.toFixed(unit === 0 ? 0 : 1)} ${units[unit]}`
}

function progressSummary(job: BuildJob): string {
  if (!job.progress) return ""
  const { done, expected, running, failed } = job.progress
  const failureText = failed === 0 ? "" : `, ${failed} failed`
  return ` ${done}/${expected}, ${running} running${failureText}`
}

function transferSummary(job: BuildJob): string {
  const transfer = [...job.transfers.values()].at(-1)
  return transfer ? ` ${formatBytes(transfer.done)}/${formatBytes(transfer.expected)} transferred` : ""
}

function parseNixEvent(line: string): Record<string, unknown> | undefined {
  if (!line.startsWith("@nix ")) return undefined
  try {
    const event = JSON.parse(line.slice("@nix ".length))
    return event !== null && typeof event === "object" ? event as Record<string, unknown> : undefined
  } catch {
    return undefined
  }
}

function stringField(event: Record<string, unknown>, index: number): string | undefined {
  const fields = event.fields
  return Array.isArray(fields) && typeof fields[index] === "string" ? fields[index] : undefined
}

function formatNixEvent(job: BuildJob, event: Record<string, unknown>): string | undefined {
  const action = event.action
  const id = typeof event.id === "number" ? event.id : undefined

  if (action === "start" && id !== undefined) {
    const type = typeof event.type === "number" ? event.type : -1
    const name = typeof event.name === "string" ? event.name : undefined
    const text = typeof event.text === "string" ? event.text : ""
    const derivation = type === 105
      ? stringField(event, 0)?.endsWith(".drv")
        ? stringField(event, 0)
        : text.match(/building '([^']+\.drv)'/)?.[1]
      : undefined
    job.activities.set(id, { type, name, text, derivation })
    if (derivation) job.activeDerivations.set(id, derivation)
    return derivation ? `building '${derivation}'` : text || undefined
  }

  if (action === "result" && id !== undefined) {
    const fields = event.fields
    const activity = job.activities.get(id)
    if (Array.isArray(fields) && fields.length === 4 && fields.every((field) => typeof field === "number")) {
      const [done, expected, running, failed] = fields as number[]
      if (activity?.type === 104 || activity?.name === "Builds") {
        job.progress = { done, expected, running, failed }
      } else if (Math.max(done, expected, running, failed) >= 1024) {
        job.transfers.set(id, { done, expected })
      }
    }
    const resultType = typeof event.type === "number" ? event.type : -1
    const output = resultType === 101 ? stringField(event, 0) : undefined
    if (output && activity?.derivation) return `${derivationName(activity.derivation)}: ${output}`
    return undefined
  }

  if (action === "stop" && id !== undefined) {
    job.activeDerivations.delete(id)
    job.transfers.delete(id)
    job.activities.delete(id)
    return undefined
  }

  if (action === "msg" && typeof event.msg === "string") return event.msg
  return undefined
}

function updateStatus(context: ExtensionContext, jobs: Iterable<BuildJob>) {
  if (!context.hasUI) return
  const activeJobs = [...jobs]
  if (activeJobs.length === 0) {
    context.ui.setStatus(STATUS_KEY, undefined)
    return
  }

  const status = activeJobs.map((job) => {
    const elapsedSeconds = Math.floor((Date.now() - job.startedAt) / 1000)
    return `${job.description}, ${elapsedSeconds}s${progressSummary(job)}${transferSummary(job)}${activeBuilds(job)}`
  })
  context.ui.setStatus(STATUS_KEY, `Nix build ${status.join("; ")}`)
}

function stopProcessGroup(childProcess: ChildProcess) {
  if (childProcess.pid === undefined) return

  try {
    process.kill(-childProcess.pid, "SIGTERM")
  } catch {
    childProcess.kill("SIGTERM")
  }
}

function parseCommandArguments(argumentsText: string): NixBuildInput {
  const argumentsList = argumentsText.trim().split(/\s+/)
  const [action, firstArgument, secondArgument] = argumentsList
  if (action === "start-build") {
    return firstArgument ? { action, installables: argumentsList.slice(1) } : { action }
  }
  if (action === "stop" || action === "status" || action === "logs") return { action }
  throw new Error("Usage: /nix-build start-build [installable]... | stop | status | logs")
}

export default function (pi: ExtensionAPI) {
  const activeJobs = new Map<BuildKind, BuildJob>()
  let statusTimer: NodeJS.Timeout | undefined

  const clearStatusTimer = () => {
    if (!statusTimer) return
    clearInterval(statusTimer)
    statusTimer = undefined
  }

  const notifyAgent = (context: ExtensionContext, job: BuildJob, kind: IssueKind, line: string) => {
    if (job.reportCount >= MAX_REPORTS) return

    const issueKey = `${kind}:${line}`
    if (job.reportedIssues.has(issueKey)) return
    job.reportedIssues.add(issueKey)
    job.reportCount += 1

    const label = kind === "warning" ? "evaluation warning" : "build failure"
    const contextLines = tail(job.recentLines, 12)
    pi.sendMessage(
      {
        customType: MESSAGE_TYPE,
        content: [
          `Background Nix build ${label} for ${job.description}:`,
          "```text",
          contextLines,
          "```",
          `The build is still running. Log: ${job.logPath}`,
          "You may edit the configuration while this broad build continues. Validate the fix first with a targeted build of the failing package or expression, then start a new broad build.",
        ].join("\n"),
        display: true,
        details: { kind, line, logPath: job.logPath },
      },
      { triggerTurn: true, deliverAs: "steer" },
    )
  }

  const appendOutput = (
    context: ExtensionContext,
    job: BuildJob,
    logStream: ReturnType<typeof createWriteStream>,
    source: "stdout" | "stderr",
    chunk: Buffer | string,
  ) => {
    const pendingKey = source === "stdout" ? "pendingStdout" : "pendingStderr"
    job[pendingKey] += chunk.toString()
    const lines = job[pendingKey].split(/\r?\n/)
    job[pendingKey] = lines.pop() ?? ""

    for (const line of lines) {
      if (!line) continue
      const event = parseNixEvent(line)
      const formatted = event ? formatNixEvent(job, event) : line
      if (!formatted) continue
      logStream.write(`${formatted}\n`)
      job.recentLines.push(formatted)
      if (job.recentLines.length > MAX_LOG_LINES) job.recentLines.shift()

      const kind = issueKindForLine(formatted)
      if (kind) notifyAgent(context, job, kind, formatted)
    }
  }

  const start = async (
    context: ExtensionContext,
    requestedHost?: string,
    requestedUser?: string,
    installables?: string[],
  ): Promise<string> => {
    const kind: BuildKind = installables ? "expression" : "system"
    if (activeJobs.has(kind)) {
      throw new Error(`A background Nix ${kind} build is already running. Stop it before starting another ${kind} build.`)
    }

    const host = installables ? undefined : validateAttributeName(requestedHost ?? hostname(), "host")
    const user = installables ? undefined : validateAttributeName(requestedUser ?? process.env.USER ?? "", "user")
    const description = installables ? `installables ${installables.join(" ")}` : host!
    const directory = await fileSystem.mkdtemp("/tmp/pi-nixos-build-")
    const logPath = join(directory, "build.log")
    const outputLink = join(directory, "result")
    const logStream = createWriteStream(logPath, { flags: "a" })
    const childProcess = spawn(
      "nix",
      [
        "build",
        "--impure",
        ...(installables ? ["--inputs-from", "."] : []),
        "--keep-going",
        "--log-format",
        "internal-json",
        "--out-link",
        outputLink,
        ...(installables ?? [targetForSystem(host!), targetForHome(host!, user!)]),
      ],
      {
        cwd: context.cwd,
        detached: process.platform !== "win32",
        env: { ...process.env, IMPURITY_PATH: context.cwd },
        stdio: ["ignore", "pipe", "pipe"],
      },
    )

    const job: BuildJob = {
      kind,
      childProcess,
      host: host ?? "expression",
      user: user ?? "",
      logPath,
      description,
      outputLink,
      recentLines: [],
      pendingStdout: "",
      pendingStderr: "",
      activities: new Map(),
      activeDerivations: new Map(),
      transfers: new Map(),
      progress: undefined,
      reportedIssues: new Set(),
      reportCount: 0,
      startedAt: Date.now(),
      stopping: false,
    }
    activeJobs.set(kind, job)
    updateStatus(context, activeJobs.values())
    statusTimer ??= setInterval(() => updateStatus(context, activeJobs.values()), 1000)

    const consumeOutput = (source: "stdout" | "stderr", chunk: Buffer) => {
      appendOutput(context, job, logStream, source, chunk)
    }
    childProcess.stdout?.on("data", (chunk) => consumeOutput("stdout", chunk))
    childProcess.stderr?.on("data", (chunk) => consumeOutput("stderr", chunk))

    childProcess.on("error", (error) => {
      appendOutput(context, job, logStream, "stderr", `${error.message}\n`)
    })

    childProcess.on("close", async (code, signal) => {
      if (job.pendingStdout) appendOutput(context, job, logStream, "stdout", "\n")
      if (job.pendingStderr) appendOutput(context, job, logStream, "stderr", "\n")
      logStream.end()
      if (activeJobs.get(job.kind) !== job) return

      activeJobs.delete(job.kind)
      if (activeJobs.size === 0) clearStatusTimer()
      updateStatus(context, activeJobs.values())

      const result = job.stopping
        ? `Background Nix build stopped for ${job.description}.`
        : code === 0
          ? `Background Nix build succeeded for ${job.description}. It did not activate the configuration.`
          : `Background Nix build failed for ${job.description} with ${signal ? `signal ${signal}` : `exit code ${code ?? "unknown"}`}.`
      pi.sendMessage(
        {
          customType: MESSAGE_TYPE,
          content: `${result}\nLog: ${logPath}`,
          display: true,
          details: { code, signal, logPath, outputLink },
        },
        { triggerTurn: true, deliverAs: "steer" },
      )
    })

    return installables
      ? `Started a background Nix build for ${installables.join(" ")}, using this flake's inputs. It does not activate the configuration. Log: ${logPath}`
      : `Started a background Nix build for ${host} and ${user}. It builds but does not activate the configuration. Log: ${logPath}`
  }

  const stop = (): string => {
    if (activeJobs.size === 0) return "No background Nix build is running."
    const descriptions = [...activeJobs.values()].map((job) => {
      job.stopping = true
      stopProcessGroup(job.childProcess)
      return job.description
    })
    return `Stopping background Nix builds for ${descriptions.join(" and ")}.`
  }

  const status = (): string => {
    if (activeJobs.size === 0) return "No background Nix build is running."
    return [...activeJobs.values()].map((job) => {
      const elapsedSeconds = Math.floor((Date.now() - job.startedAt) / 1000)
      return `Background Nix build for ${job.description} has run for ${elapsedSeconds}s. Log: ${job.logPath}`
    }).join("\n")
  }

  const logs = async (lineCount: number): Promise<string> => {
    if (activeJobs.size === 0) return "No background Nix build is running."
    const logs = await Promise.all([...activeJobs.values()].map(async (job) => {
      const log = await fileSystem.readFile(job.logPath, "utf8").catch(() => "")
      const output = tail(log.split(/\r?\n/), lineCount) || "The build has not produced output yet."
      return `${job.description}:\n${output}`
    }))
    return logs.join("\n\n")
  }

  pi.registerTool({
    name: "nix_build",
    label: "Nix Build",
    description:
      "Start, stop, inspect, or read logs from background NixOS, Home Manager, and targeted expression builds. It never activates a configuration. The build sends the agent a message on warnings, failures, and completion. Keep a broad build running while investigating failures, validate each fix with a targeted build, then start a new broad build.",
    promptSnippet: "Run and monitor background NixOS builds without activating them",
    promptGuidelines: [
      "Use nix_build to start long NixOS builds, then return control. Do not poll it or use sleep. nix_build sends messages when the build warns, fails, or completes. When it reports a failure, leave the broad build running, edit the configuration, and use nix_build with action start-build and installables to validate the failed package or expression. Start a new broad build after the targeted build passes.",
    ],
    parameters: nixBuildSchema,
    async execute(_toolCallId, parameters, _signal, _onUpdate, context) {
      let message: string
      if (parameters.action === "start-build") {
        message = await start(context, parameters.host, parameters.user, parameters.installables)
      } else if (parameters.action === "stop") {
        message = stop()
      } else if (parameters.action === "status") {
        message = status()
      } else {
        message = await logs(parameters.lines ?? 100)
      }

      return { content: [{ type: "text", text: message }], details: { action: parameters.action } }
    },
  })

  pi.registerCommand("nix-build", {
    description: "Build NixOS outputs or installables in the background without activation. Usage: /nix-build start-build [installable]... | stop | status | logs",
    handler: async (argumentsText, context) => {
      try {
        const parameters = parseCommandArguments(argumentsText)
        const message = parameters.action === "start-build"
          ? await start(context, parameters.host, parameters.user, parameters.installables)
          : parameters.action === "stop"
            ? stop()
            : parameters.action === "status"
              ? status()
              : await logs(100)
        context.ui.notify(message, "info")
      } catch (error) {
        context.ui.notify(error instanceof Error ? error.message : String(error), "error")
      }
    },
  })

  pi.on("session_shutdown", () => {
    clearStatusTimer()
    for (const job of activeJobs.values()) {
      job.stopping = true
      stopProcessGroup(job.childProcess)
    }
    activeJobs.clear()
  })
}
