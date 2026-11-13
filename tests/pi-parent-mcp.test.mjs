// Run with: node --test tests/pi-parent-mcp.test.mjs
import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { stripTypeScriptTypes } from "node:module";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";

const source = readFileSync("home/profiles/pi/extensions/parent-mcp.ts", "utf8");
const javascript = stripTypeScriptTypes(source);
const { default: register } = await import(`data:text/javascript;base64,${Buffer.from(javascript).toString("base64")}`);

function fixture() {
  const root = mkdtempSync(join(tmpdir(), "pi-parent-mcp-"));
  const cwd = join(root, "project", "worktrees", "child");
  mkdirSync(cwd, { recursive: true });
  const handlers = new Map();
  const servers = new Map();
  const warnings = [];
  const removed = [];
  register({
    on: (name, handler) => handlers.set(name, handler),
    registerMcpServer: (name, config) => {
      if (!config.url && !config.command) throw new Error("Missing transport");
      servers.set(name, config);
    },
    unregisterMcpServer: (name) => { removed.push(name); servers.delete(name); },
  });
  const configure = (directory, entries) => {
    mkdirSync(join(directory, ".pi"), { recursive: true });
    writeFileSync(join(directory, ".pi", "mcp.json"), JSON.stringify({ mcpServers: entries }));
  };
  const start = (directory = cwd) => handlers.get("session_start")({}, {
    cwd: directory,
    hasUI: true,
    ui: { notify: (message) => warnings.push(message) },
  });
  return { root, cwd, servers, warnings, removed, configure, start, clean: () => rmSync(root, { recursive: true, force: true }) };
}

test("loads all ancestor configs with nearest precedence, leaving the current directory to Pi", () => {
  const fixtureState = fixture();
  try {
    const { root, cwd, configure, start, servers, warnings } = fixtureState;
    configure(root, { distant: { url: "https://distant.example/mcp" }, shared: { url: "https://old.example/mcp", headers: { secret: "old" } } });
    configure(join(root, "project"), { shared: { url: "https://near.example/mcp" }, local: { command: "example", args: ["--stdio"], env: { TOKEN: "${TOKEN}" } } });
    configure(cwd, { current: { url: "https://current.example/mcp" } });
    start();
    assert.equal(servers.get("distant").url, "https://distant.example/mcp");
    assert.deepEqual(servers.get("shared"), { url: "https://near.example/mcp" });
    assert.deepEqual(servers.get("local"), { command: "example", args: ["--stdio"], env: { TOKEN: "${TOKEN}" } });
    assert.equal(servers.has("current"), false);
    assert.deepEqual(warnings, []);
  } finally { fixtureState.clean(); }
});

test("merges state-only overrides and normalizes server names", () => {
  const fixtureState = fixture();
  try {
    const { root, cwd, configure, start, servers } = fixtureState;
    configure(root, { "some-server": { url: "https://example.com/mcp", headers: { Authorization: "${TOKEN}" } } });
    configure(dirname(cwd), { some_server: { enabled: false, exposure: "hidden", headers: { ignored: "value" } } });
    start();
    assert.equal(servers.has("some-server"), false);
    assert.deepEqual(servers.get("some_server"), {
      url: "https://example.com/mcp", headers: { Authorization: "${TOKEN}" }, enabled: false, exposure: "hidden",
    });
  } finally { fixtureState.clean(); }
});

test("reports malformed files and invalid servers without blocking other ancestors", () => {
  const fixtureState = fixture();
  try {
    const { root, cwd, configure, start, servers, warnings } = fixtureState;
    configure(root, { valid: { url: "https://example.com/mcp" }, invalid: { enabled: false }, "bad.name": {} });
    configure(join(root, "project"), {});
    writeFileSync(join(root, "project", ".pi", "mcp.json"), "{secret-invalid-json");
    configure(dirname(cwd), {});
    writeFileSync(join(dirname(cwd), ".pi", "mcp.json"), '{"mcpServers":[]}');
    start();
    assert.equal(servers.has("valid"), true);
    assert.equal(warnings.length, 4);
    assert.match(warnings.join("\n"), /Invalid JSON/);
    assert.match(warnings.join("\n"), /Expected an mcpServers object/);
    assert.doesNotMatch(warnings.join("\n"), /secret-invalid-json/);
  } finally { fixtureState.clean(); }
});

test("refreshes registrations after edits and directory changes", () => {
  const fixtureState = fixture();
  try {
    const { root, cwd, configure, start, servers, removed } = fixtureState;
    configure(join(root, "project"), { original: { url: "https://original.example/mcp" } });
    start();
    configure(join(root, "project"), { replacement: { url: "https://replacement.example/mcp" } });
    start();
    assert.equal(servers.has("original"), false);
    assert.equal(servers.has("replacement"), true);
    assert.deepEqual(removed, ["original"]);
    const other = join(root, "other");
    mkdirSync(other);
    start(other);
    assert.equal(servers.has("replacement"), false);
    start("/");
    assert.deepEqual([...servers], []);
  } finally { fixtureState.clean(); }
});
