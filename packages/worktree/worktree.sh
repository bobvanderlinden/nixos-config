#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "$@" >&2
  exit 1
}

usage() {
  cat >&2 <<'EOF'
Usage: worktree [--reuse-existing] <project-or-github-url>
       worktree --root <repository>
       worktree --managed --name <name> --branch <branch> --base-ref <ref> <repository>
       worktree --prepare <source> <destination>

Creates a Git worktree and prints its directory. With --reuse-existing, a pull
request branch already checked out in a worktree is reused.

The argument may be a project name known to zoxide, a repository directory, a
GitHub repository URL, pull request URL, or issue URL.
EOF
  exit 1
}

if [[ "${1:-}" == "--prepare" ]]; then
  shift
  [[ $# -eq 2 ]] || usage
  exec python3 "$(dirname "${BASH_SOURCE[0]}")/worktree-prepare.py" "$@"
fi

reuse_existing=false
managed=false
print_root=false
worktree_name=""
managed_branch=""
base_ref=""
managed_directory=""
while [[ $# -gt 0 ]]; do
  case "$1" in
  --reuse-existing)
    reuse_existing=true
    shift
    ;;
  --root)
    print_root=true
    shift
    ;;
  --managed)
    managed=true
    shift
    ;;
  --name | --branch | --base-ref | --directory)
    [[ $# -ge 2 && -n "$2" ]] || usage
    case "$1" in
    --name) worktree_name="$2" ;;
    --branch) managed_branch="$2" ;;
    --base-ref) base_ref="$2" ;;
    --directory) managed_directory="$2" ;;
    esac
    shift 2
    ;;
  *) break ;;
  esac
done
if [[ "$managed" == true ]]; then
  [[ -n "$worktree_name" && -n "$managed_branch" && -n "$base_ref" ]] || usage
  [[ "$worktree_name" != */* && "$worktree_name" != "." && "$worktree_name" != ".." ]] || usage
  [[ -z "$managed_directory" || "$managed_directory" == /* ]] || usage
elif [[ -n "$worktree_name$managed_branch$base_ref$managed_directory" ]]; then
  usage
fi

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
git -C "$project_path" rev-parse --is-inside-work-tree >/dev/null || fail "Not a Git repository: $project_path"
common_directory="$(git -C "$project_path" rev-parse --path-format=absolute --git-common-dir)"
repository_path="$(dirname "$common_directory")"

find_worktree_root() {
  local directory="$repository_path"

  while :; do
    if [[ -d "$directory/.worktrees" ]]; then
      printf '%s\n' "$directory/.worktrees"
      return
    fi

    [[ "$directory" == "/" ]] && return
    directory="$(dirname "$directory")"
  done
}

worktree_root="$(find_worktree_root)"
worktree_root="${worktree_root:-/tmp/worktrees/$UID}"
if [[ "$print_root" == true ]]; then
  printf '%s\n' "$worktree_root"
  exit 0
fi

if [[ "$managed" == false ]]; then
  if ! git -C "$project_path" remote get-url upstream >/dev/null 2>&1; then
    git -C "$project_path" remote add upstream "$(git -C "$project_path" remote get-url origin)"
  fi

  git -C "$project_path" fetch upstream >&2
  git -C "$project_path" remote set-head upstream --auto >&2 || true
fi

if [[ "$managed" == true ]]; then
  revision="$base_ref"
elif [[ -n "${github_pull_request_number-}" ]]; then
  branch_name="$(gh pr view "$github_pull_request_number" --repo "$github_owner_name/$github_repository_name" --json headRefName --jq '.headRefName')"

  if [[ "$reuse_existing" == true ]]; then
    expected_branch="branch refs/heads/$branch_name"
    existing_worktree_directory="$(
      git -C "$project_path" worktree list --porcelain | {
        worktree_directory=""
        while IFS= read -r line; do
          case "$line" in
          "worktree "*) worktree_directory="${line#worktree }" ;;
          "$expected_branch")
            printf '%s\n' "$worktree_directory"
            exit 0
            ;;
          esac
        done
      }
    )"

    if [[ -n "$existing_worktree_directory" ]]; then
      printf '%s\n' "$existing_worktree_directory"
      exit 0
    fi
  fi

  git -C "$project_path" fetch upstream "pull/$github_pull_request_number/head" >&2
  git -C "$project_path" branch --force "$branch_name" FETCH_HEAD >&2
  revision="$branch_name"
else
  revision="upstream/HEAD"
fi

repository_name="$(basename "$repository_path")"
worktree_base="$worktree_root/$repository_name"
mkdir --parents "$worktree_base"

if [[ "$managed" == true ]]; then
  worktree_directory="${managed_directory:-$worktree_base/$worktree_name}"
elif [[ -n "${github_pull_request_number-}" ]]; then
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

if [[ "$managed" == true ]]; then
  WORKTREE_SOURCE_DIRECTORY="$project_path" git -C "$project_path" worktree add "$worktree_directory" -b "$managed_branch" "$revision" >&2
else
  WORKTREE_SOURCE_DIRECTORY="$project_path" git -C "$project_path" worktree add "$worktree_directory" "$revision" >&2
  # Apply staged changes only for interactive worktrees. Managed callers own
  # their base commit and require a clean source checkout.
  git -C "$project_path" diff-index --patch --cached HEAD | (
    cd "$worktree_directory" && git apply --index --allow-empty
  )
fi

# Refresh only during creation, after Git hooks. Older hooks may have copied
# local files from the main checkout instead of the invoking worktree.
python3 "$(dirname "${BASH_SOURCE[0]}")/worktree-prepare.py" --fresh "$project_path" "$worktree_directory" >/dev/null

if [[ -f "$worktree_directory/.envrc" ]] && command -v direnv >/dev/null; then
  direnv allow "$worktree_directory" >&2
fi

printf '%s\n' "$worktree_directory"
