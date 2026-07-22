#!/usr/bin/env bash

export PI_SKIP_VERSION_CHECK="${PI_SKIP_VERSION_CHECK:-1}"

exec pi "$@"
