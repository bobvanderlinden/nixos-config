#!/bin/sh
# Open video descriptors indicate possible camera use, not confirmed streaming.
set -eu
export LC_ALL=C
directory=$(mktemp -d)
trap 'rm -rf "$directory"' EXIT HUP INT TERM
devices=''
limited=false
for device in /sys/class/video4linux/video*; do
    [ -e "$device" ] || continue
    if [ ! -r "$device/name" ]; then
        echo "Cannot read camera device name: $device" >&2
        exit 1
    fi
    if grep -q 'Metadata' "$device/name"; then
        continue
    else
        result=$?
        if [ "$result" -ne 1 ]; then exit "$result"; fi
    fi
    devices="$devices /dev/${device##*/}"
done
if [ -z "$devices" ]; then printf 'camera-scan:complete\n'; exit 0; fi
# Expected permission errors and processes exiting during the scan mean limited
# coverage. Any other scan error invalidates the snapshot instead of hiding it.
if ! find /proc/[0-9]*/fd -lname '/dev/video*' -printf '%p\t%l\n' > "$directory/descriptors" 2> "$directory/errors"; then
    if [ ! -s "$directory/errors" ] || grep -vE 'Permission denied|No such file or directory' "$directory/errors" >&2; then
        exit 1
    fi
    limited=true
fi
awk -v devices="$devices" 'BEGIN { split(devices, names, " "); for (name_index in names) allowed[names[name_index]]=1 }
    allowed[$2] { split($1, parts, "/"); print parts[3] }' "$directory/descriptors" > "$directory/processes"
sort -u "$directory/processes" > "$directory/unique-processes"
: > "$directory/names"
while IFS= read -r process_id; do
    if ! head --lines 1 "/proc/$process_id/comm" >> "$directory/names" 2>/dev/null; then limited=true; fi
done < "$directory/unique-processes"
if "$limited"; then printf 'camera-scan:limited\n'; else printf 'camera-scan:complete\n'; fi
sort -u "$directory/names"
