fail() {
  echo "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: git-pr-clean [pull-request-number]

Fetches the pull request base branch and interactively rebases the current
branch onto it, autosquashing fixup commits.

When no pull request number is supplied, GitHub CLI finds the pull request for
the current branch. The script prefers the upstream remote and falls back to
origin.
EOF
}

if [[ $# -gt 1 ]]; then
  usage >&2
  exit 2
fi

if [[ $# -eq 1 && ( "$1" == "--help" || "$1" == "-h" ) ]]; then
  usage
  exit 0
fi

if [[ "$(git rev-parse --is-inside-work-tree 2> /dev/null)" != "true" ]]; then
  fail "Not inside a Git working tree"
fi

if git remote get-url upstream > /dev/null 2>&1; then
  remote_name="upstream"
elif git remote get-url origin > /dev/null 2>&1; then
  remote_name="origin"
else
  fail "No upstream or origin remote is configured"
fi

if [[ $# -eq 1 ]]; then
  [[ "$1" =~ ^[0-9]+$ ]] || fail "Pull request number must be numeric"
  base_branch="$(gh pr view "$1" --json baseRefName --jq .baseRefName)"
else
  base_branch="$(gh pr view --json baseRefName --jq .baseRefName)"
fi

[[ -n "$base_branch" ]] || fail "Could not determine the pull request base branch"

git fetch --prune "$remote_name" "+refs/heads/$base_branch:refs/remotes/$remote_name/$base_branch"
git rebase \
  --interactive \
  --autosquash \
  --rerere-autoupdate \
  --empty=drop \
  --no-keep-empty \
  --rebase-merges \
  "refs/remotes/$remote_name/$base_branch"
