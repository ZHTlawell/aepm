#!/usr/bin/env bash
# claude-usage-report.sh — Claude Enterprise 用量分析报告
# 用法: ./scripts/claude-usage-report.sh [天数, 默认7]
#
# 环境变量:
#   CLAUDE_ANALYTICS_KEY — Enterprise Analytics API Key (必需)
#
# 示例:
#   CLAUDE_ANALYTICS_KEY="sk-ant-api01-..." ./scripts/claude-usage-report.sh 14

set -euo pipefail

DAYS="${1:-7}"
API_KEY="${CLAUDE_ANALYTICS_KEY:-}"

if [[ -z "$API_KEY" ]]; then
  echo "❌ 请设置 CLAUDE_ANALYTICS_KEY 环境变量"
  echo "   export CLAUDE_ANALYTICS_KEY='sk-ant-api01-...'"
  exit 1
fi

# 数据有 3 天延迟
END_DATE=$(date -v-3d +%Y-%m-%d 2>/dev/null || date -d '3 days ago' +%Y-%m-%d)
START_DATE=$(date -v-$((DAYS + 3))d +%Y-%m-%d 2>/dev/null || date -d "$((DAYS + 3)) days ago" +%Y-%m-%d)

BASE_URL="https://api.anthropic.com/v1/organizations/analytics"

echo "📊 Claude Enterprise 用量报告"
echo "   日期范围: $START_DATE → $END_DATE (数据有3天延迟)"
echo "   生成时间: $(date '+%Y-%m-%d %H:%M')"
echo ""

# 拉取所有数据
SUMMARIES=$(curl -s "$BASE_URL/summaries?starting_date=$START_DATE&ending_date=$END_DATE" \
  -H "x-api-key: $API_KEY")

# 检查错误
if echo "$SUMMARIES" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if 'error' not in d else 1)" 2>/dev/null; then
  : # OK
else
  echo "❌ API 错误:"
  echo "$SUMMARIES" | python3 -m json.tool
  exit 1
fi

# 拉取每天的用户数据
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# 找出有活跃数据的日期
ACTIVE_DATES=$(echo "$SUMMARIES" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for s in data.get('summaries', []):
    if s.get('daily_active_user_count', 0) > 0:
        print(s['starting_at'][:10])
")

for d in $ACTIVE_DATES; do
  curl -s "$BASE_URL/users?date=$d&limit=1000" \
    -H "x-api-key: $API_KEY" > "$TMPDIR/users_$d.json" &
done
wait

# 生成报告
SUMMARIES_JSON="$SUMMARIES" TMPDIR_REPORT="$TMPDIR" python3 << 'PYEOF'
import json, sys, os, glob
from collections import defaultdict

tmpdir = os.environ["TMPDIR_REPORT"]
summaries = json.loads(os.environ["SUMMARIES_JSON"])

# ── 概览 ──
print("=" * 80)
print("  组织概览")
print("=" * 80)

active_summaries = [s for s in summaries.get("summaries", []) if s.get("daily_active_user_count", 0) > 0]
if active_summaries:
    latest = active_summaries[-1]
    print(f"  总席位数:       {latest.get('assigned_seat_count', '?')}")
    print(f"  月活用户 (MAU):  {latest.get('monthly_active_user_count', '?')}")
    print(f"  月采用率:       {latest.get('monthly_adoption_rate', '?')}%")
    print(f"  Cowork MAU:     {latest.get('cowork_monthly_active_user_count', '?')}")
    print()

    print("  日活趋势:")
    print(f"  {'日期':12s} | {'DAU':>5} | {'采用率':>8} | {'Cowork DAU':>10}")
    print("  " + "-" * 50)
    for s in active_summaries:
        date = s["starting_at"][:10]
        dau = s.get("daily_active_user_count", 0)
        rate = s.get("daily_adoption_rate", 0)
        cdau = s.get("cowork_daily_active_user_count", 0)
        print(f"  {date:12s} | {dau:>5} | {rate:>7.1f}% | {cdau:>10}")

# ── 用户维度汇总 ──
print()
print("=" * 80)
print("  用户活跃度汇总 (按天累加)")
print("=" * 80)

user_totals = defaultdict(lambda: {
    "chat_msgs": 0, "convos": 0, "cc_sessions": 0,
    "loc_add": 0, "loc_rm": 0, "commits": 0, "prs": 0,
    "files_up": 0, "days_active": 0,
    "connectors": 0, "skills": 0
})

user_files = sorted(glob.glob(os.path.join(tmpdir, "users_*.json")))
for fpath in user_files:
    try:
        with open(fpath) as f:
            data = json.load(f)
    except:
        continue
    for u in data.get("data", []):
        email = u["user"]["email_address"]
        chat = u.get("chat_metrics", {})
        cc = u.get("claude_code_metrics", {}).get("core_metrics", {})
        loc = cc.get("lines_of_code", {})

        t = user_totals[email]
        t["chat_msgs"] += chat.get("message_count", 0)
        t["convos"] += chat.get("distinct_conversation_count", 0)
        t["cc_sessions"] += cc.get("distinct_session_count", 0)
        t["loc_add"] += loc.get("added_count", 0)
        t["loc_rm"] += loc.get("removed_count", 0)
        t["commits"] += cc.get("commit_count", 0)
        t["prs"] += cc.get("pull_request_count", 0)
        t["files_up"] += chat.get("distinct_files_uploaded_count", 0)
        t["connectors"] += chat.get("connectors_used_count", 0)
        t["skills"] += chat.get("distinct_skills_used_count", 0)
        if chat.get("message_count", 0) > 0 or cc.get("distinct_session_count", 0) > 0:
            t["days_active"] += 1

# Sort by total activity
ranked = sorted(user_totals.items(), key=lambda x: x[1]["cc_sessions"] + x[1]["chat_msgs"], reverse=True)

print()
print(f"  {'用户':40s} | {'活跃天':>6} | {'Chat消息':>8} | {'CC会话':>6} | {'LOC+':>7} | {'LOC-':>7} | {'Commits':>7}")
print("  " + "-" * 100)

grand_chat = grand_cc = grand_add = grand_rm = grand_commits = 0
for email, t in ranked:
    name = email.split("@")[0]
    print(f"  {name:40s} | {t['days_active']:>6} | {t['chat_msgs']:>8} | {t['cc_sessions']:>6} | {t['loc_add']:>7,} | {t['loc_rm']:>7,} | {t['commits']:>7}")
    grand_chat += t["chat_msgs"]
    grand_cc += t["cc_sessions"]
    grand_add += t["loc_add"]
    grand_rm += t["loc_rm"]
    grand_commits += t["commits"]

print("  " + "-" * 100)
print(f"  {'合计':40s} | {'':>6} | {grand_chat:>8} | {grand_cc:>6} | {grand_add:>7,} | {grand_rm:>7,} | {grand_commits:>7}")

# ── Top 用户 ──
print()
print("=" * 80)
print("  Top 用户排名")
print("=" * 80)

print("\n  📝 Chat 消息量 Top 5:")
for email, t in sorted(user_totals.items(), key=lambda x: x[1]["chat_msgs"], reverse=True)[:5]:
    if t["chat_msgs"] > 0:
        print(f"    {email.split('@')[0]:35s} {t['chat_msgs']:>6} 条消息")

print("\n  💻 Claude Code 使用量 Top 5:")
for email, t in sorted(user_totals.items(), key=lambda x: x[1]["cc_sessions"], reverse=True)[:5]:
    if t["cc_sessions"] > 0:
        print(f"    {email.split('@')[0]:35s} {t['cc_sessions']:>6} 会话, +{t['loc_add']:,}/-{t['loc_rm']:,} LOC")

print("\n  📈 代码产出 Top 5 (Lines Added):")
for email, t in sorted(user_totals.items(), key=lambda x: x[1]["loc_add"], reverse=True)[:5]:
    if t["loc_add"] > 0:
        print(f"    {email.split('@')[0]:35s} +{t['loc_add']:>7,} 行")

print()
PYEOF
