#!/usr/bin/env bash

usage() {
  cat >&2 <<'EOF'
Usage: hypr-exec [--workspace <name> | --empty-workspace] [--silent] -- <command> [arguments...]

Starts a command through Hyprland's hl.dsp.exec_cmd dispatcher.

--workspace <name>    Start the application on this workspace.
--empty-workspace     Start the application on an unused workspace.
--silent              Do not focus the target workspace. Requires a workspace.
EOF
  exit 1
}

workspace=""
silent=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace)
      [[ -z "$workspace" && -n "${2:-}" ]] || usage
      workspace="$2"
      shift 2
      ;;
    --empty-workspace)
      [[ -z "$workspace" ]] || usage
      workspace="empty"
      shift
      ;;
    --silent)
      silent=true
      shift
      ;;
    --)
      shift
      break
      ;;
    --help | -h)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

[[ $# -gt 0 ]] || usage
[[ "$workspace" =~ ^[a-zA-Z0-9:_-]*$ ]] || usage
[[ "$silent" == false || -n "$workspace" ]] || usage

command=""
for argument in "$@"; do
  printf -v quoted_argument ' %q' "$argument"
  command+="$quoted_argument"
done
command="${command:1}"

lua_command="${command//\\/\\\\}"
lua_command="${lua_command//\"/\\\"}"

if [[ -n "$workspace" ]]; then
  workspace_rule="$workspace"
  if [[ "$silent" == true ]]; then
    workspace_rule+=" silent"
  fi
  exec hyprctl dispatch "hl.dsp.exec_cmd(\"$lua_command\", { workspace = \"$workspace_rule\" })"
else
  exec hyprctl dispatch "hl.dsp.exec_cmd(\"$lua_command\")"
fi
