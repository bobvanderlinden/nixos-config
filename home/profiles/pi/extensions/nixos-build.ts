import { spawn, type ChildProcess } from "node:child_process"
import { createWriteStream, promises as fileSystem } from "node:fs"
import { hostname } from "node:os"
import { join } from "node:path"
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent"
import { StringEnum } from "@earendil-works/pi-ai"
import { Type, type Static } from "typebox"

const STATUS_KEY = "nixos-build"
const MESSAGE_TYPE = "nixos-build"
const MAX_LOG_LINES = 500
const MAX_REPORTS = 20

const nixosBuildSchema = Type.Object({
  action: StringEnum(["start", "stop", "status", "logs"] as const),
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
})

type NixosBuildInput = Static<typeof nixosBuildSchema>
type IssueKind = "warning" | "failure"

type BuildJob = {
  childProcess: ChildProcess
  host: string
  user: string
  logPath: string
  outputLink: string
  recentLines: string[]
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

function updateStatus(context: ExtensionContext, job?: BuildJob) {
  if (!context.hasUI) return
  if (!job) {
    context.ui.setStatus(STATUS_KEY, undefined)
    return
  }

  const elapsedSeconds = Math.floor((Date.now() - job.startedAt) / 1000)
  context.ui.setStatus(STATUS_KEY, `Nix build ${job.host}, ${elapsedSeconds}s`)
}

function stopProcessGroup(childProcess: ChildProcess) {
  if (childProcess.pid === undefined) return

  try {
    process.kill(-childProcess.pid, "SIGTERM")
  } catch {
    childProcess.kill("SIGTERM")
  }
}

function parseCommandArguments(argumentsText: string): NixosBuildInput {
  const [action, host, user] = argumentsText.trim().split(/\s+/)
  if (action === "start") return { action, host, user }
  if (action === "stop" || action === "status" || action === "logs") return { action }
  throw new Error("Usage: /nixos-build start [host] [user] | stop | status | logs")
}

export default function (pi: ExtensionAPI) {
  let activeJob: BuildJob | undefined
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
          `Background Nix build ${label} for ${job.host}:`,
          "```text",
          contextLines,
          "```",
          `The build is still running. Log: ${job.logPath}`,
          "Do not edit the configuration and leave this build running. Stop it before making a fix, then start a new build.",
        ].join("\n"),
        display: true,
        details: { kind, line, logPath: job.logPath },
      },
      { triggerTurn: true, deliverAs: "steer" },
    )
  }

  const appendOutput = (context: ExtensionContext, job: BuildJob, chunk: Buffer | string) => {
    const text = chunk.toString()
    for (const line of text.split(/\r?\n/)) {
      if (!line) continue
      job.recentLines.push(line)
      if (job.recentLines.length > MAX_LOG_LINES) job.recentLines.shift()

      const kind = issueKindForLine(line)
      if (kind) notifyAgent(context, job, kind, line)
    }
  }

  const start = async (
    context: ExtensionContext,
    requestedHost?: string,
    requestedUser?: string,
  ): Promise<string> => {
    if (activeJob) {
      throw new Error(`A NixOS build is already running for ${activeJob.host}. Stop it before starting another.`)
    }

    const host = validateAttributeName(requestedHost ?? hostname(), "host")
    const user = validateAttributeName(requestedUser ?? process.env.USER ?? "", "user")
    const directory = await fileSystem.mkdtemp("/tmp/pi-nixos-build-")
    const logPath = join(directory, "build.log")
    const outputLink = join(directory, "result")
    const logStream = createWriteStream(logPath, { flags: "a" })
    const childProcess = spawn(
      "nix",
      [
        "build",
        "--impure",
        "--keep-going",
        "--log-format",
        "raw",
        "--out-link",
        outputLink,
        targetForSystem(host),
        targetForHome(host, user),
      ],
      {
        cwd: context.cwd,
        detached: process.platform !== "win32",
        env: { ...process.env, IMPURITY_PATH: context.cwd },
        stdio: ["ignore", "pipe", "pipe"],
      },
    )

    const job: BuildJob = {
      childProcess,
      host,
      user,
      logPath,
      outputLink,
      recentLines: [],
      reportedIssues: new Set(),
      reportCount: 0,
      startedAt: Date.now(),
      stopping: false,
    }
    activeJob = job
    updateStatus(context, job)
    statusTimer = setInterval(() => updateStatus(context, activeJob), 1000)

    const consumeOutput = (chunk: Buffer) => {
      logStream.write(chunk)
      appendOutput(context, job, chunk)
    }
    childProcess.stdout?.on("data", consumeOutput)
    childProcess.stderr?.on("data", consumeOutput)

    childProcess.on("error", (error) => {
      logStream.write(`${error.message}\n`)
      appendOutput(context, job, error.message)
    })

    childProcess.on("close", async (code, signal) => {
      logStream.end()
      if (activeJob !== job) return

      activeJob = undefined
      clearStatusTimer()
      updateStatus(context)

      const result = job.stopping
        ? `Background Nix build stopped for ${host}.`
        : code === 0
          ? `Background Nix build succeeded for ${host}. It did not activate the configuration.`
          : `Background Nix build failed for ${host} with ${signal ? `signal ${signal}` : `exit code ${code ?? "unknown"}`}.`
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

    return `Started a background Nix build for ${host} and ${user}. It builds but does not activate the configuration. Log: ${logPath}`
  }

  const stop = (): string => {
    if (!activeJob) return "No background Nix build is running."
    activeJob.stopping = true
    stopProcessGroup(activeJob.childProcess)
    return `Stopping the background Nix build for ${activeJob.host}.`
  }

  const status = (): string => {
    if (!activeJob) return "No background Nix build is running."
    const elapsedSeconds = Math.floor((Date.now() - activeJob.startedAt) / 1000)
    return `Background Nix build for ${activeJob.host} has run for ${elapsedSeconds}s. Log: ${activeJob.logPath}`
  }

  const logs = async (lineCount: number): Promise<string> => {
    if (!activeJob) return "No background Nix build is running."
    const log = await fileSystem.readFile(activeJob.logPath, "utf8").catch(() => "")
    return tail(log.split(/\r?\n/), lineCount) || "The build has not produced output yet."
  }

  pi.registerTool({
    name: "nixos_build",
    label: "NixOS Build",
    description:
      "Start, stop, inspect, or read logs from a background NixOS and Home Manager build. It never activates a configuration. Start it before a long build, stop it before editing after a failure, and restart it to validate a fix.",
    promptSnippet: "Run and monitor background NixOS builds without activating them",
    promptGuidelines: [
      "Use nixos_build to start NixOS builds that may take a long time. When it reports a failure, stop the build before editing configuration files, then start a new build after the fix.",
    ],
    parameters: nixosBuildSchema,
    async execute(_toolCallId, parameters, _signal, _onUpdate, context) {
      let message: string
      if (parameters.action === "start") {
        message = await start(context, parameters.host, parameters.user)
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

  pi.registerCommand("nixos-build", {
    description: "Build NixOS in the background without activation. Usage: /nixos-build start [host] [user] | stop | status | logs",
    handler: async (argumentsText, context) => {
      try {
        const parameters = parseCommandArguments(argumentsText)
        const message = parameters.action === "start"
          ? await start(context, parameters.host, parameters.user)
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
    if (!activeJob) return
    activeJob.stopping = true
    stopProcessGroup(activeJob.childProcess)
    activeJob = undefined
  })
}
