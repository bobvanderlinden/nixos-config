// Run with: node --test tests/agent-worktree.test.mjs
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { test } from "node:test";

for (const command of [[], ["agent"], ["pi"], ["custom-command"]]) {
  test(`agent-worktree launches ${command[0] ?? "default agent"}`, () => {
    const directory = mkdtempSync(join(tmpdir(), "agent-worktree-test-"));
    const executableDirectory = join(directory, "bin");
    const worktreeDirectory = join(directory, "checkout");
    const log = join(directory, "commands");
    mkdirSync(executableDirectory);
    mkdirSync(worktreeDirectory);
    function executable(name, content) {
      const path = join(executableDirectory, name);
      writeFileSync(path, `#!/usr/bin/env bash\n${content}\n`);
      chmodSync(path, 0o755);
    }
    try {
      executable("worktree", 'printf "%s\\n" "$TEST_WORKTREE"');
      executable("direnv", 'printf "direnv\\n" >> "$TEST_LOG"\nshift 2\nexec "$@"');
      for (const name of ["agent", "pi", "custom-command"]) {
        executable(name, 'printf "%s\\n" "$PWD" "$0" "$@" >> "$TEST_LOG"');
      }
      execFileSync("bash", [resolve("packages/agent-worktree/agent-worktree.sh"), "project", ...command, ...(command.length ? ["argument with spaces"] : [])], {
        env: {
          ...process.env,
          PATH: `${executableDirectory}:${process.env.PATH}`,
          TEST_WORKTREE: worktreeDirectory,
          TEST_LOG: log,
        },
      });
      const output = readFileSync(log, "utf8");
      assert.equal(output.startsWith("direnv\n"), command[0] === "custom-command");
      assert.ok(output.includes(`${worktreeDirectory}\n`));
      assert.ok(output.includes(`${executableDirectory}/${command[0] ?? "agent"}\n`));
      if (command.length) assert.ok(output.endsWith("argument with spaces\n"));
    } finally {
      rmSync(directory, { recursive: true, force: true });
    }
  });
}
