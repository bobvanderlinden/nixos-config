fail()
{
  echo "$@" >&2
  exit 1
}

report_current_directory()
{
  local directory="$1"
  local character
  local encoded_directory=""
  local index

  [[ -t 1 ]] || return

  # OSC 7 uses a file URI. Percent-encode the path so a repository name with
  # whitespace or control characters cannot invalidate or inject terminal data.
  local LC_ALL=C
  for ((index = 0; index < ${#directory}; index++)); do
    character="${directory:index:1}"
    case "$character" in
      [a-zA-Z0-9.~_/-]) encoded_directory+="$character" ;;
      *)
        printf -v character '%%%02X' "'$character"
        encoded_directory+="$character"
        ;;
    esac
  done

  printf '%b' "\033]7;file://${encoded_directory}\033\\"
}

REVISION="HEAD"
OPTION_INDEX="1"
ARGS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    --)
      shift
      ARGS=("$@")
      break
      ;;
    --no-index)
      OPTION_INDEX="0"
      shift
      ;;
    --index)
      OPTION_INDEX="1"
      shift
      ;;
    --revision)
      shift
      REVISION="$1"
      shift
      ;;
    -*)
      fail "Unknown option $1"
      ;;
    *)
      # First non-option argument starts the command; take all remaining args
      ARGS=("$@")
      break
      ;;
  esac
done

[ -d .git ] || fail "Not a git directory"

REPO_NAME="$(basename "$PWD")"
WORKTREE_BASE="/tmp/worktrees/$UID/$REPO_NAME"
mkdir --parents "$WORKTREE_BASE"
WORKTREE_DIR="$(mktemp --directory "$WORKTREE_BASE/XXXXXX")"
git worktree add "$WORKTREE_DIR" "$REVISION"

cleanup() {
  git worktree remove --force "$WORKTREE_DIR" || true
  rm -rf "$WORKTREE_DIR" || true
}
trap cleanup EXIT

if [ "$OPTION_INDEX" = 1 ]
then
  # Apply the index of the original worktree to the new one.
  git diff-index -p --cached HEAD | (cd "$WORKTREE_DIR" && git apply --index --allow-empty)
fi

if [ -f "$WORKTREE_DIR/.envrc" ] && command -v direnv > /dev/null; then
  direnv allow "$WORKTREE_DIR"
fi

cd "$WORKTREE_DIR" || fail "Failed to cd to worktree directory"
report_current_directory "$PWD"

if [ "${#ARGS[@]}" -gt 0 ]
then
  "${ARGS[@]}" || true
else
  $SHELL || true
fi
