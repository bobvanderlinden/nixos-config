---
name: nix
description: Find Nix packages and use Nix commands. Load whenever you intend to run `nix`, install a package, or identify the package that provides an executable.
---

- Avoid `nix search nixpkgs <package-name>`.
- Prefer `nix-locate --minimal --at-root /bin/<executable>`.
- Prefer `nix-search <package-name>`.
