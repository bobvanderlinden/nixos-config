// Run with: node --test tests/agent-worktree.test.mjs
import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { test } from "node:test";

test("agent-worktree preserves worktree stderr and exit status", () => {
  const directory = mkdtempSync(join(tmpdir(), "agent-worktree-error-test-"));
  try {
    const executable = join(directory, "worktree");
    writeFileSync(executable, '#!/usr/bin/env bash\nprintf "underlying worktree error\\n" >&2\nexit 141\n');
    chmodSync(executable, 0o755);
    const result = spawnSync("bash", [resolve("packages/agent-worktree/agent-worktree.sh"), "project"], {
      env: { ...process.env, PATH: `${directory}:${process.env.PATH}` },
      encoding: "utf8",
    });
    assert.equal(result.status, 141);
    assert.equal(result.stdout, "");
    assert.match(result.stderr, /underlying worktree error/);
    assert.match(result.stderr, /Could not create worktree \(exit status 141\)/);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

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
