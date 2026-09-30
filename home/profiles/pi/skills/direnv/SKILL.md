---
name: direnv
description: Work with project development environments that use direnv, Nix flakes, and local virtual environments.
---

# Project development environments

Most projects load `.envrc` automatically. Do not manually source it.

## Create an environment

Read the project's `.envrc`, existing flake, and local instructions first. If it has no local development shell, run this from the Git repository root:

```sh
devshell-init
```

`devshell-init` detects common project files and creates `.nix/flake.nix` with the matching tools. It creates `.envrc.local` when the project already tracks `.envrc`, otherwise it creates `.envrc`. It excludes the generated paths through `.git/info/exclude` and runs `direnv allow`. It stops rather than overwriting an existing flake or environment file.

For manual setup, put development tools in the flake's `devShells.<system>.default` package list. Put local setup in `.envrc.local` when the project tracks `.envrc`. Exclude local files through `.git/info/exclude`, not `.gitignore`.

Use `use flake path:$PWD/.nix` for a local ignored flake. A plain relative flake path inside a Git repository can hide ignored files from Nix. Test it without adding it to Git:

```sh
nix develop path:./.nix --command <command>
```

## Python projects

Provide `python3` and `uv` in the flake. Create the virtual environment in `.envrc.local` and install the pinned requirements:

```sh
use flake path:$PWD/.nix

if [ ! -x .venv/bin/python ]; then
    uv venv .venv
fi

source .venv/bin/activate
uv pip install --requirements requirements.txt
```

Activate `.venv` before running project Python commands when the project instructions require it.
