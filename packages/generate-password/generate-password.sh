#!/usr/bin/env bash
# Generate a human-readable password with SeCrEt- prefix for automatic redaction
# Uses characters that are easier to type: alphanumeric and common special chars
# Character set matches the opencode secret-filter plugin pattern

set -euo pipefail

PREFIX="SeCrEt-"
LENGTH=25
CHARSET='a-zA-Z0-9!@*+'

printf '%s' "$PREFIX"
tr -dc "$CHARSET" </dev/urandom | head -c "$LENGTH"
printf '\n'
