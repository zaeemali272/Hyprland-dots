#!/usr/bin/env bash
for cmd in "$@"; do
    # Strip arguments to find the executable binary
    binary="${cmd%% *}"
    if command -v "$binary" >/dev/null 2>&1; then
        eval "$cmd" &
        exit 0
    fi
done
exit 1