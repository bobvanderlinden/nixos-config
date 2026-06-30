#!/usr/bin/env bash
# adhoc: temporarily replace a /nix/store symlink with a writable regular file.
#
# Usage:
#   adhoc PATH            Replace the symlink PATH with a regular file containing
#                         its contents. The original symlink is backed up next to
#                         it as .NAME.backup.
#   adhoc --restore PATH  Restore the original symlink and remove the backup.

set -euo pipefail

prog=$(basename "$0")

usage() {
  cat <<EOF
Usage:
  $prog PATH            Replace symlink PATH (must resolve into /nix/store) with a
                        writable regular file containing its contents.
  $prog --restore PATH  Restore the original symlink and remove the backup.
EOF
}

backup_path() {
  local path=$1
  local dir base
  dir=$(dirname -- "$path")
  base=$(basename -- "$path")
  printf '%s/.%s.backup' "$dir" "$base"
}

do_adhoc() {
  local path=$1
  local backup
  backup=$(backup_path "$path")

  if [[ ! -L "$path" ]]; then
    echo "$prog: warning: $path is not a symlink, leaving it alone" >&2
    exit 1
  fi

  local target
  target=$(readlink --canonicalize-missing -- "$path")
  if [[ "$target" != /nix/store/* ]]; then
    echo "$prog: warning: $path resolves to $target, not /nix/store, leaving it alone" >&2
    exit 1
  fi

  if [[ -e "$backup" ]]; then
    echo "$prog: error: backup $backup already exists; restore first" >&2
    exit 1
  fi

  # Keep the symlink as backup, then replace path with a writable copy.
  mv --no-target-directory -- "$path" "$backup"
  cp --no-target-directory -- "$backup" "$path"
  chmod u+w -- "$path"

  echo "$prog: $path is now a writable file (backup symlink: $backup)"
  echo "$prog: restore with: $prog --restore $path"
}

do_restore() {
  local path=$1
  local backup
  backup=$(backup_path "$path")

  if [[ ! -L "$backup" ]]; then
    echo "$prog: warning: no backup symlink at $backup, nothing to restore" >&2
    exit 1
  fi

  rm --force -- "$path"
  mv --no-target-directory -- "$backup" "$path"
  echo "$prog: restored symlink $path"
}

main() {
  case "${1:-}" in
    --restore)
      [[ $# -eq 2 ]] || { usage >&2; exit 2; }
      do_restore "$2"
      ;;
    -h | --help)
      usage
      ;;
    "")
      usage >&2
      exit 2
      ;;
    *)
      [[ $# -eq 1 ]] || { usage >&2; exit 2; }
      do_adhoc "$1"
      ;;
  esac
}

main "$@"
