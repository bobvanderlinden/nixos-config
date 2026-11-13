import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"
import { readFileSync } from "node:fs"
import { dirname, join, resolve } from "node:path"

type ServerConfig = Parameters<ExtensionAPI["registerMcpServer"]>[1]

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
}

// Ancestor configs are explicitly trusted by installing this user extension.
// They can start processes and evaluate command-backed credentials, just like
// the current directory's config. Pi still owns that config and user settings.
export default function (pi: ExtensionAPI) {
  const registeredNames = new Set<string>()

  pi.on("session_start", (_event, context) => {
    for (const name of registeredNames) pi.unregisterMcpServer(name)
    registeredNames.clear()

    const report = (message: string) => {
      if (context.hasUI) context.ui.notify(message, "warning")
      else console.error(`[parent-mcp] ${message}`)
    }

    const directories: string[] = []
    let directory = resolve(context.cwd)
    while (dirname(directory) !== directory) {
      directory = dirname(directory)
      directories.push(directory)
    }

    const servers = new Map<string, { name: string; config: Record<string, unknown>; path: string }>()
    for (const ancestor of directories.reverse()) {
      const path = join(ancestor, ".pi", "mcp.json")
      let source: string
      try {
        source = readFileSync(path, "utf8")
      } catch (error) {
        if ((error as NodeJS.ErrnoException).code !== "ENOENT") report(`Cannot read ${path}`)
        continue
      }

      let document: unknown
      try {
        document = JSON.parse(source)
      } catch {
        report(`Invalid JSON in ${path}`)
        continue
      }
      if (!isObject(document) || !isObject(document.mcpServers)) {
        report(`Expected an mcpServers object in ${path}`)
        continue
      }

      for (const [name, config] of Object.entries(document.mcpServers)) {
        if (!/^[a-zA-Z0-9_-]+$/.test(name) || !isObject(config)) {
          report(`Invalid MCP server entry in ${path}`)
          continue
        }
        // Pi treats hyphens and underscores as the same server name.
        const key = name.replaceAll("-", "_")
        const inherited = servers.get(key)
        if (!("command" in config) && !("url" in config) && !("type" in config) && inherited) {
          const overrides = Object.fromEntries(
            Object.entries(config).filter(([field]) => ["enabled", "exposure", "toolExposure"].includes(field)),
          )
          servers.set(key, { name, config: { ...inherited.config, ...overrides }, path })
        } else {
          servers.set(key, { name, config, path })
        }
      }
    }

    for (const { name, config, path } of servers.values()) {
      try {
        // The registration API validates each merged entry independently.
        pi.registerMcpServer(name, config as ServerConfig)
        registeredNames.add(name)
      } catch {
        report(`Could not register MCP server "${name}" from ${path}; check its configuration and name conflicts`)
      }
    }
  })
}
