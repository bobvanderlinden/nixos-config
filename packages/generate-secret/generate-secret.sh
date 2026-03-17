#!/usr/bin/env bash
# Generate a machine secret/token with SeCrEt- prefix for automatic redaction
# Uses the full allowed character set for maximum entropy
# Character set matches the opencode secret-filter plugin pattern: a-zA-Z0-9-_?!@&*+

set -euo pipefail

PREFIX="SeCrEt-"
LENGTH=25
CHARSET='a-zA-Z0-9\-_?!@&*+'

printf '%s' "$PREFIX"
tr -dc "$CHARSET" </dev/urandom | head -c "$LENGTH"
printf '\n'
