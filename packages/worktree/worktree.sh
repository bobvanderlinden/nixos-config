#!/usr/bin/env bash

fail() {
  echo "$@" >&2
  exit 1
}

usage() {
  cat >&2 <<'EOF'
Usage: worktree <project-or-github-url>

Creates a Git worktree and prints its directory.

The argument may be a project name known to zoxide, a repository directory, a
GitHub repository URL, pull request URL, or issue URL.
EOF
  exit 1
}

[[ $# -eq 1 ]] || usage
[[ "$1" == "--help" || "$1" == "-h" ]] && usage

project="$1"

if [[ "$project" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
  github_owner_name="${BASH_REMATCH[1]}"
  github_repository_name="${BASH_REMATCH[2]}"
  if [[ "$project" =~ /pull/([0-9]+) ]]; then
    github_pull_request_number="${BASH_REMATCH[1]}"
  elif [[ "$project" =~ /issues/([0-9]+) ]]; then
    github_issue_number="${BASH_REMATCH[1]}"
  fi
elif [[ -d "$project" ]]; then
  project_path="$project"
else
  github_repository_name="$project"
fi

if [[ -z "${project_path-}" ]]; then
  project_path="$(zoxide query "$github_repository_name")" || fail "Could not find project: $github_repository_name"
fi

project_path="$(cd "$project_path" && pwd -P)" || fail "Could not change to project: $project_path"
git -C "$project_path" rev-parse --is-inside-work-tree > /dev/null || fail "Not a Git repository: $project_path"

if ! git -C "$project_path" remote get-url upstream > /dev/null 2>&1; then
  git -C "$project_path" remote add upstream "$(git -C "$project_path" remote get-url origin)"
fi

git -C "$project_path" fetch upstream >&2
git -C "$project_path" remote set-head upstream --auto >&2 || true

if [[ -n "${github_pull_request_number-}" ]]; then
  branch_name="$(gh pr view "$github_pull_request_number" --repo "$github_owner_name/$github_repository_name" --json headRefName --jq '.headRefName')"
  git -C "$project_path" fetch upstream "pull/$github_pull_request_number/head" >&2
  git -C "$project_path" branch --force "$branch_name" FETCH_HEAD >&2
  revision="$branch_name"
else
  revision="upstream/HEAD"
fi

repository_name="$(basename "$project_path")"
worktree_base="/tmp/worktrees/$UID/$repository_name"
mkdir --parents "$worktree_base"

if [[ -n "${github_pull_request_number-}" ]]; then
  worktree_directory="$worktree_base/pr-$github_pull_request_number"
elif [[ -n "${github_issue_number-}" ]]; then
  worktree_directory="$worktree_base/issue-$github_issue_number"
else
  worktree_number=1
  while [[ -e "$worktree_base/worktree-$worktree_number" ]]; do
    ((worktree_number++))
  done
  worktree_directory="$worktree_base/worktree-$worktree_number"
fi

[[ ! -e "$worktree_directory" ]] || fail "Worktree directory already exists: $worktree_directory"

git -C "$project_path" worktree add "$worktree_directory" "$revision" >&2

# Apply staged changes from the original checkout to the new worktree.
git -C "$project_path" diff-index --patch --cached HEAD | (
  cd "$worktree_directory" && git apply --index --allow-empty
)

if [[ -f "$worktree_directory/.envrc" ]] && command -v direnv > /dev/null; then
  direnv allow "$worktree_directory" >&2
fi

printf '%s\n' "$worktree_directory"
