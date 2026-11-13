// Run with: node --test tests/pi-desktop-status.test.mjs
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { stripTypeScriptTypes } from "node:module";
import { basename } from "node:path";
import { test } from "node:test";
import { runInNewContext } from "node:vm";

function fixture(extension, child) {
  const handlers = new Map();
  const tools = new Map();
  const effects = [];
  const socketHandlers = new Map();
  const socket = {
    writable: true,
    on: (name, handler) => socketHandlers.set(name, handler),
    write: (message) => effects.push(["publish", JSON.parse(message)]),
    destroy: () => {},
  };
  const source = stripTypeScriptTypes(readFileSync(`home/profiles/pi/extensions/${extension}.ts`, "utf8"))
    .replace(/^import .*\n/gm, "")
    .replace(/export default function/, "globalThis.register = function")
    .replace(/export function/g, "function");
  const sandbox = {
    process: { env: child ? { PI_SUBAGENT_CHILD: "1" } : {}, pid: 123, getuid: () => 1000 },
    basename,
    Type: new Proxy({}, { get: () => () => ({}) }),
    StringEnum: () => ({}),
    net: { createConnection: () => { effects.push(["connect"]); return socket; } },
    spawn: (...argumentsList) => {
      effects.push(["spawn", ...argumentsList]);
      return { on: () => {}, unref: () => {} };
    },
    setTimeout: () => { throw new Error("Unexpected reconnect timer"); },
    clearTimeout: () => {},
  };
  runInNewContext(source, sandbox);
  sandbox.register({
    on: (name, handler) => handlers.set(name, handler),
    registerTool: (tool) => tools.set(tool.name, tool),
    getSessionName: () => "Test session",
    exec: async (...argumentsList) => { effects.push(["exec", ...argumentsList]); return { code: 0 }; },
  });
  const context = {
    cwd: "/project",
    mode: "tui",
    sessionManager: { getSessionFile: () => "/session.json" },
    ui: { setTitle: (title) => effects.push(["title", title]) },
  };
  return { handlers, tools, effects, socketHandlers, context };
}

test("subagents do not register desktop notifications or play coin sounds", () => {
  const state = fixture("notify", true);
  assert.equal(state.handlers.has("agent_settled"), false);
  assert.deepEqual(state.effects, []);
});

test("parent completion still sends a desktop notification and plays the coin sound", async () => {
  const state = fixture("notify", false);
  await state.handlers.get("agent_settled")({}, state.context);
  assert.equal(state.effects[0][0], "exec");
  assert.equal(state.effects[0][1], "coin");
  assert.equal(state.effects[1][0], "spawn");
  assert.equal(state.effects[1][1], "hypr-notify");
});

test("subagents keep their status tool without publishing to Quickshell or changing the terminal title", async () => {
  const state = fixture("session-status", true);
  await state.handlers.get("session_start")({}, state.context);
  await state.handlers.get("agent_start")({}, state.context);
  const result = await state.tools.get("set_session_status").execute("call", {
    status: "done", description: "Child finished", label: "child",
  }, undefined, undefined, state.context);
  assert.equal(result.details.description, "Child finished");
  await state.handlers.get("agent_end")({}, state.context);
  await state.handlers.get("session_shutdown")();
  assert.deepEqual(state.effects, []);
});

test("parent status still publishes to Quickshell", async () => {
  const state = fixture("session-status", false);
  await state.handlers.get("session_start")({}, state.context);
  state.socketHandlers.get("connect")();
  await state.tools.get("set_session_status").execute("call", {
    status: "done", description: "Parent finished",
  }, undefined, undefined, state.context);
  const published = state.effects.filter(([kind]) => kind === "publish").at(-1)[1];
  assert.equal(published.sessionStatus, "done");
  assert.equal(published.sessionDescription, "Parent finished");
  await state.handlers.get("session_shutdown")();
});
