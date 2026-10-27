import assert from "node:assert/strict"
import { EventEmitter } from "node:events"
import { readFile } from "node:fs/promises"
import { stripTypeScriptTypes } from "node:module"
import * as path from "node:path"
import { test } from "node:test"
import { createContext, SourceTextModule, SyntheticModule } from "node:vm"

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
  let elapsed = 0
  let nextTimer = 0
  const timers = new Map()
  const moduleContext = createContext({
    process, setInterval, clearInterval,
    setTimeout: (callback, delay) => {
      const identifier = ++nextTimer
      timers.set(identifier, { callback, deadline: elapsed + delay })
      return identifier
    },
    clearTimeout: identifier => timers.delete(identifier),
  })
  const advanceTime = milliseconds => {
    elapsed += milliseconds
    for (const [identifier, timer] of timers) {
      if (timer.deadline <= elapsed) {
        timers.delete(identifier)
        timer.callback()
      }
    }
  }
  const extension = new SourceTextModule(source, { context: moduleContext })
  await extension.link(async specifier => {
    assert.ok(imports[specifier], `Unexpected import: ${specifier}`)
    const exports = imports[specifier]
    return new SyntheticModule(Object.keys(exports), function () {
      for (const [name, value] of Object.entries(exports)) this.setExport(name, value)
    }, { context: moduleContext })
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
    calls, messages, notifications, child, advanceTime,
    emitEvent: event => child.stderr.emit("data", Buffer.from(`@nix ${JSON.stringify(event)}\n`)),
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

test("warnings use fixed 10-second windows and remain deduplicated", async () => {
  const harness = await createHarness()
  try {
    await harness.execute({ action: "start-build" })
    const warning = message => harness.emitEvent({ action: "msg", level: 1, msg: message })
    warning("first warning")
    harness.advanceTime(9_000)
    warning("second warning")
    warning("first warning")
    assert.equal(harness.messages.length, 0)
    harness.advanceTime(1_000)
    assert.equal(harness.messages.length, 1)
    assert.deepEqual(Array.from(harness.messages[0].details.warnings), ["first warning", "second warning"])
    warning("third warning")
    harness.advanceTime(9_999)
    assert.equal(harness.messages.length, 1)
    harness.advanceTime(1)
    assert.equal(harness.messages.length, 2)
    assert.deepEqual(Array.from(harness.messages[1].details.warnings), ["third warning"])
  } finally {
    harness.cleanup()
  }
})

for (const exitCode of [0, 1]) {
  test(`completion flushes pending warnings with exit code ${exitCode}`, async () => {
    const harness = await createHarness()
    try {
      await harness.execute({ action: "start-build" })
      harness.emitEvent({ action: "msg", level: 1, msg: "pending warning" })
      harness.child.emit("close", exitCode, null)
      assert.equal(harness.messages.length, 2)
      assert.equal(harness.messages[0].details.kind, "warning")
      assert.equal(harness.messages[1].details.code, exitCode)
      harness.advanceTime(10_000)
      assert.equal(harness.messages.length, 2)
    } finally {
      harness.cleanup()
    }
  })
}

test("errors are immediate and builder warnings do not trigger messages", async () => {
  const harness = await createHarness()
  try {
    await harness.execute({ action: "start-build" })
    harness.emitEvent({ action: "start", id: 1, type: 105, fields: ["/nix/store/example-package.drv"] })
    harness.emitEvent({ action: "result", id: 1, type: 101, fields: ["warning: builder warning"] })
    harness.advanceTime(10_000)
    assert.equal(harness.messages.length, 0)
    harness.emitEvent({ action: "msg", level: 1, msg: "pending warning" })
    harness.emitEvent({ action: "msg", level: 0, msg: "immediate error" })
    assert.equal(harness.messages.length, 1)
    assert.equal(harness.messages[0].details.kind, "failure")
    harness.advanceTime(10_000)
    assert.equal(harness.messages.length, 2)
    assert.equal(harness.messages[1].details.kind, "warning")
  } finally {
    harness.cleanup()
  }
})

test("shutdown discards pending warning batches", async () => {
  const harness = await createHarness()
  await harness.execute({ action: "start-build" })
  harness.emitEvent({ action: "msg", level: 1, msg: "pending warning" })
  harness.cleanup()
  harness.advanceTime(10_000)
  harness.child.emit("close", 0, null)
  assert.equal(harness.messages.length, 0)
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
