#!/usr/bin/env bash
# preflight-files-registered.sh — verify every business .swift file is referenced
# in *.xcodeproj/project.pbxproj. Catches the "新增 Swift 未 pod install / xcodegen"
# class of build failure (rule ios-pub-070).
#
# Usage:
#   preflight-files-registered.sh <project_root>
#
# Exit codes:
#   0 — every business .swift is registered
#   1 — one or more files unreferenced
#   2 — usage / no .xcodeproj found

set -uo pipefail

if [[ $# -lt 1 ]]; then
    echo "usage: $0 <project_root>" >&2
    exit 2
fi

ROOT="$1"
if [[ ! -d "$ROOT" ]]; then
    echo "error: not a directory: $ROOT" >&2
    exit 2
fi

ROOT="$(cd "$ROOT" && pwd)"

# Locate all pbxproj files inside .xcodeproj packages.
PBXPROJS=()
while IFS= read -r line; do PBXPROJS+=("$line"); done < <(
    find "$ROOT" -type f -name 'project.pbxproj' \
        -not -path '*/Pods/*' \
        -not -path '*/.build/*' \
        -not -path '*/DerivedData/*' \
        2>/dev/null
)

if [[ ${#PBXPROJS[@]} -eq 0 ]]; then
    echo "error: no project.pbxproj found under $ROOT" >&2
    exit 2
fi

# Collect business swift files (skip Pods, build artifacts, tests).
SWIFT_FILES=()
while IFS= read -r line; do SWIFT_FILES+=("$line"); done < <(
    find "$ROOT" -type f -name '*.swift' \
        -not -path '*/Pods/*' \
        -not -path '*/.build/*' \
        -not -path '*/DerivedData/*' \
        -not -path '*/.swiftpm/*' \
        -not -path '*/build/*' \
        -not -path '*/Carthage/*' \
        -not -path '*/node_modules/*' \
        -not -path '*/.git/*' \
        -not -name 'Package.swift' \
        2>/dev/null
)

# Concatenate all pbxproj content once for O(N) lookup.
PBXPROJ_BLOB=$(cat "${PBXPROJS[@]}")

UNREGISTERED=()
for f in "${SWIFT_FILES[@]}"; do
    base="${f##*/}"
    if ! grep -qF "$base" <<<"$PBXPROJ_BLOB"; then
        UNREGISTERED+=("$f")
    fi
done

echo "═══════════════════════════════════════════════════"
echo "  Files-Registered Pre-Archive Gate (ios-pub-070)"
echo "  Project: $ROOT"
echo "  Swift files scanned: ${#SWIFT_FILES[@]}"
echo "  pbxproj files: ${#PBXPROJS[@]}"
echo "═══════════════════════════════════════════════════"

if [[ ${#UNREGISTERED[@]} -eq 0 ]]; then
    echo
    echo "✅ All .swift files are referenced in at least one Xcode target."
    exit 0
fi

echo
echo "❌ ${#UNREGISTERED[@]} file(s) NOT referenced in any project.pbxproj:"
for f in "${UNREGISTERED[@]}"; do
    rel="${f#$ROOT/}"
    echo "   $rel"
done
echo
echo "Fix:"
echo "   - XcodeGen project: run \`xcodegen generate\`"
echo "   - CocoaPods project: run \`pod install\` (and ensure podspec source_files glob covers the path)"
echo "   - Manual project: add the file via Xcode → File → Add Files"
exit 1
