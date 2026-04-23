#!/usr/bin/env bash
# mobile-precheck.sh — 一次性检测 mobile 环境所有组件
# 被 ae-mobile-setup 和 ae-mobile-agent 调用
set -uo pipefail

echo "=== Mobile 环境预检 ==="

# 快速路径：WDA 已在运行
if curl -s --max-time 3 http://localhost:8100/status 2>/dev/null | python3 -c "import json,sys;d=json.load(sys.stdin);assert d['value']['ready']" 2>/dev/null; then
    echo "🟢 WDA 已在运行 (localhost:8100)"
    echo "STATUS=ready"
    exit 0
fi

# 逐项检测
MISSING=()

echo -n "Node.js:      "
if node --version 2>/dev/null; then echo "✅"; else echo "❌ 需要安装"; MISSING+=(nodejs); fi

echo -n "go-ios:       "
if which ios >/dev/null 2>&1 && ios version 2>/dev/null; then echo "✅"; else echo "❌ 需要安装"; MISSING+=(go-ios); fi

echo -n "Xcode:        "
if xcodebuild -version 2>/dev/null | head -1; then echo "✅"; else echo "❌ 需要安装"; MISSING+=(xcode); fi

echo -n "WDA 编译:     "
WDA_APP=$(find ~/Library/Developer/Xcode/DerivedData/WebDriverAgent-*/Build/Products/Debug-iphoneos -name '*.app' -maxdepth 1 2>/dev/null | head -1)
if [[ -n "$WDA_APP" ]]; then echo "✅ ($WDA_APP)"; else echo "❌ 需要编译"; MISSING+=(wda); fi

echo -n "mobile-mcp:   "
if claude mcp list 2>/dev/null | grep -q mobile-mcp; then echo "✅"; else echo "❌ 需要配置"; MISSING+=(mobile-mcp); fi

echo -n "iPhone:       "
UDID=""
IOS_VER=""
IOS_MAJOR=""
if which ios >/dev/null 2>&1; then
    DEV_JSON=$(ios list 2>/dev/null || true)
    DEVICE_COUNT=$(echo "$DEV_JSON" | python3 -c "import json,sys;d=json.load(sys.stdin);print(len(d.get('deviceList',[])))" 2>/dev/null || echo 0)
    if [[ "$DEVICE_COUNT" -gt 0 ]]; then
        UDID=$(echo "$DEV_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
item = d['deviceList'][0]
print(item['serialNumber'] if isinstance(item, dict) else item)
" 2>/dev/null)
        IOS_VER=$(echo "$DEV_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for x in d.get('deviceList', []):
    if isinstance(x, dict):
        print(x.get('productVersion', ''))
        break
" 2>/dev/null)
        [[ -n "$IOS_VER" ]] && IOS_MAJOR=$(echo "$IOS_VER" | cut -d. -f1)
        echo "✅ ($DEVICE_COUNT 台, UDID: $UDID, iOS: ${IOS_VER:-unknown})"
    else
        echo "❌ 未检测到 (USB 未连接或未信任)"
        MISSING+=(iphone)
    fi
else
    echo "❌ 无法检测 (go-ios 未安装)"
    MISSING+=(iphone)
fi

# iOS 17+ 额外检测: Developer Mode + DDI — 这两项是 code 74 的常见根因
if [[ -n "$IOS_MAJOR" && "$IOS_MAJOR" -ge 16 ]]; then
    echo -n "Developer Mode: "
    DEV_MODE=$(ios info --udid="$UDID" 2>/dev/null | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('DeveloperModeStatus', d.get('DeveloperMode', 'unknown')))
except Exception:
    print('unknown')
" 2>/dev/null)
    case "$DEV_MODE" in
        true|True|1|enabled) echo "✅ 已开启" ;;
        false|False|0|disabled) echo "❌ 未开启 — 设置 → 隐私与安全性 → 开发者模式"; MISSING+=(developer-mode) ;;
        *) echo "⚠️ 未知 ($DEV_MODE) — 请手动确认 设置 → 隐私与安全性 → 开发者模式 已开启" ;;
    esac
fi

if [[ -n "$IOS_MAJOR" && "$IOS_MAJOR" -ge 17 && -n "$UDID" ]]; then
    echo -n "DDI 挂载:     "
    if ios image list --udid="$UDID" 2>&1 | grep -qiE "mounted|PersonalizedImage|DeveloperDiskImage"; then
        echo "✅"
    else
        echo "⚠️ 未检测到已挂载 DDI (ios image auto --udid=$UDID 可尝试自动挂载)"
    fi
fi

if [[ -n "$IOS_MAJOR" && "$IOS_MAJOR" -ge 26 ]]; then
    echo "⚠️  iOS $IOS_VER 为 beta — 已知上游问题:"
    echo "   - appium/appium#21347 (iOS 26 × Xcode 26)"
    echo "   - go-ios#631 (ios runwda tunnel 失败)"
    echo "   如 wda-start.sh 仍报 code 74，先尝试 Xcode GUI 手动 Product → Test 一次"
fi

echo -n "配置文件:     "
if [[ -f ~/.config/ae/mobile-setup.json ]]; then
    echo "✅ ($(cat ~/.config/ae/mobile-setup.json | python3 -c "import json,sys;d=json.load(sys.stdin);print('setup_date:', d.get('setup_date','unknown'))" 2>/dev/null))"
    echo "CONFIG=exists"
else
    echo "⚠️ 不存在 (首次搭建)"
    echo "CONFIG=missing"
fi

echo ""
if [[ ${#MISSING[@]} -eq 0 ]]; then
    echo "STATUS=all_installed_but_wda_not_running"
    echo "ACTION=只需执行 Step 4（启动 WDA + 端口转发）"
else
    echo "STATUS=missing_components"
    echo "MISSING=${MISSING[*]}"
    echo "ACTION=按 Step 顺序安装缺失组件"
fi
