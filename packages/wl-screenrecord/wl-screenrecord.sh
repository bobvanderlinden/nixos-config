set -o errexit
title="Screen recording"
video_file="$HOME"/recording.mp4
notification_id="$(notify-send --transient --urgency critical --print-id "$title" "Initializing...")"
geometry="$(slurp)"
parallel -j 0 --halt now,done=1 <<EOF
notify-send --replace-id "$notification_id" --transient --urgency critical --wait "$title" "Recording..."
wf-recorder --geometry "$geometry" --overwrite -f "$video_file"
EOF

notify-send --replace-id "$notification_id" --urgency normal --expire-time 5000 "$title" "Recorded video placed on clipboard"

echo -n "file://$video_file" | wl-copy --regular --primary --type text/uri-list
xdg-open "$video_file"
