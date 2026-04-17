#!/usr/bin/env bash
# preflight-swiftui-lint.sh — wrapper for the SwiftPM-based SwiftUI publish linter.
#
# Usage:
#   preflight-swiftui-lint.sh <project_root> [--json]
#
# On first run, resolves swift-syntax and compiles the binary (~30-60s).
# Subsequent runs reuse the built binary (<1s to launch).
#
# Rules scanned (see templates/pm/constraints/ios-publish-constraints.md for source of truth):
#   ios-pub-010 — Interactive element touch target < 44pt
#   ios-pub-011 — Button / onTapGesture empty or placeholder action closure

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$SCRIPT_DIR/preflight-swiftui-lint"
BINARY="$TOOL_DIR/.build/release/preflight-swiftui-lint"

if [[ $# -lt 1 ]]; then
    echo "usage: $0 <project_root> [--json]" >&2
    exit 2
fi

TARGET="$1"
shift || true

if [[ ! -d "$TARGET" ]]; then
    echo "error: not a directory: $TARGET" >&2
    exit 2
fi

if [[ ! -d "$TOOL_DIR" ]]; then
    echo "error: linter source not found at $TOOL_DIR" >&2
    echo "       (expected ae-pm to have installed scripts/preflight-swiftui-lint/)" >&2
    exit 3
fi

if ! command -v swift >/dev/null 2>&1; then
    echo "error: 'swift' CLI not available. Install Xcode or Swift toolchain." >&2
    exit 3
fi

# Build release binary on first run (or if sources changed).
needs_build=false
if [[ ! -x "$BINARY" ]]; then
    needs_build=true
else
    newest_source=$(find "$TOOL_DIR/Sources" "$TOOL_DIR/Package.swift" -type f -newer "$BINARY" 2>/dev/null | head -1 || true)
    if [[ -n "$newest_source" ]]; then
        needs_build=true
    fi
fi

if [[ "$needs_build" == "true" ]]; then
    echo "[preflight-swiftui-lint] building (first run or sources changed)..." >&2
    (cd "$TOOL_DIR" && swift build -c release) >&2
fi

TARGET_ABS="$(cd "$TARGET" && pwd)"
exec "$BINARY" "$TARGET_ABS" "$@"
