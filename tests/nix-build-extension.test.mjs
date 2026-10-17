import assert from "node:assert/strict"
import { EventEmitter } from "node:events"
import { readFile } from "node:fs/promises"
import { stripTypeScriptTypes } from "node:module"
import * as path from "node:path"
import { test } from "node:test"
import { SourceTextModule, SyntheticModule } from "node:vm"

const source = stripTypeScriptTypes(await readFile(new URL("../.pi/extensions/nix-build.ts", import.meta.url), "utf8"))

async function createHarness() {
  const calls = []
  const messages = []
  const notifications = []
  const tools = new Map()
  const commands = new Map()
  const handlers = new Map()
  const child = new EventEmitter()
  child.stdout = new EventEmitter()
  child.stderr = new EventEmitter()
  const schemaType = {
    Object: properties => ({ properties }),
    String: options => options,
    Integer: options => options,
    Optional: schema => schema,
    Array: (items, options) => ({ items, ...options }),
  }
  const imports = {
    "node:child_process": {
      spawn: (...argumentsList) => { calls.push(argumentsList); return child },
    },
    "node:fs": {
      promises: { mkdtemp: async () => "/tmp/pi-nixos-build-test" },
      createWriteStream: () => ({ write() {}, end() {} }),
    },
    "node:os": { hostname: () => "test-host" },
    "node:path": { join: path.join, resolve: path.resolve },
    "@earendil-works/pi-ai": { StringEnum: values => ({ enum: values }) },
    typebox: { Type: schemaType },
  }
  const extension = new SourceTextModule(source)
  await extension.link(async specifier => {
    assert.ok(imports[specifier], `Unexpected import: ${specifier}`)
    const exports = imports[specifier]
    return new SyntheticModule(Object.keys(exports), function () {
      for (const [name, value] of Object.entries(exports)) this.setExport(name, value)
    })
  })
  await extension.evaluate()
  extension.namespace.default({
    registerTool: tool => tools.set(tool.name, tool),
    registerCommand: (name, command) => commands.set(name, command),
    on: (name, handler) => handlers.set(name, handler),
    sendMessage: message => messages.push(message),
  })
  const context = {
    cwd: "/project",
    hasUI: false,
    ui: { notify: (...argumentsList) => notifications.push(argumentsList) },
  }
  return {
    calls, messages, notifications, child,
    tool: tools.get("nix_build"),
    execute: parameters => tools.get("nix_build").execute("test", parameters, undefined, undefined, context),
    command: argumentsText => commands.get("nix-build").handler(argumentsText, context),
    cleanup: () => handlers.get("session_shutdown")(),
  }
}

for (const [name, parameters, expected] of [
  ["default temporary link", {}, "/tmp/pi-nixos-build-test/result"],
  ["relative link", { outputLink: "system-result" }, "/project/system-result"],
  ["absolute link", { outputLink: "/tmp/custom-result" }, "/tmp/custom-result"],
  ["path containing spaces", { outputLink: "build outputs/result" }, "/project/build outputs/result"],
  ["targeted build", { outputLink: "package-result", installables: ["nixpkgs#hello"] }, "/project/package-result"],
]) {
  test(name, async () => {
    const harness = await createHarness()
    try {
      const result = await harness.execute({ action: "start-build", ...parameters })
      const [command, argumentsList, options] = harness.calls[0]
      assert.equal(command, "nix")
      assert.equal(argumentsList[argumentsList.indexOf("--out-link") + 1], expected)
      assert.equal(options.cwd, "/project")
      assert.ok(result.content[0].text.includes(`Output link: ${expected}`))
      if (parameters.installables) {
        assert.equal(argumentsList.at(-1), "nixpkgs#hello")
        assert.ok(argumentsList.includes("--inputs-from"))
      } else {
        assert.ok(argumentsList.at(-2).includes(".config.system.build.toplevel"))
        assert.ok(argumentsList.at(-1).endsWith(".home.activationPackage"))
      }
      harness.child.emit("close", 0, null)
      assert.ok(harness.messages.at(-1).content.includes(`Output link: ${expected}`))
      assert.equal(harness.messages.at(-1).details.outputLink, expected)
    } finally {
      harness.cleanup()
    }
  })
}

for (const argumentsText of [
  "start-build --out-link system-result",
  "start-build --out-link system-result nixpkgs#hello",
  "start-build nixpkgs#hello --out-link system-result",
]) {
  test(`command: ${argumentsText}`, async () => {
    const harness = await createHarness()
    try {
      await harness.command(argumentsText)
      const argumentsList = harness.calls[0][1]
      assert.equal(argumentsList[argumentsList.indexOf("--out-link") + 1], "/project/system-result")
      assert.ok(!argumentsList.includes("system-result"))
      assert.equal(argumentsList.includes("nixpkgs#hello"), argumentsText.includes("nixpkgs#hello"))
    } finally {
      harness.cleanup()
    }
  })
}

test("reject missing, duplicate and empty paths without spawning", async () => {
  const harness = await createHarness()
  try {
    for (const argumentsText of ["start-build --out-link", "start-build --out-link --out-link", "start-build --out-link first --out-link second"]) {
      await harness.command(argumentsText)
      assert.equal(harness.notifications.at(-1)[1], "error")
    }
    for (const outputLink of ["", "   "]) {
      await assert.rejects(harness.execute({ action: "start-build", outputLink }), /must not be empty/)
    }
    assert.equal(harness.calls.length, 0)
    assert.equal(harness.tool.parameters.properties.outputLink.minLength, 1)
  } finally {
    harness.cleanup()
  }
})

test("failed builds do not report an output link as created", async () => {
  const harness = await createHarness()
  try {
    await harness.execute({ action: "start-build", outputLink: "result" })
    harness.child.emit("close", 1, null)
    assert.ok(harness.messages.at(-1).content.includes("failed"))
    assert.ok(!harness.messages.at(-1).content.includes("Output link:"))
  } finally {
    harness.cleanup()
  }
})
