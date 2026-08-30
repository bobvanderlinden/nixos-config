#!/usr/bin/env bash

fail() {
  echo "$@" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: agent-worktree <project-or-github-url> [command...]

Creates a worktree, then starts an agent in it.

Examples:
  agent-worktree MediKitRequest
  agent-worktree ~/projects/meditools/MediKitRequest/
  agent-worktree https://github.com/MeditoolsBV/MediKitClient
  agent-worktree https://github.com/MeditoolsBV/MediKitClient/pull/9418
  agent-worktree https://github.com/MeditoolsBV/MediKitClient/issues/9598
EOF
  exit 1
}

if [[ "$1" == "--run" ]]; then
  shift
  command=("$@")
  exec "${command[@]}"
fi

[[ $# -eq 0 ]] && usage
[[ "$1" == "-h" || "$1" == "--help" ]] && usage

project="$1"
shift

if [[ "$project" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
  github_owner_name="${BASH_REMATCH[1]}"
  github_repository_name="${BASH_REMATCH[2]}"
  if [[ "$project" =~ /pull/([0-9]+) ]]; then
    github_pull_request_number="${BASH_REMATCH[1]}"
  elif [[ "$project" =~ /issues/([0-9]+) ]]; then
    github_issue_number="${BASH_REMATCH[1]}"
  fi
fi

worktree_directory="$(worktree "$project")" || fail "Could not create worktree"

context_parts=()
if [[ -n "${github_pull_request_number-}" ]]; then
  context_parts+=("The pull request you're working on is https://github.com/$github_owner_name/$github_repository_name/pull/$github_pull_request_number")
fi
if [[ -n "${github_issue_number-}" ]]; then
  context_parts+=("The issue you're working on is https://github.com/$github_owner_name/$github_repository_name/issues/$github_issue_number")
fi

if [[ ${#context_parts[@]} -gt 0 ]]; then
  context_file="$(mktemp --suffix=.md)"
  printf '%s\n' "${context_parts[@]}" > "$context_file"
  # The OS cleans up this temporary file after Pi reads it.
fi

if [[ $# -gt 0 ]]; then
  command=("$@")
elif [[ -n "${context_file-}" ]]; then
  command=(agent --append-system-prompt "$context_file")
else
  command=(agent)
fi

if [[ -n "${github_pull_request_number-}" ]]; then
  export GITHUB_PR_NUMBER="$github_pull_request_number"
fi
if [[ -n "${github_issue_number-}" ]]; then
  export GITHUB_ISSUE_NUMBER="$github_issue_number"
fi

cd "$worktree_directory" || fail "Could not change to worktree: $worktree_directory"
exec direnv exec . "${command[@]}"
