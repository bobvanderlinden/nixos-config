import type { ChildProcessWithoutNullStreams } from "node:child_process"
import { spawn } from "node:child_process"
import { accessSync, constants, existsSync, readFileSync } from "node:fs"
import { homedir } from "node:os"
import { delimiter, dirname, extname, isAbsolute, join, resolve } from "node:path"
import { fileURLToPath, pathToFileURL } from "node:url"
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"
import { Type } from "typebox"

type LanguageServer = {
  command: string
  args?: string[]
}

type LspConfig = {
  languages: Record<string, LanguageServer>
  extensions: Record<string, string>
}

type Location = {
  uri: string
  range: {
    start: { line: number; character: number }
  }
}

type PendingRequest = {
  resolve: (value: unknown) => void
  reject: (error: Error) => void
}

const referencesSchema = Type.Object({
  file: Type.String({
    description: "Path to the source file, relative to the current project or absolute.",
  }),
  line: Type.Integer({
    minimum: 1,
    description: "One-based line number of the symbol.",
  }),
  character: Type.Optional(
    Type.Integer({
      minimum: 1,
      description: "One-based character number of the symbol. Defaults to 1.",
    }),
  ),
})

function configPath(): string {
  const agentDirectory = process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi", "agent")
  return join(agentDirectory, "lsp.json")
}

function loadConfig(): LspConfig {
  const file = configPath()
  if (!existsSync(file)) return { languages: {}, extensions: {} }

  const value: unknown = JSON.parse(readFileSync(file, "utf8"))
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`LSP config ${file} must be a JSON object.`)
  }

  const config = value as Partial<LspConfig>
  if (!config.languages || typeof config.languages !== "object" || Array.isArray(config.languages)) {
    throw new Error(`LSP config ${file} requires a languages object.`)
  }
  if (!config.extensions || typeof config.extensions !== "object" || Array.isArray(config.extensions)) {
    throw new Error(`LSP config ${file} requires an extensions object.`)
  }

  for (const [language, server] of Object.entries(config.languages)) {
    if (!server || typeof server !== "object" || Array.isArray(server) || typeof server.command !== "string" || !server.command) {
      throw new Error(`LSP language ${language} requires a command.`)
    }
    if (server.args !== undefined && (!Array.isArray(server.args) || server.args.some((argument) => typeof argument !== "string"))) {
      throw new Error(`LSP language ${language} args must be an array of strings.`)
    }
  }

  for (const [extension, language] of Object.entries(config.extensions)) {
    if (!extension.startsWith(".") || typeof language !== "string" || !config.languages[language]) {
      throw new Error(`LSP extension mapping ${extension} must name a configured language.`)
    }
  }

  return config as LspConfig
}

function commandIsAvailable(command: string): boolean {
  if (command.includes("/")) {
    try {
      accessSync(command, constants.X_OK)
      return true
    } catch {
      return false
    }
  }

  return (process.env.PATH ?? "").split(delimiter).some((directory) => {
    try {
      accessSync(join(directory, command), constants.X_OK)
      return true
    } catch {
      return false
    }
  })
}

function encodeMessage(message: unknown): Buffer {
  const content = Buffer.from(JSON.stringify(message), "utf8")
  return Buffer.concat([Buffer.from(`Content-Length: ${content.length}\r\n\r\n`, "ascii"), content])
}

class Client {
  private readonly process: ChildProcessWithoutNullStreams
  private readonly pending = new Map<number, PendingRequest>()
  private readonly documents = new Map<string, { content: string; version: number }>()
  private buffer = Buffer.alloc(0)
  private nextId = 1
  private initialized: Promise<void> | null = null

  constructor(
    private readonly language: string,
    private readonly server: LanguageServer,
    private readonly cwd: string,
    private readonly onExit: () => void,
  ) {
    this.process = spawn(server.command, server.args ?? [], {
      cwd,
      env: process.env,
      stdio: "pipe",
    })
    this.process.stdout.on("data", (chunk: Buffer) => this.receive(chunk))
    this.process.stderr.on("data", () => {})
    this.process.on("error", (error) => this.fail(error))
    this.process.on("exit", () => this.fail(new Error(`${server.command} exited.`)))
  }

  async references(file: string, line: number, character: number, signal?: AbortSignal): Promise<Location[]> {
    await this.initialize(signal)
    const uri = pathToFileURL(file).href
    this.openDocument(uri, readFileSync(file, "utf8"))
    const result = await this.request("textDocument/references", {
      textDocument: { uri },
      position: { line, character },
      context: { includeDeclaration: true },
    }, signal)
    if (!Array.isArray(result)) return []
    return result.filter((location): location is Location => Boolean(location && typeof location === "object" && "uri" in location && "range" in location))
  }

  stop() {
    this.process.kill("SIGTERM")
  }

  private async initialize(signal?: AbortSignal) {
    if (!this.initialized) {
      this.initialized = this.request("initialize", {
        processId: process.pid,
        rootUri: pathToFileURL(this.cwd).href,
        workspaceFolders: [{ uri: pathToFileURL(this.cwd).href, name: this.cwd }],
        capabilities: {},
      }, signal).then(() => {
        this.notify("initialized", {})
      })
    }
    await this.initialized
  }

  private openDocument(uri: string, content: string) {
    const existing = this.documents.get(uri)
    if (!existing) {
      this.documents.set(uri, { content, version: 1 })
      this.notify("textDocument/didOpen", {
        textDocument: { uri, languageId: this.language, version: 1, text: content },
      })
      return
    }
    if (existing.content === content) return

    const version = existing.version + 1
    this.documents.set(uri, { content, version })
    this.notify("textDocument/didChange", {
      textDocument: { uri, version },
      contentChanges: [{ text: content }],
    })
  }

  private request(method: string, params: unknown, signal?: AbortSignal): Promise<unknown> {
    const id = this.nextId++
    return new Promise((resolveRequest, reject) => {
      const abort = () => {
        this.pending.delete(id)
        this.notify("$/cancelRequest", { id })
        reject(new Error(`LSP request ${method} was cancelled.`))
      }
      if (signal?.aborted) return abort()
      signal?.addEventListener("abort", abort, { once: true })
      this.pending.set(id, {
        resolve: (value) => {
          signal?.removeEventListener("abort", abort)
          resolveRequest(value)
        },
        reject: (error) => {
          signal?.removeEventListener("abort", abort)
          reject(error)
        },
      })
      this.send({ jsonrpc: "2.0", id, method, params })
    })
  }

  private notify(method: string, params: unknown) {
    this.send({ jsonrpc: "2.0", method, params })
  }

  private send(message: unknown) {
    this.process.stdin.write(encodeMessage(message))
  }

  private receive(chunk: Buffer) {
    this.buffer = Buffer.concat([this.buffer, chunk])
    while (true) {
      const headerEnd = this.buffer.indexOf("\r\n\r\n")
      if (headerEnd === -1) return
      const header = this.buffer.subarray(0, headerEnd).toString("ascii")
      const contentLength = Number(/^Content-Length:\s*(\d+)\s*$/im.exec(header)?.[1])
      if (!Number.isSafeInteger(contentLength) || contentLength < 0) {
        this.fail(new Error(`Invalid LSP response header from ${this.server.command}.`))
        return
      }
      const contentStart = headerEnd + 4
      if (this.buffer.length < contentStart + contentLength) return
      const content = this.buffer.subarray(contentStart, contentStart + contentLength)
      this.buffer = this.buffer.subarray(contentStart + contentLength)
      try {
        this.handleMessage(JSON.parse(content.toString("utf8")) as { id?: unknown; result?: unknown; error?: { message?: unknown } })
      } catch (error) {
        this.fail(error instanceof Error ? error : new Error(String(error)))
        return
      }
    }
  }

  private handleMessage(message: { id?: unknown; result?: unknown; error?: { message?: unknown } }) {
    if (typeof message.id !== "number") return
    const pending = this.pending.get(message.id)
    if (!pending) return
    this.pending.delete(message.id)
    if (message.error) {
      pending.reject(new Error(typeof message.error.message === "string" ? message.error.message : "LSP request failed."))
      return
    }
    pending.resolve(message.result)
  }

  private fail(error: Error) {
    for (const pending of this.pending.values()) pending.reject(error)
    this.pending.clear()
    this.onExit()
  }
}

function formatLocations(locations: Location[]): string {
  if (locations.length === 0) return "No references found."
  const lines = locations.slice(0, 500).map((location) => {
    const file = location.uri.startsWith("file:") ? fileURLToPath(location.uri) : location.uri
    return `${file}:${location.range.start.line + 1}:${location.range.start.character + 1}`
  })
  if (locations.length > lines.length) lines.push(`... ${locations.length - lines.length} more references`)
  return lines.join("\n")
}

export default function (pi: ExtensionAPI) {
  const clients = new Map<string, Client>()

  pi.registerTool({
    name: "lsp_references",
    label: "LSP References",
    description: "Find symbol references through the language server configured for the source file.",
    parameters: referencesSchema,
    async execute(_toolCallId, input, signal, _onUpdate, context) {
      const file = isAbsolute(input.file) ? input.file : resolve(context.cwd, input.file)
      if (!existsSync(file)) throw new Error(`File does not exist: ${file}`)
      const config = loadConfig()
      const language = config.extensions[extname(file)]
      if (!language) throw new Error(`No LSP language is configured for ${extname(file) || "this file type"}.`)
      const server = config.languages[language]
      if (!commandIsAvailable(server.command)) {
        throw new Error(`LSP command is not available in PATH: ${server.command}`)
      }

      const key = `${language}\0${context.cwd}`
      let client = clients.get(key)
      if (!client) {
        client = new Client(language, server, context.cwd, () => clients.delete(key))
        clients.set(key, client)
      }

      const locations = await client.references(file, input.line - 1, (input.character ?? 1) - 1, signal)
      return {
        content: [{ type: "text", text: formatLocations(locations) }],
        details: { language, locations },
      }
    },
  })

  pi.on("session_shutdown", () => {
    for (const client of clients.values()) client.stop()
    clients.clear()
  })
}
