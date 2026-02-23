#!/usr/bin/env bash

fail() {
  echo "$@" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: agent-worktree <target>

Creates a temporary git worktree for running AI agents.

Target can be:
  project-name                    Bare project name (searches ~/projects/ and ~/projects/meditools/)
  /path/to/project                Direct path to a git repository
  https://github.com/org/repo     GitHub repository URL
  https://github.com/org/repo/pull/123   GitHub pull request URL
  https://github.com/org/repo/issues/123 GitHub issue URL

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
  COMMAND=("$@")
  exec "${COMMAND[@]}"
  exit 0
fi

[[ $# -eq 0 ]] && usage
[[ "$1" == "-h" || "$1" == "--help" ]] && usage

# Parse GitHub repo URL to extract owner, repo name, PR number, and issue number
if [[ "$1" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
  GITHUB_OWNER_NAME="${BASH_REMATCH[1]}"
  GITHUB_REPO_NAME="${BASH_REMATCH[2]}"
  if [[ "$1" =~ /pull/([0-9]+) ]]; then
    GITHUB_PR_NUMBER="${BASH_REMATCH[1]}"
  elif [[ "$1" =~ /issues/([0-9]+) ]]; then
    GITHUB_ISSUE_NUMBER="${BASH_REMATCH[1]}"
  fi
elif [[ -d "$1" ]]; then
  PROJECT_PATH="$1"
else
  GITHUB_REPO_NAME="$1"
fi

shift

if [[ -z "${PROJECT_PATH-}" ]]; then
  PROJECT_PATH="$(zoxide query "$GITHUB_REPO_NAME")"
fi


echo "Using project: $PROJECT_PATH"

# Change to the project directory
cd "$PROJECT_PATH" || fail "Could not change to directory: $PROJECT_PATH"

# Determine the base revision to use

# Check if 'upstream' exists as a remote
if ! git remote get-url upstream > /dev/null 2>&1; then
  git remote add upstream "$(git remote get-url origin)"
  git remote set-head upstream --auto
fi

# Always fetch upstream HEAD to update the reference
git fetch upstream HEAD

if [[ -n "${GITHUB_PR_NUMBER-}" ]]; then
  git fetch upstream pull/"$GITHUB_PR_NUMBER"/head
  BRANCH_NAME="$(git name-rev --name-only FETCH_HEAD)"
  git branch --force "$BRANCH_NAME" FETCH_HEAD
  REVISION="$BRANCH_NAME"
else
  REVISION=upstream/HEAD
fi

WORKTREE_ARGS=(
  --copy devenv.nix
  --copy .envrc.local
  --copy devenv.yaml
  --copy devenv.lock
  --copy flake.nix
  --copy flake.lock
  --copy .nix
  --link .claude
  --link .opencode
  --link opencode.json
  --link .vscode
  --link CLAUDE.md
  --link AGENTS.md
  --revision "$REVISION"
)

# Build context instructions for the agent session
CONTEXT_PARTS=()
if [[ -n "${GITHUB_PR_NUMBER-}" ]]; then
  CONTEXT_PARTS+=("The pull request you're working on is https://github.com/$GITHUB_OWNER_NAME/$GITHUB_REPO_NAME/pull/$GITHUB_PR_NUMBER")
fi
if [[ -n "${GITHUB_ISSUE_NUMBER-}" ]]; then
  CONTEXT_PARTS+=("The issue you're working on is https://github.com/$GITHUB_OWNER_NAME/$GITHUB_REPO_NAME/issues/$GITHUB_ISSUE_NUMBER")
fi

if [[ ${#CONTEXT_PARTS[@]} -gt 0 ]]; then
  CONTEXT_FILE="$(mktemp --suffix=.md)"
  printf '%s\n' "${CONTEXT_PARTS[@]}" > "$CONTEXT_FILE"
  # The temp file is left in /tmp for the OS to clean up; exec replaces this
  # process so a trap on EXIT would fire too early (before opencode reads it).
  EXISTING_CONFIG_CONTENT="${OPENCODE_CONFIG_CONTENT:-{}}"
  export OPENCODE_CONFIG_CONTENT
  OPENCODE_CONFIG_CONTENT="$(printf '%s' "$EXISTING_CONFIG_CONTENT" | jq --arg path "$CONTEXT_FILE" '.instructions += [$path]')"
fi

# Determine the command to run (default: agent)
if [[ $# -gt 0 ]]; then
  COMMAND=("$@")
else
  COMMAND=(agent)
fi

if [[ -n "${GITHUB_PR_NUMBER-}" ]]; then
  export GITHUB_PR_NUMBER
fi
if [[ -n "${GITHUB_ISSUE_NUMBER-}" ]]; then
  export GITHUB_ISSUE_NUMBER
fi

exec git-worktree-shell "${WORKTREE_ARGS[@]}" -- direnv exec . "${COMMAND[@]}"
