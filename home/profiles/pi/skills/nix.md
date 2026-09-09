---
name: nix
description: Use before using nix or before trying to access /nix/store/**
---

- You are on a NixOS system.
- Never search files or content recursively in `/nix/store`; use `nix-locate` instead.
- To find the package for a specific file, use `nix-locate`.
- To find the package that provides an executable, use `nix-locate --minimal --at-root /bin/<executable>`.
- Prefer `nix-search <package-name>`; avoid `nix search nixpkgs <package-name>`.
- If a package cannot be found, use `nix run nixpkgs#<package-name> -- ...` or `export PATH="$(nix build nixpkgs#<package-name>)/bin:$PATH"`.
