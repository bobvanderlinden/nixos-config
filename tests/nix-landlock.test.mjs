import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtemp, mkdir, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import test from "node:test";

const nixCommand = process.env.NIX_LANDLOCK_BINARY;
const nonoCommand = process.env.NONO_COMMAND;

test("Nix evaluates under Landlock without granting reads of the filesystem root", {
  skip: !nixCommand || !nonoCommand ? "Set NIX_LANDLOCK_BINARY and NONO_COMMAND to built executables" : false,
  timeout: 120000,
}, async () => {
  const directory = await mkdtemp(join(tmpdir(), "nix-landlock-test-"));
  const allowedDirectory = join(directory, "allowed");
  const deniedDirectory = join(directory, "denied");
  try {
    await mkdir(allowedDirectory);
    await mkdir(deniedDirectory);
    await writeFile(join(allowedDirectory, "file"), "allowed");
    await writeFile(join(allowedDirectory, "expression.nix"), "21 * 2\n");
    await writeFile(join(deniedDirectory, "file"), "denied");
    await symlink("file", join(allowedDirectory, "link"));
    await symlink("../denied/file", join(allowedDirectory, "denied-link"));
    const profile = join(directory, "profile.json");
    await writeFile(profile, JSON.stringify({
      meta: { name: "nix-landlock-test", description: "Test traversal without root directory read permission" },
      groups: { include: ["nix_runtime", "system_read_linux_core"] },
      filesystem: { allow: [allowedDirectory], read: ["/etc/static", "/etc/nix"] },
      network: { block: true },
      workdir: { access: "none" },
    }));
    function evaluate(expression, { impure = true, raw = false } = {}) {
      const result = spawnSync(resolve(nonoCommand), [
        "run", "--silent", "--no-rollback", "--no-audit", "--profile", profile,
        "--", "/run/current-system/sw/bin/env", `HOME=${allowedDirectory}`,
        `NIX_CONF_DIR=${allowedDirectory}`, "NIX_USER_CONF_FILES=/dev/null", "NIX_CONFIG=",
        resolve(nixCommand), "--store", "dummy://",
        "--extra-experimental-features", "nix-command", "eval",
        ...(impure ? ["--impure"] : []), ...(raw ? ["--raw"] : []), "--expr", expression,
      ], {
        cwd: allowedDirectory,
        // Set Nix's HOME only after entering nono. Otherwise nono's protected
        // state would be inside the directory this test deliberately grants.
        env: process.env,
        encoding: "utf8",
        timeout: 15000,
      });
      assert.ifError(result.error);
      return result;
    }
    function expectValue(expression, expected, options) {
      const result = evaluate(expression, options);
      assert.equal(result.status, 0, result.stderr);
      assert.equal(result.stdout.trim(), expected);
    }
    function expectDenied(expression) {
      const result = evaluate(expression);
      assert.notEqual(result.status, 0, `Unexpected success: ${expression}`);
      assert.match(result.stderr, /Permission denied/, result.stderr);
    }
    expectValue("1 + 1", "2", { impure: false });
    expectValue("1 + 1", "2");
    expectValue(`builtins.readFile ${allowedDirectory}/file`, "allowed", { raw: true });
    expectValue(`builtins.readFile ${allowedDirectory}/link`, "allowed", { raw: true });
    expectValue(`import ${allowedDirectory}/expression.nix`, "42");
    expectValue(`(builtins.readDir ${allowedDirectory}).file`, "regular", { raw: true });
    expectDenied('builtins.readDir "/"');
    expectDenied(`builtins.readDir ${directory}`);
    expectDenied(`builtins.readDir ${deniedDirectory}`);
    expectDenied(`builtins.readFile ${deniedDirectory}/file`);
    expectDenied(`builtins.readFile ${allowedDirectory}/denied-link`);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});
