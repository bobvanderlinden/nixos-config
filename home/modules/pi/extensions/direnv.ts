import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent"
import { spawn } from "node:child_process"
import { existsSync } from "node:fs"
import { dirname, join } from "node:path"

type EnvDiff = Record<string, string | null>

type CommandResult = {
  code: number | null
  stdout: string
  stderr: string
}

type ExportResult = {
  envDiff: EnvDiff | null
  envrcPath: string | null
  autoAllowed: boolean
  failed: boolean
}

function isEnvDiff(value: unknown): value is EnvDiff {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return false
  }

  return Object.values(value).every(
    (entry) => typeof entry === "string" || entry === null,
  )
}

function applyEnvDiff(envDiff: EnvDiff) {
  for (const [key, value] of Object.entries(envDiff)) {
    if (value === null) {
      delete process.env[key]
      continue
    }

    process.env[key] = value
  }
}

function runCommand(
  command: string,
  argumentsList: string[],
  cwd: string,
  signal?: AbortSignal,
): Promise<CommandResult> {
  return new Promise((resolve) => {
    const childProcess = spawn(command, argumentsList, {
      cwd,
      env: process.env,
      stdio: ["ignore", "pipe", "pipe"],
      signal,
    })

    let stdout = ""
    let stderr = ""

    childProcess.stdout.setEncoding("utf8")
    childProcess.stderr.setEncoding("utf8")

    childProcess.stdout.on("data", (chunk) => {
      stdout += chunk
    })

    childProcess.stderr.on("data", (chunk) => {
      stderr += chunk
    })

    childProcess.on("error", () => {
      resolve({ code: 1, stdout, stderr })
    })

    childProcess.on("close", (code) => {
      resolve({ code, stdout, stderr })
    })
  })
}

async function findGitRoot(cwd: string, signal?: AbortSignal): Promise<string | null> {
  const result = await runCommand("git", ["rev-parse", "--show-toplevel"], cwd, signal)
  if (result.code !== 0) return null
  return result.stdout.trim() || null
}

function findEnvrc(startDir: string, stopAt: string | null): string | null {
  let currentDir = startDir
  const boundary = stopAt || "/"

  while (true) {
    const envrcPath = join(currentDir, ".envrc")
    if (existsSync(envrcPath)) {
      return envrcPath
    }

    if (currentDir === boundary || currentDir === "/") {
      break
    }

    const parentDir = dirname(currentDir)
    if (parentDir === currentDir) {
      break
    }

    currentDir = parentDir
  }

  return null
}

async function exportDirenv(envrcPath: string, signal?: AbortSignal): Promise<ExportResult> {
  const envrcDir = dirname(envrcPath)
  let autoAllowed = false

  while (true) {
    const exportResult = await runCommand("direnv", ["export", "json"], envrcDir, signal)
    const stdout = exportResult.stdout.trim()

    if (exportResult.code === 0) {
      if (!stdout) {
        return { envDiff: null, envrcPath, autoAllowed, failed: false }
      }

      const parsed: unknown = JSON.parse(stdout)
      if (!isEnvDiff(parsed)) {
        return { envDiff: null, envrcPath, autoAllowed, failed: true }
      }

      return { envDiff: parsed, envrcPath, autoAllowed, failed: false }
    }

    if (autoAllowed || !exportResult.stderr.includes("is blocked")) {
      return { envDiff: null, envrcPath, autoAllowed, failed: true }
    }

    const allowResult = await runCommand("direnv", ["allow"], envrcDir, signal)
    if (allowResult.code !== 0) {
      return { envDiff: null, envrcPath, autoAllowed, failed: true }
    }

    autoAllowed = true
  }
}

async function syncDirenv(
  cwd: string,
  getSyncPromise: () => Promise<ExportResult> | null,
  setSyncPromise: (promise: Promise<ExportResult> | null) => void,
  signal?: AbortSignal,
): Promise<ExportResult> {
  const existingSyncPromise = getSyncPromise()
  if (existingSyncPromise) return existingSyncPromise

  const nextSyncPromise = (async () => {
    try {
      const gitRoot = await findGitRoot(cwd, signal)
      const envrcPath = findEnvrc(cwd, gitRoot)

      if (!envrcPath) {
        return { envDiff: null, envrcPath: null, autoAllowed: false, failed: false }
      }

      const result = await exportDirenv(envrcPath, signal)
      if (result.envDiff) {
        applyEnvDiff(result.envDiff)
      }

      return result
    } catch {
      return { envDiff: null, envrcPath: null, autoAllowed: false, failed: true }
    } finally {
      setSyncPromise(null)
    }
  })()

  setSyncPromise(nextSyncPromise)
  return nextSyncPromise
}

async function loadDirenv(
  context: ExtensionContext,
  isLoaded: () => boolean,
  setLoaded: (loaded: boolean) => void,
  getSyncPromise: () => Promise<ExportResult> | null,
  setSyncPromise: (promise: Promise<ExportResult> | null) => void,
) {
  if (isLoaded()) return
  setLoaded(true)

  const result = await syncDirenv(
    context.cwd,
    getSyncPromise,
    setSyncPromise,
    context.signal,
  )
  if (result.failed) {
    if (result.envrcPath && context.hasUI) {
      context.ui.notify("direnv: failed to load environment", "error")
    }
    return
  }

  if (result.autoAllowed) {
    if (context.hasUI) {
      context.ui.notify("direnv: allowed and reloaded environment", "info")
    }
    return
  }

  if (result.envDiff && context.hasUI) {
    context.ui.notify("direnv: environment loaded", "info")
  }
}

export default function (pi: ExtensionAPI) {
  let loaded = false
  let syncPromise: Promise<ExportResult> | null = null

  const isLoaded = () => loaded
  const setLoaded = (nextLoaded: boolean) => {
    loaded = nextLoaded
  }
  const getSyncPromise = () => syncPromise
  const setSyncPromise = (nextSyncPromise: Promise<ExportResult> | null) => {
    syncPromise = nextSyncPromise
  }

  pi.on("session_start", async (_event, context) => {
    await loadDirenv(context, isLoaded, setLoaded, getSyncPromise, setSyncPromise)
  })

  pi.on("tool_call", async (_event, context) => {
    await loadDirenv(context, isLoaded, setLoaded, getSyncPromise, setSyncPromise)
  })

  pi.on("user_bash", async (_event, context) => {
    await loadDirenv(context, isLoaded, setLoaded, getSyncPromise, setSyncPromise)
  })
}
