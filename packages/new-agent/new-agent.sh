#!/usr/bin/env bash

usage() {
  cat <<'EOF'
Usage: new-agent <project-or-github-url> <prompt>

Creates and focuses an empty Hyprland workspace, creates a worktree for the
first argument, then starts an agent with <prompt> in a terminal there.

The first argument accepts the same input as worktree: a project name known to
zoxide, a repository directory, a GitHub repository URL, pull request URL, or
issue URL.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ $# -ne 2 || -z "${1:-}" || -z "${2:-}" ]]; then
  usage >&2
  exit 1
fi

project="$1"
prompt="$2"

worktree_directory="$(worktree "$project")" || exit 1
# shellcheck disable=SC2016 # $1 and $2 expand in the child shell.
exec hypr-exec \
  --empty-workspace \
  --silent \
  -- sh -c 'cd "$1" && exec terminal agent "$2"' sh "$worktree_directory" "$prompt"
