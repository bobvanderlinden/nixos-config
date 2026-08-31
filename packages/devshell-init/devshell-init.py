#!/usr/bin/env python3

import argparse
from pathlib import Path
import subprocess


def run_git(project_root: Path, *arguments: str) -> str:
    result = subprocess.run(
        ["git", *arguments],
        cwd=project_root,
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def is_tracked(project_root: Path, path: str) -> bool:
    return (
        subprocess.run(
            ["git", "ls-files", "--error-unmatch", "--", path],
            cwd=project_root,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode
        == 0
    )


def add_to_exclude(project_root: Path, git_directory: Path, path: str) -> None:
    if is_tracked(project_root, path):
        return

    exclude_file = git_directory / "info" / "exclude"
    exclude_file.parent.mkdir(parents=True, exist_ok=True)
    exclude_file.touch(exist_ok=True)
    ignored_paths = exclude_file.read_text().splitlines()
    if path not in ignored_paths:
        with exclude_file.open("a") as file:
            file.write(f"{path}\n")


def exists(path: Path) -> bool:
    return path.exists() or path.is_symlink()


def detect_packages(project_root: Path) -> list[str]:
    packages: list[str] = []

    def add(*names: str) -> None:
        for name in names:
            if name not in packages:
                packages.append(name)

    pyproject = project_root / "pyproject.toml"
    pyproject_contents = pyproject.read_text() if pyproject.is_file() else ""
    cmake_lists = project_root / "CMakeLists.txt"
    cmake_contents = cmake_lists.read_text() if cmake_lists.is_file() else ""

    if (project_root / "Cargo.toml").is_file():
        add("cargo", "rustc")
    if (project_root / "package.json").is_file():
        add("nodejs")
    if (project_root / "uv.lock").is_file() or "[tool.uv]" in pyproject_contents:
        add("uv", "python3")
    if (project_root / "poetry.lock").is_file() or "[tool.poetry]" in pyproject_contents:
        add("poetry", "python3")
    if any(
        (project_root / filename).is_file()
        for filename in ("deno.json", "deno.jsonc", "deno.lock")
    ):
        add("deno")
    if any(
        (project_root / filename).is_file()
        for filename in ("bun.lock", "bun.lockb", "bunfig.toml")
    ):
        add("bun")
    if (project_root / "go.mod").is_file():
        add("go")
    if any(
        (project_root / filename).is_file() for filename in ("Justfile", "justfile")
    ):
        add("just", "pkg-config")
    if any(
        (project_root / filename).is_file()
        for filename in ("GNUmakefile", "Makefile", "makefile")
    ):
        add("gnumake", "pkg-config")
    if cmake_lists.is_file():
        add("cmake", "pkg-config")
    if any(project_root.glob("*.pro")) or "Qt" in cmake_contents:
        add("qt6.full")
    if (project_root / "meson.build").is_file():
        add("meson", "ninja")
    if any(
        (project_root / filename).is_file()
        for filename in ("build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts", "gradlew")
    ):
        add("gradle", "jdk")
    if (project_root / "pom.xml").is_file():
        add("maven", "jdk")
    if any(
        (project_root / filename).is_file()
        for filename in ("MODULE.bazel", "WORKSPACE", "WORKSPACE.bazel", ".bazelrc")
    ):
        add("bazelisk")
    if any(
        any(project_root.glob(pattern))
        for pattern in ("*.sln", "*.csproj", "*.fsproj", "*.vbproj")
    ):
        add("dotnet-sdk")
    if (project_root / "build.zig").is_file():
        add("zig")
    if any(project_root.glob("*.cabal")) or any(
        (project_root / filename).is_file() for filename in ("cabal.project", "stack.yaml")
    ):
        add("ghc", "cabal-install")
    if (project_root / "mix.exs").is_file():
        add("beamPackages.elixir")
    if (project_root / "Gemfile").is_file():
        add("ruby", "bundler")
    if (project_root / "composer.json").is_file():
        add("php", "phpPackages.composer")

    return packages


def flake_contents(packages: list[str]) -> str:
    package_lines = "".join(f"              {package}\n" for package in packages)
    return f'''{{
  description = "Local development shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = {{ nixpkgs, ... }}:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
    in
    {{
      devShells = nixpkgs.lib.genAttrs systems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${{system}};
        in
        {{
          default = pkgs.mkShell {{
            packages = with pkgs; [
{package_lines}            ];
          }};
        }}
      );
    }};
}}
'''


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Create a local Nix development shell in a Git repository."
    )
    parser.add_argument("directory", nargs="?", type=Path, default=Path.cwd())
    arguments = parser.parse_args()

    try:
        directory = arguments.directory.resolve(strict=True)
        project_root = Path(run_git(directory, "rev-parse", "--show-toplevel"))
        git_directory = Path(run_git(project_root, "rev-parse", "--git-dir"))
    except (FileNotFoundError, subprocess.CalledProcessError):
        parser.error(f"{arguments.directory}: not inside a Git repository")

    if not git_directory.is_absolute():
        git_directory = project_root / git_directory

    flake = project_root / ".nix" / "flake.nix"
    if exists(flake):
        parser.error(".nix/flake.nix already exists")

    envrc_name = ".envrc.local" if is_tracked(project_root, ".envrc") else ".envrc"
    envrc = project_root / envrc_name
    if exists(envrc):
        parser.error(f"{envrc_name} already exists")

    flake.parent.mkdir(parents=True, exist_ok=True)
    flake.write_text(flake_contents(detect_packages(project_root)))
    envrc.write_text("use flake path:$PWD/.nix\n")

    add_to_exclude(project_root, git_directory, ".nix/")
    add_to_exclude(project_root, git_directory, envrc_name)
    subprocess.run(["direnv", "allow"], cwd=project_root, check=True)
    print(f"Created .nix/flake.nix and {envrc_name}")


if __name__ == "__main__":
    main()
