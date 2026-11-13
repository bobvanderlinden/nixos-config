// Run with: node --test tests/pi-terminal-directory.test.mjs
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { stripTypeScriptTypes } from "node:module";
import { hostname } from "node:os";
import { test } from "node:test";

const source = readFileSync("home/profiles/pi/extensions/terminal-directory.ts", "utf8");
const javascript = stripTypeScriptTypes(source);
const { default: register } = await import(`data:text/javascript;base64,${Buffer.from(javascript).toString("base64")}`);

function startSessions(contexts, isTerminal = true) {
  const handlers = new Map();
  register({ on: (name, handler) => handlers.set(name, handler) });
  const output = [];
  const originalWrite = process.stdout.write;
  const originalTerminal = Object.getOwnPropertyDescriptor(process.stdout, "isTTY");
  try {
    Object.defineProperty(process.stdout, "isTTY", { configurable: true, value: isTerminal });
    process.stdout.write = (chunk) => { output.push(chunk); return true; };
    for (const context of contexts) handlers.get("session_start")({}, context);
  } finally {
    process.stdout.write = originalWrite;
    if (originalTerminal) Object.defineProperty(process.stdout, "isTTY", originalTerminal);
    else delete process.stdout.isTTY;
  }
  return output;
}

test("reports the interactive session directory using OSC 7", () => {
  assert.deepEqual(startSessions([{ mode: "tui", cwd: "/home/bob/projects/meditools" }]), [
    `\x1b]7;file://${hostname()}/home/bob/projects/meditools\x1b\\`,
  ]);
});

test("encodes special characters and updates the directory after session replacement", () => {
  assert.deepEqual(startSessions([
    { mode: "tui", cwd: "/projects/space # café%" },
    { mode: "tui", cwd: "/projects/other" },
  ]), [
    `\x1b]7;file://${hostname()}/projects/space%20%23%20caf%C3%A9%25\x1b\\`,
    `\x1b]7;file://${hostname()}/projects/other\x1b\\`,
  ]);
});

test("does not write terminal sequences in non-interactive modes or redirected output", () => {
  for (const mode of ["rpc", "json", "print"]) {
    assert.deepEqual(startSessions([{ mode, cwd: "/projects/meditools" }]), []);
  }
  assert.deepEqual(startSessions([{ mode: "tui", cwd: "/projects/meditools" }], false), []);
});
