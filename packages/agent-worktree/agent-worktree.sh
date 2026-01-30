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

# Find a project by name in known directories
find_project() {
  local name="$1"
  local search_dirs=(
    "$HOME/projects"
    "$HOME/projects/meditools"
    "$HOME/projects/nedap"
  )

  for dir in "${search_dirs[@]}"; do
    if [[ -d "$dir/$name/.git" ]] || [[ -f "$dir/$name/.git" ]]; then
      echo "$dir/$name"
      return 0
    fi
  done

  return 1
}

# Extract repository name from GitHub URL
extract_repo_from_url() {
  local url="$1"
  # Match patterns like:
  # https://github.com/org/repo
  # https://github.com/org/repo/
  # https://github.com/org/repo/pull/123
  # https://github.com/org/repo/issues/123
  # git@github.com:org/repo.git
  if [[ "$url" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
    echo "${BASH_REMATCH[2]}"
    return 0
  fi
  return 1
}

# Extract PR number from GitHub URL if present
extract_pr_number() {
  local url="$1"
  if [[ "$url" =~ /pull/([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

# Extract issue number from GitHub URL if present
extract_issue_number() {
  local url="$1"
  if [[ "$url" =~ /issues/([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

resolve_target() {
  local target="$1"

  # Check if it's a path (starts with / or ~ or .)
  if [[ "$target" =~ ^[/~.] ]]; then
    # Expand ~ if present
    target="${target/#\~/$HOME}"
    # Remove trailing slash
    target="${target%/}"
    if [[ -d "$target/.git" ]] || [[ -f "$target/.git" ]]; then
      echo "$target"
      return 0
    else
      fail "Not a git repository: $target"
    fi
  fi

  # Check if it's a URL
  if [[ "$target" =~ ^https?:// ]] || [[ "$target" =~ ^git@ ]]; then
    local repo_name
    repo_name=$(extract_repo_from_url "$target") || fail "Could not extract repository name from URL: $target"
    local project_path
    project_path=$(find_project "$repo_name") || fail "Could not find local checkout for repository: $repo_name"
    echo "$project_path"
    return 0
  fi

  # Assume it's a bare project name
  local project_path
  project_path=$(find_project "$target") || fail "Could not find project: $target"
  echo "$project_path"
}

[[ $# -eq 0 ]] && usage
[[ "$1" == "-h" || "$1" == "--help" ]] && usage

TARGET="$1"
shift

# Resolve the target to a local git repository path
PROJECT_PATH=$(resolve_target "$TARGET")

echo "Using project: $PROJECT_PATH"

# Change to the project directory
cd "$PROJECT_PATH" || fail "Could not change to directory: $PROJECT_PATH"

# Determine the base revision to use
BASE_REVISION="upstream/HEAD"
if ! git rev-parse --verify "$BASE_REVISION" >/dev/null 2>&1; then
  BASE_REVISION="origin/HEAD"
  if ! git rev-parse --verify "$BASE_REVISION" >/dev/null 2>&1; then
    BASE_REVISION="HEAD"
  fi
fi

# Check for PR or issue in the URL
PR_NUMBER=$(extract_pr_number "$TARGET")
ISSUE_NUMBER=$(extract_issue_number "$TARGET")

WORKTREE_ARGS=(
  --copy devenv.nix
  --copy .envrc.local
  --copy devenv.yaml
  --copy devenv.lock
  --copy flake.nix
  --copy flake.lock
  --link .claude
  --link .cursor
  --link CLAUDE.md
)

# Determine the command to run (default: claude)
if [[ $# -gt 0 ]]; then
  COMMAND=("$@")
else
  COMMAND=(claude)
fi

if [[ -n "$PR_NUMBER" ]]; then
  # For PRs: fetch and checkout the PR head
  echo "Fetching PR #$PR_NUMBER..."
  git fetch upstream "pull/$PR_NUMBER/head" 2>/dev/null || git fetch origin "pull/$PR_NUMBER/head" 2>/dev/null || fail "Could not fetch PR #$PR_NUMBER"
  REVISION="FETCH_HEAD"
  echo "Using PR #$PR_NUMBER revision"
  exec git-worktree-shell --revision "$REVISION" "${WORKTREE_ARGS[@]}" -- direnv exec . "${COMMAND[@]}"
elif [[ -n "$ISSUE_NUMBER" ]]; then
  # For issues: create a worktree from base, then create and checkout a new branch
  BRANCH_NAME="issue-$ISSUE_NUMBER"
  echo "Creating worktree for issue #$ISSUE_NUMBER with new branch: $BRANCH_NAME"
  git branch "$BRANCH_NAME" "$BASE_REVISION"
  exec git-worktree-shell --revision "$BRANCH_NAME" "${WORKTREE_ARGS[@]}" -- direnv exec . "${COMMAND[@]}"
else
  # Default: use base revision
  echo "Using revision: $BASE_REVISION"
  exec git-worktree-shell --revision "$BASE_REVISION" "${WORKTREE_ARGS[@]}" -- direnv exec . "${COMMAND[@]}"
fi
