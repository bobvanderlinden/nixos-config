#!/usr/bin/env bash

usage() {
  cat <<'EOF'
Usage: new-agent <project-or-github-url> [prompt]

Creates and focuses an empty Hyprland workspace, creates a worktree for the
first argument or reuses one for the pull request branch, then starts an agent
in a terminal there. When given, prompt
is passed to the agent.

The first argument accepts the same input as worktree: a project name known to
zoxide, a repository directory, a GitHub repository URL, pull request URL, or
issue URL.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 || $# -gt 2 || -z "${1:-}" ]]; then
  usage >&2
  exit 1
fi

project="$1"
prompt="${2:-}"

# Fish runs agent-worktree during initialization, then opens its prompt when it exits.
# shellcheck disable=SC2016 # $1 and $2 expand in the child shell.
exec hypr-exec \
  --empty-workspace \
  --silent \
  -- sh -c '
    if [ -n "$2" ]; then
      NEW_AGENT_PROJECT="$1" NEW_AGENT_PROMPT="$2" exec terminal "$SHELL" \
        --interactive \
        --init-command "agent-worktree --prompt \"\$NEW_AGENT_PROMPT\" \"\$NEW_AGENT_PROJECT\""
    else
      NEW_AGENT_PROJECT="$1" exec terminal "$SHELL" \
        --interactive \
        --init-command "agent-worktree \"\$NEW_AGENT_PROJECT\""
    fi
  ' sh "$project" "$prompt"
