fail()
{
  echo "$@" >&2
  exit 1
}

OPTION_INDEX="1"
ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --)
      ARGS+=("$@")
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
    -*)
      fail "Unknown option $1"
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

REVISION="HEAD"

if [ "${#ARGS[@]}" -eq 1 ]
then
  REVISION="${ARGS[0]}"
elif [ "${#ARGS[@]}" -gt 1 ]
then
  fail "Too many arguments"
fi

[ -d .git ] || fail "Not a git directory"

REPO_NAME="$(basename "$PWD")"
WORKTREE_DIR="$(mktemp --directory --suffix "$REPO_NAME-worktree")"
git worktree add "$WORKTREE_DIR" "$REVISION"

if [ "$OPTION_INDEX" = 1 ]
then
  # Apply the index of the original worktree to the new one.
  git diff-index -p --cached HEAD | (cd "$WORKTREE_DIR" && git apply --index --allow-empty)
fi

(cd "$WORKTREE_DIR"
  $SHELL || true
  git worktree remove --force "$WORKTREE_DIR" || true
  rm -rf "$WORKTREE_DIR" || true
)
