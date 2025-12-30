#!/usr/bin/env bash
set -euo pipefail

ITERATIONS="${ITERATIONS:-5000}"
EDITS="${EDITS:-200}"

export CC="${CC:-clang}"
export CFLAGS="${CFLAGS:--O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined}"
export LDFLAGS="${LDFLAGS:--fsanitize=address,undefined}"

# LeakSanitizer works on Linux; enable it explicitly.
export ASAN_OPTIONS="${ASAN_OPTIONS:-halt_on_error=1:abort_on_error=1:detect_leaks=1}"

exec tree-sitter fuzz --rebuild --iterations "$ITERATIONS" --edits "$EDITS" "$@"
