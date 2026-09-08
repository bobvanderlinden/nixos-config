#!/usr/bin/env bash

usage() {
  cat >&2 <<'EOF'
Usage: hypr-monitor-place <left|right|up|down>

Places the laptop display relative to the one connected external display.
EOF
  exit 1
}

[[ $# -eq 1 ]] || usage

case "$1" in
  left | right | up | down)
    direction="$1"
    ;;
  --help | -h)
    usage
    ;;
  *)
    usage
    ;;
esac

mapfile -t laptop_outputs < <(
  hyprctl -j monitors | jq --raw-output '.[] | select(.name | test("^eDP-")) | .name'
)
mapfile -t external_outputs < <(
  hyprctl -j monitors | jq --raw-output '.[] | select(.name | test("^eDP-") | not) | .name'
)

if [[ ${#laptop_outputs[@]} -ne 1 ]]; then
  printf 'Expected one laptop display matching eDP-; found %d.\n' "${#laptop_outputs[@]}" >&2
  exit 1
fi

if [[ ${#external_outputs[@]} -ne 1 ]]; then
  printf 'Expected one external display; found %d.\n' "${#external_outputs[@]}" >&2
  exit 1
fi

# Anchor the external display so auto placement has an unambiguous reference.
hyprctl eval "hl.monitor({ output = \"${external_outputs[0]}\", position = \"0x0\" })"
exec hyprctl eval "hl.monitor({ output = \"${laptop_outputs[0]}\", position = \"auto-${direction}\", scale = 1 })"
