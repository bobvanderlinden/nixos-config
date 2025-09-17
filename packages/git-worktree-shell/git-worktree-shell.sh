fail()
{
  echo "$@" >&2
  exit 1
}

REVISION="HEAD"
OPTION_INDEX="1"
ARGS=()
LINKS=()
COPY=()

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
    --link)
      shift
      LINKS+=("$1")
      shift
      ;;
    --copy)
      shift
      COPY+=("$1")
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
      ARGS+=("$1")
      shift
      ;;
  esac
done

[ -d .git ] || fail "Not a git directory"

REPO_NAME="$(basename "$PWD")"
WORKTREE_DIR="$(mktemp --directory --suffix "$REPO_NAME-worktree")"
git worktree add "$WORKTREE_DIR" "$REVISION"

if [ "$OPTION_INDEX" = 1 ]
then
  # Apply the index of the original worktree to the new one.
  git diff-index -p --cached HEAD | (cd "$WORKTREE_DIR" && git apply --index --allow-empty)
fi

for link in "${LINKS[@]}"; do
  [ -e "$WORKTREE_DIR/$link" ] || [ -e "$PWD/$link" ] && ln -s "$PWD/$link" "$WORKTREE_DIR/$link"
done

for copy in "${COPY[@]}"; do
  [ -e "$WORKTREE_DIR/$copy" ] || [ -e "$PWD/$copy" ] && cp -r "$PWD/$copy" "$WORKTREE_DIR/$copy"
done

if [ -f "$WORKTREE_DIR/.envrc" ] && command -v direnv > /dev/null; then
  direnv allow "$WORKTREE_DIR"
fi

(cd "$WORKTREE_DIR" || fail "Failed to cd to worktree directory"
  if [ "${#ARGS[@]}" -gt 0 ]
  then
    "${ARGS[@]}"
  else
    $SHELL || true
  fi
  git worktree remove --force "$WORKTREE_DIR" || true
  rm -rf "$WORKTREE_DIR" || true
)
