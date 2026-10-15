#!/bin/sh
# Open video descriptors indicate possible camera use, not confirmed streaming.
devices=''
for device in /sys/class/video4linux/video*; do
    [ -r "$device/name" ] || continue
    grep -q 'Metadata' "$device/name" && continue
    devices="$devices /dev/${device##*/}"
done
[ -n "$devices" ] || exit 0
# One traversal, regardless of how many video devices exist. Processes may exit
# during the scan; inaccessible descriptors are expected and are skipped.
find /proc/[0-9]*/fd -lname '/dev/video*' -printf '%p\t%l\n' 2>/dev/null |
    awk -v devices="$devices" 'BEGIN { split(devices, names, " "); for (name_index in names) allowed[names[name_index]]=1 }
        allowed[$2] { split($1, parts, "/"); print parts[3] }' |
    sort -u |
    while IFS= read -r process_id; do
        [ -r "/proc/$process_id/comm" ] && head --lines 1 "/proc/$process_id/comm"
    done | sort -u
