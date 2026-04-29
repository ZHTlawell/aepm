#!/usr/bin/env bash
# preflight-content-copyright.sh — flag use of copyrighted Bible translations
# (and similar protected-text markers) that lack a corresponding license
# acknowledgement (rule ios-pub-080).
#
# Public-domain whitelist (no acknowledgement required):
#   KJV / ASV / WEB / BBE / Darby / YLT / RV
#
# Copyrighted markers (require explicit license + acknowledgement):
#   NIV / ESV / NASB / NLT / MSG / CSB / NKJV / NRSV / TLV / AMP / HCSB / CEV / GNT
#
# Usage:
#   preflight-content-copyright.sh <project_root>
#
# Exit codes:
#   0 — no copyrighted markers found, OR all found markers are acknowledged
#   1 — copyrighted marker present without matching acknowledgement
#   2 — usage error

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

# Markers that imply copyright. Match patterns like "(NIV)", "[NIV]", " NIV " — but
# tighten to parenthesized / bracketed forms to cut false positives on identifier text.
COPYRIGHTED=(NIV ESV NASB NLT MSG CSB NKJV NRSV TLV AMP HCSB CEV GNT)

# Acknowledgement files we'll search for license declarations.
ACK_FILES=()
while IFS= read -r line; do ACK_FILES+=("$line"); done < <(
    find "$ROOT" -type f \( \
        -iname 'Acknowledgments.md' -o \
        -iname 'Acknowledgements.md' -o \
        -iname 'CREDITS.md' -o \
        -iname 'NOTICE' -o \
        -iname 'NOTICE.md' -o \
        -iname 'Acknowledgments.txt' -o \
        -iname 'CREDITS.txt' \
    \) -not -path '*/Pods/*' -not -path '*/.git/*' 2>/dev/null
)

ACK_BLOB=""
if [[ ${#ACK_FILES[@]} -gt 0 ]]; then
    ACK_BLOB=$(cat "${ACK_FILES[@]}")
fi

# Search source + html + markdown + json for the markers.
SCAN_FILES=()
while IFS= read -r line; do SCAN_FILES+=("$line"); done < <(
    find "$ROOT" -type f \( \
        -name '*.swift' -o -name '*.m' -o -name '*.mm' -o \
        -name '*.html' -o -name '*.md' -o -name '*.txt' -o \
        -name '*.json' -o -name '*.plist' \
    \) \
        -not -path '*/Pods/*' \
        -not -path '*/.build/*' \
        -not -path '*/DerivedData/*' \
        -not -path '*/.git/*' \
        -not -path '*/node_modules/*' \
        2>/dev/null
)

VIOLATIONS=0

echo "═══════════════════════════════════════════════════"
echo "  Content Copyright Scan (ios-pub-080)"
echo "  Project: $ROOT"
echo "  Files scanned: ${#SCAN_FILES[@]}"
echo "  Acknowledgement files: ${#ACK_FILES[@]}"
echo "═══════════════════════════════════════════════════"

for marker in "${COPYRIGHTED[@]}"; do
    # Patterns: (NIV)  [NIV]  , NIV   "NIV"
    pattern="(\\($marker\\)|\\[$marker\\]|\"$marker\"|, $marker[ ,.;)])"
    HITS=()
    while IFS= read -r line; do HITS+=("$line"); done < <(
        grep -RlE "$pattern" "${SCAN_FILES[@]}" 2>/dev/null
    )

    [[ ${#HITS[@]} -eq 0 ]] && continue

    # Acknowledged?
    if grep -qiE "(^|[^A-Z])$marker[^A-Z]" <<<"$ACK_BLOB" \
       && grep -qiE "(used by permission|copyright|all rights reserved|©|licensed)" <<<"$ACK_BLOB"; then
        echo
        echo "ℹ️  $marker — found in ${#HITS[@]} file(s), acknowledgement detected, OK"
        continue
    fi

    VIOLATIONS=$((VIOLATIONS + 1))
    echo
    echo "❌ $marker (copyrighted) used in ${#HITS[@]} file(s) without acknowledgement:"
    for f in "${HITS[@]}"; do
        rel="${f#$ROOT/}"
        echo "   $rel"
    done
done

echo

if [[ $VIOLATIONS -eq 0 ]]; then
    echo "✅ No unacknowledged copyrighted content markers found."
    echo "   (Public-domain Bible translations — KJV / ASV / WEB / BBE — are always safe.)"
    exit 0
fi

echo "Fix:"
echo "   1. Switch to public-domain text (e.g. KJV → safe to embed)"
echo "   2. OR obtain a license and add an Acknowledgments.md with the publisher's"
echo "      required attribution boilerplate (e.g. \"Used by permission of Biblica, Inc.®\")"
exit 1
