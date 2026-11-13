---
name: update-flake
description: Update this Nix flake or its inputs, apply the configuration, and commit the lock-file update.
---

Use this skill when asked to update the flake or its inputs.

Run `nix run --impure .#switch` or `nix run --impure .#switch-home` by default.

## Update procedure

1. Inspect the working tree with `git status`, `git diff`, and `git diff --staged`.
2. Commit all existing changes before touching the flake. Split them by logical change. A logical change may cover several files. Do not combine unrelated changes merely because they are present in the working tree. Follow the repository's existing commit-message style.
3. Run `nix flake update`, then use the `nix_build` tool with `action: "start-build"` to build the NixOS and Home Manager configurations. Use this tool for update builds instead of shell build commands. It builds without activating. Wait for its completion notification rather than polling. Keep the broad build running when investigating failures, validate fixes with targeted `nix_build` builds, then start a new broad build after those pass.
4. After the build succeeds, apply the configuration with `nix run --impure .#switch` (or `.#switch-home` for a Home Manager-only update).
5. If the switch succeeds, inspect the resulting lock-file change and commit it separately using the repository's normal input-update commit style.
6. Confirm the working tree is clean and report the commits created and the switch result.
