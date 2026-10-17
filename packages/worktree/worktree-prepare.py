"""Prepare local development files without sharing worktree runtime state."""

import json
import os
import shutil
import sqlite3
import subprocess
import sys
from pathlib import Path


LOCAL_PATHS = (
    ".envrc", ".envrc.local", ".env", ".env.local", ".nix",
    "flake.nix", "flake.lock", "devenv.nix", "devenv.yaml", "devenv.lock",
    "devenv.local.nix", "devenv.local.yaml",
    "AGENTS.md", "CLAUDE.md", ".agents", ".claude", ".pi", ".vscode",
)
SHARED_DIRECTORIES = ("node_modules", ".venv", ".cache")
RUNTIME_PATHS = {".pi/tasks", ".pi/subagents", ".pi/sessions", ".claude/projects"}


def git(directory, *arguments):
    return subprocess.check_output(["git", "-C", str(directory), *arguments])


def tracked_paths(directory):
    return {
        os.fsdecode(value)
        for value in git(directory, "ls-files", "-z").split(b"\0") if value
    }


def prepare(source, destination, fresh=False):
    source = source.resolve(strict=True)
    destination = destination.resolve(strict=True)
    if source == destination:
        raise ValueError("Source and destination must be different worktrees")
    source_common = Path(os.fsdecode(git(source, "rev-parse", "--path-format=absolute", "--git-common-dir")).strip()).resolve()
    destination_common = Path(os.fsdecode(git(destination, "rev-parse", "--path-format=absolute", "--git-common-dir")).strip()).resolve()
    if source_common != destination_common:
        raise ValueError("Source and destination must belong to the same repository")
    source_tracked = tracked_paths(source)
    destination_tracked = tracked_paths(destination)
    synthetic_paths = set()

    def has_tracked_path(relative):
        return any(value == relative or value.startswith(relative + "/") for value in destination_tracked)

    def safe_parent(relative):
        # Never follow a link in the destination back into the original checkout.
        return not any(parent.is_symlink() for parent in (destination / relative).parents if parent != destination and destination in parent.parents)

    def copy_local(relative, ancestors=frozenset()):
        relative_name = relative.as_posix()
        if relative_name in RUNTIME_PATHS or not safe_parent(relative):
            return
        original = source / relative
        target = destination / relative
        if not original.exists() and not original.is_symlink():
            return
        if target.is_symlink():
            if has_tracked_path(relative_name):
                return
            if fresh:
                target.unlink()
            else:
                synthetic_paths.add(relative_name)
                return
        if original.is_dir():
            real_directory = original.resolve()
            if real_directory in ancestors or (target.exists() and not target.is_dir()):
                return
            for entry in sorted(original.iterdir()):
                if entry.name == ".git":
                    continue
                if entry.name in SHARED_DIRECTORIES:
                    link_cache(relative / entry.name)
                else:
                    copy_local(relative / entry.name, ancestors | {real_directory})
            return
        if not original.is_file() or relative_name in source_tracked or has_tracked_path(relative_name):
            return
        if fresh or not target.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            # Dereference local configuration links so child edits stay local.
            shutil.copy2(original, target)
        synthetic_paths.add(relative_name)

    def link_cache(relative):
        relative_name = relative.as_posix()
        original = source / relative
        target = destination / relative
        if not original.is_dir() or has_tracked_path(relative_name) or not safe_parent(relative):
            return
        if not target.exists() and not target.is_symlink():
            target.parent.mkdir(parents=True, exist_ok=True)
            target.symlink_to(original.resolve(), target_is_directory=True)
        if target.is_symlink() and target.resolve() == original.resolve():
            synthetic_paths.add(relative_name)

    for local_path in LOCAL_PATHS:
        copy_local(Path(local_path))

    # Include nested package caches in monorepos without walking node_modules.
    project_directories = {Path(".")}
    for tracked in source_tracked:
        project_directories.update(Path(tracked).parents)
    for directory in sorted(project_directories):
        for cache_name in SHARED_DIRECTORIES:
            link_cache(directory / cache_name)

    # SQLite backup includes committed WAL pages without copying a live DB file.
    # Do not copy devenv services, state, run links, or generated shell scripts:
    # those contain checkout-specific paths or belong to running processes.
    original_database = source / ".devenv/nix-eval-cache.db"
    target_database = destination / ".devenv/nix-eval-cache.db"
    if original_database.is_file() and not has_tracked_path(".devenv/nix-eval-cache.db") and safe_parent(Path(".devenv/nix-eval-cache.db")):
        if not target_database.exists() and not target_database.is_symlink():
            target_database.parent.mkdir(parents=True, exist_ok=True)
            with (
                sqlite3.connect(original_database.as_uri() + "?mode=ro", uri=True) as original_connection,
                sqlite3.connect(target_database) as target_connection,
            ):
                original_connection.backup(target_connection)
        synthetic_paths.add(".devenv/nix-eval-cache.db")

    return {"syntheticPaths": sorted(synthetic_paths)}


if __name__ == "__main__":
    arguments = sys.argv[1:]
    fresh = bool(arguments and arguments[0] == "--fresh")
    if fresh:
        arguments = arguments[1:]
    if len(arguments) != 2:
        sys.exit("Usage: worktree --prepare <source> <destination>")
    print(json.dumps(prepare(Path(arguments[0]), Path(arguments[1]), fresh=fresh)))
