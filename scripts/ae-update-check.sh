#!/usr/bin/env bash
# ae-update-check.sh — Claude Code SessionStart hook
# Silently checks ae-pm/ae-go repos for updates, auto-pulls if available,
# and writes changelog diff to cache file for agent to display.
# Runs at most once every 24 hours. Most invocations exit in <10ms.

set -e

AE_HOME="${AE_HOME:-$HOME/.ae}"
CONFIG_DIR="$HOME/.config/ae"
CACHE_FILE="$CONFIG_DIR/.update-available"
CHECK_FILE="$CONFIG_DIR/.last-update-check-hook"

mkdir -p "$CONFIG_DIR"

# Read hook input from stdin (required by Claude Code hook protocol)
cat >/dev/null 2>&1 || true

# Rate limit: check at most once per 24 hours
LAST_CHECK=$(cat "$CHECK_FILE" 2>/dev/null || echo "0")
NOW=$(date +%s)
if (( NOW - LAST_CHECK < 86400 )); then
    exit 0
fi

# Update timestamp
echo "$NOW" > "$CHECK_FILE"

# Check and auto-update each installed role
UPDATES=""
for ROLE in pm go; do
    REPO="$AE_HOME/$ROLE"
    [ -d "$REPO/.git" ] || continue

    # Detect default branch (main or master)
    BRANCH=$(git -C "$REPO" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
    if [ -z "$BRANCH" ]; then
        for b in main master; do
            if git -C "$REPO" show-ref --verify --quiet "refs/remotes/origin/$b" 2>/dev/null; then
                BRANCH="$b"
                break
            fi
        done
    fi
    [ -z "$BRANCH" ] && continue

    git -C "$REPO" fetch origin "$BRANCH" --quiet 2>/dev/null || continue

    BEHIND=$(git -C "$REPO" rev-list "HEAD..origin/$BRANCH" --count 2>/dev/null || echo "0")
    if [ "$BEHIND" -gt 0 ]; then
        BEFORE=$(git -C "$REPO" rev-parse HEAD 2>/dev/null)
        OLD_VER=$(head -3 "$REPO/CHANGELOG.md" 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)

        # Auto pull
        git -C "$REPO" pull origin "$BRANCH" --quiet 2>/dev/null || continue

        NEW_VER=$(head -3 "$REPO/CHANGELOG.md" 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)

        # Extract changelog diff (new entries between old and new version)
        CHANGELOG_DIFF=""
        if [ -n "$OLD_VER" ] && [ -n "$NEW_VER" ] && [ "$OLD_VER" != "$NEW_VER" ]; then
            # Get lines from top until we hit the old version header
            CHANGELOG_DIFF=$(awk "/^## $OLD_VER/{exit} /^##/{found=1} found{print}" "$REPO/CHANGELOG.md" 2>/dev/null | head -30)
        fi

        ENTRY="ae-${ROLE} 已自动更新: ${OLD_VER:-?} → ${NEW_VER:-?}"
        if [ -n "$CHANGELOG_DIFF" ]; then
            ENTRY="${ENTRY}
${CHANGELOG_DIFF}"
        fi

        if [ -n "$UPDATES" ]; then
            UPDATES="${UPDATES}

"
        fi
        UPDATES="${UPDATES}${ENTRY}"
    fi
done

# Write cache
if [ -n "$UPDATES" ]; then
    echo "$UPDATES" > "$CACHE_FILE"
else
    rm -f "$CACHE_FILE"
fi

exit 0
