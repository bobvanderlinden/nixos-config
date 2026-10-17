// Run with: node --test tests/pi-direnv.test.mjs
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, utimesSync, writeFileSync } from "node:fs";
import { stripTypeScriptTypes } from "node:module";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";

const source = readFileSync("home/profiles/pi/extensions/direnv.ts", "utf8");
// The harness needs only the empty parameter schema, not Pi's TypeBox runtime.
const javascript = stripTypeScriptTypes(source).replace(
  'import { Type } from "typebox"',
  "const Type = { Object: () => ({}) }",
);
const { default: register } = await import(`data:text/javascript;base64,${Buffer.from(javascript).toString("base64")}`);

for (const scenario of ["loaded", "failed", "absent"]) {
  test(`headless child direnv: ${scenario}`, async () => {
    const directory = mkdtempSync(join(tmpdir(), "pi-direnv-test-"));
    const previousEnvironment = { ...process.env };
    const handlers = new Map();
    const tools = new Map();
    const context = { cwd: directory, hasUI: false };
    try {
      execFileSync("git", ["init", "--quiet", directory]);
      process.env.DIRENV_CONFIG = join(directory, "direnv-config");
      delete process.env.DIRENV_DIR;
      delete process.env.DIRENV_FILE;
      delete process.env.DIRENV_DIFF;
      delete process.env.DIRENV_WATCHES;
      delete process.env.PI_DIRENV_TEST_VALUE;
      if (scenario !== "absent") {
        writeFileSync(join(directory, ".envrc"), scenario === "failed"
          ? "exit 1\n"
          : "export PI_DIRENV_TEST_VALUE=child-environment\n");
        // direnv records watch timestamps in seconds. Make the later edit distinct
        // without sleeping or depending on which second the test started in.
        const initialTimestamp = new Date(Date.now() - 5000);
        utimesSync(join(directory, ".envrc"), initialTimestamp, initialTimestamp);
      }
      register({
        on: (name, handler) => handlers.set(name, handler),
        registerTool: (tool) => tools.set(tool.name, tool),
      });
      await handlers.get("session_start")({}, context);
      const prompt = await handlers.get("before_agent_start")({ systemPrompt: "Worker instructions" }, context);
      if (scenario === "loaded") {
        assert.equal(process.env.PI_DIRENV_TEST_VALUE, "child-environment");
        assert.match(prompt.systemPrompt, /^Worker instructions\n\n.*automatically loaded/);
        assert.match(prompt.systemPrompt, /Do not source .envrc/);
        assert.equal(execFileSync("bash", ["-c", 'printf "%s" "$PI_DIRENV_TEST_VALUE"'], { encoding: "utf8" }), "child-environment");
        writeFileSync(join(directory, ".envrc"), "export PI_DIRENV_TEST_VALUE=reloaded-environment\n");
        await tools.get("direnv_reload").execute("reload", {}, undefined, undefined, context);
        assert.equal(process.env.PI_DIRENV_TEST_VALUE, "reloaded-environment");
      } else if (scenario === "failed") {
        assert.match(prompt.systemPrompt, /failed to load/);
        assert.doesNotMatch(prompt.systemPrompt, /automatically loaded/);
      } else {
        assert.equal(prompt, undefined);
      }
      await handlers.get("session_shutdown")({}, context);
      assert.equal(process.env.PI_DIRENV_TEST_VALUE, undefined);
    } finally {
      for (const key of Object.keys(process.env)) {
        if (!(key in previousEnvironment)) delete process.env[key];
      }
      Object.assign(process.env, previousEnvironment);
      rmSync(directory, { recursive: true, force: true });
    }
  });
}
