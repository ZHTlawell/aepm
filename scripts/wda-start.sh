#!/usr/bin/env bash
# wda-start.sh — 一键启动 WDA 环境（tunnel + xcodebuild + forward + verify）
#
# Usage:
#   bash wda-start.sh                          # 自动检测设备，端口 8100
#   bash wda-start.sh --udid XXXX              # 指定设备 UDID
#   bash wda-start.sh --udid XXXX --port 8101  # 第二台设备用不同端口（多 session 并行）
#   bash wda-start.sh --check-only             # 只检查不启动
#
# 多 session 并行规则:
#   - pkill 按 UDID 精确匹配，不影响其他 session 的 WDA/forward
#   - userspace tunnel 若已存在则复用（不 kill 重启，避免影响并行设备）
#   - 日志文件按端口隔离: /tmp/wda-xcodebuild-${PORT}.log
#
# 需要: go-ios (https://github.com/danielpaulus/go-ios)

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

WDA_PORT=8100
MAX_RETRIES=3

log()  { echo -e "${GREEN}[wda]${NC} $*"; }
warn() { echo -e "${YELLOW}[wda]${NC} $*"; }
err()  { echo -e "${RED}[wda]${NC} $*" >&2; }

# Parse args
UDID=""
CHECK_ONLY=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --udid) UDID="$2"; shift 2 ;;
        --port) WDA_PORT="$2"; shift 2 ;;
        --check-only) CHECK_ONLY=true; shift ;;
        *) err "Unknown arg: $1"; exit 1 ;;
    esac
done

# Per-port xcodebuild log to avoid stomping across parallel sessions
XCB_LOG="/tmp/wda-xcodebuild-${WDA_PORT}.log"

# Step 1: Check device
log "Step 1: 检查设备连接..."
if ! command -v ios &>/dev/null; then
    err "go-ios 未安装。运行 /ae-mobile-setup 或: go install github.com/danielpaulus/go-ios/v2@latest"
    exit 1
fi

DEVICE_JSON=$(ios list 2>/dev/null || true)
DEVICE_COUNT=$(echo "$DEVICE_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    devices = data.get('deviceList', [])
    print(len(devices))
except:
    print(0)
" 2>/dev/null || echo "0")

if [[ "$DEVICE_COUNT" == "0" ]]; then
    err "未检测到 iOS 设备。请检查 USB 连接。"
    exit 1
fi

# Auto-detect UDID if not specified
if [[ -z "$UDID" ]]; then
    UDID=$(echo "$DEVICE_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
item = data['deviceList'][0]
print(item['serialNumber'] if isinstance(item, dict) else item)
" 2>/dev/null || true)
fi

if [[ -z "$UDID" ]]; then
    err "无法获取设备 UDID"
    exit 1
fi
log "设备: ${BOLD}$UDID${NC}"

# Step 1.5: Detect iOS version
IOS_VERSION=$(echo "$DEVICE_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for d in data.get('deviceList', []):
    if isinstance(d, dict) and d.get('serialNumber', '') == '$UDID':
        print(d.get('productVersion', ''))
        break
" 2>/dev/null || true)

IOS_MAJOR=""
if [[ -n "$IOS_VERSION" ]]; then
    IOS_MAJOR=$(echo "$IOS_VERSION" | cut -d. -f1)
    log "iOS 版本: ${BOLD}$IOS_VERSION${NC}"
    if [[ "$IOS_MAJOR" -ge 26 ]]; then
        warn "⚠️  检测到 iOS $IOS_VERSION（beta）— WDA 兼容性可能不完整"
        warn "   已知问题: go-ios DDI 下载可能不匹配 (go-ios#704)"
        warn "   建议: 确保 Xcode 版本与 iOS beta 匹配，必要时手动挂载 DDI"
    fi
else
    warn "无法获取 iOS 版本号（go-ios 版本可能较旧），继续..."
fi

# Step 2: Check if WDA is already running
log "Step 2: 检查 WDA 状态..."
if curl -s --connect-timeout 2 "http://localhost:${WDA_PORT}/status" | python3 -c "
import json, sys
data = json.load(sys.stdin)
val = data.get('value', {})
ready = val.get('ready', False) if isinstance(val, dict) else False
state = val.get('state', '') if isinstance(val, dict) else ''
sid = data.get('sessionId') or (val.get('sessionId', '') if isinstance(val, dict) else '')
if ready or state == 'success' or sid:
    label = f'session={sid[:8]}...' if sid else f'state={state}'
    print(f'WDA 已在运行 ({label})')
    sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
    log "WDA 环境就绪 ✓"
    if $CHECK_ONLY; then exit 0; fi
    # Still verify screenshot works
    if curl -s --connect-timeout 3 "http://localhost:${WDA_PORT}/screenshot" | python3 -c "
import json, sys, base64
data = json.load(sys.stdin)
img = base64.b64decode(data['value'])
if len(img) > 80000: sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
        log "截图验证通过 ✓"
        exit 0
    else
        warn "WDA 状态正常但截图可能异常，继续重启..."
    fi
fi

if $CHECK_ONLY; then
    err "WDA 未运行"
    exit 1
fi

# Step 3: Start userspace tunnel (iOS 17+)
# Userspace tunnel is per-machine (serves all connected devices via pymobiledevice3).
# Reuse if already running — killing it would break any other session's WDA.
log "Step 3: 启动 userspace tunnel..."
EXISTING_TUNNEL_PID=$(pgrep -f "ios tunnel" | head -1 || true)
if [[ -n "$EXISTING_TUNNEL_PID" ]]; then
    log "tunnel 已在运行 (PID: $EXISTING_TUNNEL_PID) — 复用，不重启"
    TUNNEL_PID="$EXISTING_TUNNEL_PID"
else
    ios tunnel start --userspace &>/dev/null &
    TUNNEL_PID=$!
    sleep 2

    if ! kill -0 "$TUNNEL_PID" 2>/dev/null; then
        warn "tunnel 进程已退出（可能 iOS < 17 不需要 tunnel）"
    else
        log "tunnel 已启动 (PID: $TUNNEL_PID)"
    fi
fi

# Step 3.5: Auto-mount Developer Disk Image (iOS 17+)
if [[ -n "$IOS_MAJOR" && "$IOS_MAJOR" -ge 17 ]]; then
    log "Step 3.5: 挂载 Developer Disk Image..."
    if ios image auto --udid="$UDID" &>/dev/null; then
        log "DDI 挂载成功 ✓"
    else
        warn "DDI 挂载失败（可能已挂载或需手动处理）"
        if [[ -n "$IOS_MAJOR" && "$IOS_MAJOR" -ge 26 ]]; then
            warn "   iOS 26+ 提示: 如 DDI 不匹配，尝试 Xcode > Window > Devices 手动配对"
        fi
    fi
fi

# Step 4: Start WDA
log "Step 4: 启动 WDA..."
# Kill only THIS device's WDA (match on UDID in -destination arg).
# Other sessions' WDA processes (different UDID) are untouched.
pkill -f "xcodebuild.*WebDriverAgentRunner.*${UDID}" 2>/dev/null || true
sleep 1

# Find WebDriverAgent project
# 1. Check mobile-setup saved config first
MOBILE_CONFIG="${HOME}/.config/ae/mobile-setup.json"
if [[ -f "$MOBILE_CONFIG" ]]; then
    WDA_PROJECT=$(python3 -c "
import json, os
with open('$MOBILE_CONFIG') as f:
    data = json.load(f)
p = data.get('wda_project', '')
if p:
    p = os.path.expanduser(p)
    # Append .xcodeproj if not already
    xcproj = os.path.join(p, 'WebDriverAgent.xcodeproj')
    if os.path.exists(xcproj):
        print(xcproj)
    elif os.path.exists(p) and p.endswith('.xcodeproj'):
        print(p)
" 2>/dev/null || true)
fi

# 2. Search system locations (no user-specific paths)
if [[ -z "$WDA_PROJECT" ]]; then
    WDA_PROJECT=$(find /usr/local/lib /opt/homebrew ~/Library /Applications \
        -name "WebDriverAgent.xcodeproj" -maxdepth 6 2>/dev/null | head -1 || true)
fi

# 3. Try go-ios bundled WDA
if [[ -z "$WDA_PROJECT" ]]; then
    WDA_PROJECT=$(find "$(dirname "$(which ios)")/../" -name "WebDriverAgent.xcodeproj" -maxdepth 5 2>/dev/null | head -1 || true)
fi

if [[ -z "$WDA_PROJECT" ]]; then
    err "未找到 WebDriverAgent.xcodeproj。运行 /ae-mobile-setup 安装。"
    exit 1
fi
log "WDA 项目: $WDA_PROJECT"

# Read signing config from mobile-setup.json (avoid creating duplicate WDA with different bundle ID)
WDA_TEAM_ID=""
WDA_BUNDLE_ID=""
if [[ -f "$MOBILE_CONFIG" ]]; then
    eval "$(python3 -c "
import json
with open('$MOBILE_CONFIG') as f:
    data = json.load(f)
tid = data.get('team_id', '')
bid = data.get('bundle_id', '')
if tid: print(f'WDA_TEAM_ID={tid}')
if bid: print(f'WDA_BUNDLE_ID={bid}')
" 2>/dev/null || true)"
fi

# Build xcodebuild command with signing params if available
XC_ARGS=(-project "$WDA_PROJECT" -scheme WebDriverAgentRunner -destination "id=$UDID")
if [[ -n "$WDA_TEAM_ID" ]]; then
    XC_ARGS+=(DEVELOPMENT_TEAM="$WDA_TEAM_ID")
    log "Team ID: $WDA_TEAM_ID"
fi
if [[ -n "$WDA_BUNDLE_ID" ]]; then
    XC_ARGS+=(PRODUCT_BUNDLE_IDENTIFIER="$WDA_BUNDLE_ID")
fi

# --- Helper: start port forward ---
start_forward() {
    # Kill only this UDID+port forward. Matching on both port AND udid avoids
    # stomping on another session using a different port or different device.
    pkill -f "ios forward ${WDA_PORT} ${WDA_PORT} --udid=${UDID}" 2>/dev/null || true
    # Wait until port is actually freed (up to 5s)
    for i in $(seq 1 10); do
        if ! lsof -i :${WDA_PORT} -sTCP:LISTEN &>/dev/null; then
            break
        fi
        sleep 0.5
    done
    ios forward ${WDA_PORT} ${WDA_PORT} --udid="$UDID" &>/dev/null &
    FORWARD_PID=$!
    sleep 1
    # Verify forward process is alive and port is bound
    if ! kill -0 "$FORWARD_PID" 2>/dev/null; then
        warn "端口转发启动失败，重试..."
        sleep 2
        ios forward ${WDA_PORT} ${WDA_PORT} --udid="$UDID" &>/dev/null &
        FORWARD_PID=$!
        sleep 1
    fi
}

# --- Helper: verify WDA responds ---
# Returns 0 on success, 1 on failure
verify_wda() {
    local retries=${1:-$MAX_RETRIES}
    local wait_first=${2:-5}
    sleep "$wait_first"
    for attempt in $(seq 1 "$retries"); do
        if curl -s --connect-timeout 3 "http://localhost:${WDA_PORT}/status" | python3 -c "
import json, sys
data = json.load(sys.stdin)
val = data.get('value', {})
# Accept: ready=true OR state=success OR non-null sessionId
ready = val.get('ready', False) if isinstance(val, dict) else False
state = val.get('state', '') if isinstance(val, dict) else ''
sid = data.get('sessionId') or (val.get('sessionId', '') if isinstance(val, dict) else '')
if ready or state == 'success' or sid:
    label = f'session={sid[:8]}...' if sid else f'state={state}'
    print(f'WDA 就绪 ({label})')
    sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
            return 0
        fi
        if [[ $attempt -lt $retries ]]; then
            warn "第 $attempt 次验证失败，等待重试..."
            sleep 3
        fi
    done
    return 1
}

# --- Helper: dump diagnostics ---
dump_diagnostics() {
    err "--- 错误日志 (最后 30 行) ---"
    tail -30 "$XCB_LOG" >&2 2>/dev/null || true
    err "--- 完整日志: cat $XCB_LOG ---"
    if [[ -n "$IOS_MAJOR" && "$IOS_MAJOR" -ge 26 ]]; then
        err ""
        err "=== iOS $IOS_VERSION 诊断建议 ==="
        err "1. 确认 Xcode 版本支持 iOS $IOS_VERSION（Xcode beta 可能需要更新）"
        err "2. 在 Xcode GUI 中: 打开 WebDriverAgent.xcodeproj → Product → Test 查看详细错误"
        err "3. 检查 WDA 版本: 尝试从 appium/WebDriverAgent main 分支重新 clone 最新代码"
        err "4. 备选方案: pymobiledevice3 (pip install pymobiledevice3) 支持 iOS 26 XCTest 启动"
        err "5. 跟踪上游: https://github.com/appium/WebDriverAgent/issues"
        err ""
        err "请将以下信息反馈给 AE Team:"
        err "  cat $XCB_LOG | tail -50"
        err "  xcodebuild -version"
        err "  ios version"
    fi
}

# ===== Attempt 1: test-without-building =====
log "尝试 test-without-building..."
xcodebuild test-without-building "${XC_ARGS[@]}" &>"$XCB_LOG" &
WDA_PID=$!

# Quick check: if process died immediately
sleep 3
if ! kill -0 "$WDA_PID" 2>/dev/null; then
    XC_EXIT=$(wait "$WDA_PID" 2>/dev/null; echo $?)
    warn "test-without-building 立即失败 (exit code: $XC_EXIT)"
else
    # Process alive — start forward and verify
    log "Step 5: 端口转发 (port=${WDA_PORT})..."
    start_forward
    log "Step 6: 验证 WDA (http://localhost:${WDA_PORT})..."
    if verify_wda 3 3; then
        log "${GREEN}WDA 环境就绪 ✓${NC}"
        echo ""
        echo -e "${BOLD}进程信息:${NC}"
        [[ -n "${TUNNEL_PID:-}" ]] && echo "  tunnel:  PID $TUNNEL_PID"
        echo "  WDA:     PID $WDA_PID (udid=$UDID)"
        echo "  forward: PID $FORWARD_PID (localhost:${WDA_PORT} → device:${WDA_PORT})"
        echo ""
        echo -e "${BOLD}配套脚本如何使用此端口:${NC}"
        echo "  export WDA_URL=http://localhost:${WDA_PORT}"
        echo ""
        exit 0
    fi
    warn "test-without-building 验证失败"
fi

# ===== Attempt 2: test (full build) =====
warn "检查 xcodebuild 日志..."
if grep -q "exit code 74\|exited with code 74" "$XCB_LOG" 2>/dev/null; then
    warn "检测到 exit code 74 (test runner 启动即崩溃)"
fi

# Kill previous attempt (xcodebuild + stale forward) — scoped to this UDID/port
pkill -f "xcodebuild.*WebDriverAgentRunner.*${UDID}" 2>/dev/null || true
pkill -f "ios forward ${WDA_PORT} ${WDA_PORT} --udid=${UDID}" 2>/dev/null || true
sleep 1

log "回退到 xcodebuild test（含完整 build）..."
xcodebuild test "${XC_ARGS[@]}" &>"$XCB_LOG" &
WDA_PID=$!
log "xcodebuild test 启动中 (PID: $WDA_PID)..."

# Full build needs more time
sleep 5
if ! kill -0 "$WDA_PID" 2>/dev/null; then
    XC_EXIT2=$(wait "$WDA_PID" 2>/dev/null; echo $?)
    err "xcodebuild test 也立即失败 (exit code: $XC_EXIT2)"
    dump_diagnostics
    exit 1
fi

log "Step 5: 端口转发 (port=${WDA_PORT})..."
start_forward
log "Step 6: 验证 WDA (http://localhost:${WDA_PORT})..."
if verify_wda 4 8; then
    log "${GREEN}WDA 环境就绪 ✓${NC}"
    echo ""
    echo -e "${BOLD}进程信息:${NC}"
    [[ -n "${TUNNEL_PID:-}" ]] && echo "  tunnel:  PID $TUNNEL_PID"
    echo "  WDA:     PID $WDA_PID (udid=$UDID)"
    echo "  forward: PID $FORWARD_PID (localhost:${WDA_PORT} → device:${WDA_PORT})"
    echo ""
    echo -e "${BOLD}配套脚本如何使用此端口:${NC}"
    echo "  export WDA_URL=http://localhost:${WDA_PORT}"
    echo ""
    exit 0
fi

# ===== Both attempts failed =====
err "WDA 启动失败（test-without-building 和 test 均失败）"
dump_diagnostics
exit 1
