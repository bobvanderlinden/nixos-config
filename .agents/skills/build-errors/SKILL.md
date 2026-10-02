---
name: build-errors
description: Diagnose and fix Nix build or switch failures in this configuration.
---

Use this skill when a Nix build, evaluation, or switch fails.

Run `nix run --impure .#switch` or `nix run --impure .#switch-home` by default.

Read the full failure, identify the first actionable error, and try one fix at a time. Keep every build fix in its own commit, then rerun `nix run --impure .#switch`. Do not bury a fix in a flake-update commit.

Use this order when choosing a fix:

1. Change this configuration to replace deprecated options or otherwise make the build work.
2. Find a relevant NixOS/nixpkgs pull request and patch it through `applyPatches` and `fetchpatch` in `flake.nix`.
3. Find an existing NixOS/nixpkgs issue and apply its workaround when it is small, safe, and directly relevant.
4. Find a relevant upstream-project pull request and patch it in the `workarounds` overlay in `flake.nix`.
5. If no safe fix is available, stop and report the evidence listed below. Do not apply speculative patches.

For a patch, prefer `fetchpatch`, not a manually downloaded patch or inline diff. Prefer GitHub's single-commit patch URL when one commit contains the fix:

```text
https://github.com/{owner}/{repo}/commit/{commit-sha}.patch
```

Otherwise use the pull-request patch URL:

```text
https://github.com/{owner}/{repo}/pull/{pr}.patch
```

Place a comment immediately above every sourced patch that gives the URL and says which build error or missing fix requires it. For example:

```nix
# Fixes foo 1.2.3 failing with "error text" after the flake update.
# Source: https://github.com/owner/repo/commit/abc123.patch
(pkgs.fetchpatch {
  url = "https://github.com/owner/repo/commit/abc123.patch";
  hash = "sha256-...";
})
```

Use `applyPatches` for source patches. Put upstream-project patches in the `workarounds` overlay. Keep the patch narrow and remove it once the fix reaches the pinned upstream version.

Write each build-fix commit with a useful body. State the build error, the chosen remedy, the source URL or issue, and why the workaround belongs in the configuration. Keep the lock-file update as a separate commit unless the repository already has a clear convention that requires otherwise.

## Reporting an unresolved failure

If the error remains unresolved, report:

- the exact failing package and salient error output;
- existing NixOS/nixpkgs issues;
- existing upstream-project issues;
- related NixOS/nixpkgs pull requests;
- related upstream changelog entries; and
- related upstream pull requests.

Link every issue and pull request. Say which candidate fixes were considered and why none was applied.
