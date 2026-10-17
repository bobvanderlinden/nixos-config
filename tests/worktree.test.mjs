// Run with: node --test tests/worktree.test.mjs
// Set WORKTREE_COMMAND and PI_SUBAGENTS_PACKAGE to test the Nix-built integration.
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { test } from "node:test";

const worktreeCommand = process.env.WORKTREE_COMMAND ?? resolve("packages/worktree/worktree.sh");
function worktree(argumentsList, environment) {
  return execFileSync("bash", [worktreeCommand, ...argumentsList], {
    env: environment, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"],
  }).trim();
}
function git(directory, ...argumentsList) {
  return execFileSync("git", ["-C", directory, ...argumentsList], { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }).trim();
}
function fixture() {
  const directory = mkdtempSync(join(tmpdir(), "worktree-integration-"));
  const repository = join(directory, "project");
  mkdirSync(repository);
  mkdirSync(join(directory, ".worktrees"));
  git(repository, "init", "--quiet");
  git(repository, "config", "user.email", "test@example.invalid");
  git(repository, "config", "user.name", "Worktree test");
  function write(relative, content) {
    mkdirSync(dirname(join(repository, relative)), { recursive: true });
    writeFileSync(join(repository, relative), content);
  }
  write("tracked.txt", "committed\n");
  write("packages/example/package.json", "{}\n");
  write(".pi/settings.json", "{}\n");
  write(".gitignore", ".nix/\n.envrc.local\n.envrc\n.env\nnode_modules/\n.venv/\n.cache/\n.devenv/\n.agents/\n.pi/skills/\n.pi/tasks/\n");
  git(repository, "add", ".");
  git(repository, "commit", "--quiet", "--message", "Initial commit");
  write(".envrc", 'source_env_if_exists .envrc.local\n');
  write(".envrc.local", "export WORKTREE_TEST_ENV=loaded\n");
  write(".env", "LOCAL_VALUE=original\n");
  write(".nix/flake.nix", "local development shell\n");
  write(".agents/skills/local/SKILL.md", "Local instructions\n");
  write(".pi/skills/local/SKILL.md", "Local Pi instructions\n");
  write(".pi/tasks/parent-state", "Do not copy this\n");
  write("node_modules/dependency/index.js", "cached dependency\n");
  write("packages/example/node_modules/dependency/index.js", "nested dependency\n");
  write(".venv/bin/python", "cached interpreter\n");
  write(".devenv/state/service", "Do not share this\n");
  execFileSync("python3", ["-c", "import sqlite3, sys; connection = sqlite3.connect(sys.argv[1]); connection.execute('create table cache (value text)'); connection.execute(\"insert into cache values ('cached evaluation')\"); connection.commit()", join(repository, ".devenv/nix-eval-cache.db")]);
  return {
    directory, repository,
    environment: { ...process.env, DIRENV_CONFIG: join(directory, "direnv-config") },
    cleanup: () => rmSync(directory, { recursive: true, force: true }),
  };
}

test("worktree uses shared paths and prepares local configuration and caches", () => {
  const context = fixture();
  const { repository, directory, environment } = context;
  try {
    assert.equal(worktree(["--root", repository], environment), join(directory, ".worktrees"));
    const destination = worktree(["--managed", "--name", "child", "--branch", "test-child", "--base-ref", "HEAD", repository], environment);
    assert.equal(destination, join(directory, ".worktrees/project/child"));
    assert.equal(git(destination, "rev-parse", "HEAD"), git(repository, "rev-parse", "HEAD"));
    for (const relative of [".envrc", ".envrc.local", ".env", ".nix/flake.nix", ".agents/skills/local/SKILL.md", ".pi/skills/local/SKILL.md"]) {
      assert.equal(readFileSync(join(destination, relative), "utf8"), readFileSync(join(repository, relative), "utf8"));
    }
    assert.equal(existsSync(join(destination, ".pi/tasks")), false);
    assert.equal(existsSync(join(destination, ".devenv/state")), false);
    assert.equal(readFileSync(join(destination, ".pi/settings.json"), "utf8"), "{}\n");
    assert.equal(realpathSync(join(destination, "node_modules")), join(repository, "node_modules"));
    assert.equal(realpathSync(join(destination, "packages/example/node_modules")), join(repository, "packages/example/node_modules"));
    assert.equal(realpathSync(join(destination, ".venv")), join(repository, ".venv"));
    assert.notEqual(realpathSync(join(destination, ".devenv/nix-eval-cache.db")), join(repository, ".devenv/nix-eval-cache.db"));
    assert.equal(execFileSync("python3", ["-c", "import sqlite3, sys; print(sqlite3.connect(sys.argv[1]).execute('select value from cache').fetchone()[0])", join(destination, ".devenv/nix-eval-cache.db")], { encoding: "utf8" }).trim(), "cached evaluation");
    writeFileSync(join(destination, ".envrc.local"), "child-only changes\n");
    assert.equal(readFileSync(join(repository, ".envrc.local"), "utf8"), "export WORKTREE_TEST_ENV=loaded\n");
    const metadata = JSON.parse(worktree(["--prepare", repository, destination], environment));
    assert.ok(metadata.syntheticPaths.includes("node_modules"));
    assert.ok(metadata.syntheticPaths.includes(".nix/flake.nix"));
    assert.ok(!metadata.syntheticPaths.includes(".pi/settings.json"));
    const grandchild = worktree(["--managed", "--name", "grandchild", "--branch", "test-grandchild", "--base-ref", "HEAD", destination], environment);
    assert.equal(grandchild, join(directory, ".worktrees/project/grandchild"));
    assert.equal(worktree(["--root", grandchild], environment), join(directory, ".worktrees"));
    assert.equal(readFileSync(join(grandchild, ".envrc.local"), "utf8"), "child-only changes\n");
  } finally {
    context.cleanup();
  }
});

test("interactive worktree retains upstream and staged-change behavior", () => {
  const context = fixture();
  try {
    git(context.repository, "remote", "add", "origin", context.repository);
    writeFileSync(join(context.repository, "tracked.txt"), "staged change\n");
    git(context.repository, "add", "tracked.txt");
    const destination = worktree([context.repository], context.environment);
    assert.equal(destination, join(context.directory, ".worktrees/project/worktree-1"));
    assert.equal(readFileSync(join(destination, "tracked.txt"), "utf8"), "staged change\n");
    assert.equal(readFileSync(join(destination, ".nix/flake.nix"), "utf8"), "local development shell\n");
  } finally {
    context.cleanup();
  }
});

test("Git checkout hook uses the same preparation helper", () => {
  const context = fixture();
  try {
    const executableDirectory = join(context.directory, "bin");
    mkdirSync(executableDirectory);
    const wrapper = join(executableDirectory, "worktree");
    writeFileSync(wrapper, `#!/usr/bin/env bash\nexec bash ${JSON.stringify(worktreeCommand)} "$@"\n`);
    chmodSync(wrapper, 0o755);
    const destination = join(context.directory, ".worktrees/project/direct-git");
    execFileSync("git", ["-C", context.repository, "-c", `core.hooksPath=${resolve("home/git-hooks")}`, "worktree", "add", "--detach", destination, "HEAD"], {
      env: { ...context.environment, PATH: `${executableDirectory}:${process.env.PATH}` },
      stdio: ["ignore", "pipe", "pipe"],
    });
    assert.equal(readFileSync(join(destination, ".nix/flake.nix"), "utf8"), "local development shell\n");
    assert.equal(readFileSync(join(destination, ".agents/skills/local/SKILL.md"), "utf8"), "Local instructions\n");
    assert.equal(realpathSync(join(destination, "node_modules")), join(context.repository, "node_modules"));
    assert.equal(existsSync(join(destination, ".pi/tasks")), false);
  } finally {
    context.cleanup();
  }
});

test("worktree falls back to the existing per-user temporary root", () => {
  const directory = mkdtempSync(join(tmpdir(), "worktree-fallback-"));
  try {
    git(directory, "init", "--quiet");
    assert.equal(worktree(["--root", directory], process.env), `/tmp/worktrees/${process.getuid()}`);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test("pi-subagents allocates through worktree and excludes synthetic files from handoff", {
  skip: !process.env.PI_SUBAGENTS_PACKAGE,
}, async () => {
  const context = fixture();
  const previousConfig = process.env.DIRENV_CONFIG;
  process.env.DIRENV_CONFIG = context.environment.DIRENV_CONFIG;
  try {
    const modulePath = join(process.env.PI_SUBAGENTS_PACKAGE, "src/runs/shared/worktree.js");
    const { createWorktrees, resolveExpectedWorktreeAgentCwd, diffWorktrees } = await import(pathToFileURL(modulePath));
    const hook = join(context.directory, "setup-hook.mjs");
    writeFileSync(hook, `#!/usr/bin/env node\nimport { readFileSync } from 'node:fs';\nimport { execFileSync } from 'node:child_process';\nconst input = JSON.parse(readFileSync(0, 'utf8'));\nprocess.stdout.write(execFileSync(${JSON.stringify(worktreeCommand)}, ['--prepare', input.repoRoot, input.worktreePath]));\n`);
    chmodSync(hook, 0o755);
    const snapshots = [];
    const setup = await createWorktrees(context.repository, "integration-test", 1, {
      provider: "native", setupHook: { hookPath: hook }, onProgress: snapshot => snapshots.push(snapshot),
    });
    const destination = setup.worktrees[0].path;
    assert.equal(destination, join(context.directory, ".worktrees/project/pi-worktree-integration-test-0"));
    assert.equal(resolveExpectedWorktreeAgentCwd(context.repository, "integration-test", 0), destination);
    assert.ok(snapshots.some(snapshot => snapshot.command?.command === worktreeCommand && snapshot.command.args.includes("--managed")));
    assert.ok(setup.worktrees[0].syntheticPaths.includes(".envrc.local"));
    assert.ok(setup.worktrees[0].syntheticPaths.includes("node_modules"));
    const loaded = execFileSync("direnv", ["exec", destination, "bash", "-c", 'printf "%s" "$WORKTREE_TEST_ENV"'], { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
    assert.equal(loaded, "loaded");
    writeFileSync(join(destination, "tracked.txt"), "child implementation\n");
    const diffs = diffWorktrees(setup, ["worker"], join(context.directory, "diffs"));
    assert.equal(diffs.length, 1);
    const patch = readFileSync(diffs[0].patchPath, "utf8");
    assert.match(patch, /child implementation/);
    assert.doesNotMatch(patch, /node_modules|\.envrc|\.nix\/|\.agents\/|\.pi\/skills/);
    assert.ok(existsSync(join(context.repository, "node_modules/dependency/index.js")));
    assert.ok(existsSync(join(context.repository, ".nix/flake.nix")));
  } finally {
    if (previousConfig === undefined) delete process.env.DIRENV_CONFIG;
    else process.env.DIRENV_CONFIG = previousConfig;
    context.cleanup();
  }
});
