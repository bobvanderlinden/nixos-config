#!/usr/bin/env bash

export PI_SKIP_VERSION_CHECK="${PI_SKIP_VERSION_CHECK:-1}"
export PI_TELEMETRY="${PI_TELEMETRY:-0}"

case "${1:-}" in
  install|remove|uninstall|update)
    ;;
  *)
    export PI_OFFLINE="${PI_OFFLINE:-1}"
    ;;
esac

exec pi "$@"
