#!/bin/bash
# patch-playwright-mcp.sh — 修补 Playwright MCP 的导航超时问题
#
# 根因：Chromium 新 tab 的 V8 code cache 不跨 renderer process 共享，
# 导致重型 SPA（飞书、百度等）的 domcontentloaded 事件延迟 10-60 秒。
# Playwright MCP 的 browser_navigate 硬编码 waitUntil: "domcontentloaded"，
# 导致 Agent 在导航时长时间卡住。
#
# 修补内容：
#   1. navigate(): waitUntil → "commit" + 5s DCL bounded wait，DCL 超时则跳过 load wait
#   2. Tab 增加 _domReady 标记，DCL 是否在 5s 内完成
#   3. captureSnapshot(): ariaSnapshot timeout = domReady ? 5s : 1s + catch
#   4. headerSnapshot(): page.title() timeout = domReady ? 3s : 0.5s
#
# 效果：飞书从 40-60s → ~7s，百度从 15-17s → ~7s
#
# 用法：
#   bash scripts/patch-playwright-mcp.sh
#   # 或通过 ae-go:
#   bash ~/.ae/go/scripts/patch-playwright-mcp.sh

set -euo pipefail

# 找到 playwright-core 的 tab.js
TAB_JS=$(find ~/.npm/_npx -path "*/playwright-core/lib/tools/backend/tab.js" 2>/dev/null | head -1)

if [ -z "$TAB_JS" ]; then
  echo "ERROR: playwright-core tab.js not found. Run 'npx @playwright/mcp@latest --help' first."
  exit 1
fi

echo "Patching: $TAB_JS"

# 检查是否已 patch
if grep -q '_domReady' "$TAB_JS"; then
  echo "Already patched. To re-patch, first run: npm cache clean --force"
  exit 0
fi

# 备份
cp "$TAB_JS" "${TAB_JS}.bak"

node -e "
const fs = require('fs');
let code = fs.readFileSync('$TAB_JS', 'utf8');

// 1. 在构造函数中添加 _domReady 标记
code = code.replace(
  'this._recentEventEntries = [];',
  'this._recentEventEntries = [];\n    this._domReady = true;'
);

// 2. navigate(): commit + conditional waits
code = code.replace(
  /await this\.page\.goto\(url2, \{ waitUntil: \"domcontentloaded\", \.\.\.this\.navigationTimeoutOptions \}\);/,
  'await this.page.goto(url2, { waitUntil: \"commit\", ...this.navigationTimeoutOptions });'
);
code = code.replace(
  'await this.waitForLoadState(\"load\", { timeout: 5e3 });',
  'this._domReady = await this.page.waitForLoadState(\"domcontentloaded\", { timeout: 5e3 }).then(() => true).catch(() => false);\n    if (this._domReady)\n      await this.waitForLoadState(\"load\", { timeout: 5e3 });'
);

// 3. captureSnapshot(): dynamic timeout + catch
code = code.replace(
  /const ariaSnapshot = selector \? await this\.page\.locator\(selector\)\.ariaSnapshot\(\{ mode: \"ai\", depth \}\) : await this\.page\.ariaSnapshot\(\{ mode: \"ai\", depth \}\);/,
  'const _t = this._domReady ? 5e3 : 1e3;\n      const ariaSnapshot = await (selector ? this.page.locator(selector).ariaSnapshot({ mode: \"ai\", depth, timeout: _t }) : this.page.ariaSnapshot({ mode: \"ai\", depth, timeout: _t })).catch(() => \"\");'
);

// 4. headerSnapshot(): dynamic title timeout
code = code.replace(
  'title = await this.page.title();',
  'const _tt = this._domReady ? 3e3 : 500;\n      title = await Promise.race([this.page.title(), new Promise((r) => setTimeout(() => r(\"\"), _tt))]);'
);

fs.writeFileSync('$TAB_JS', code);
console.log('Patch applied successfully.');
"

echo "Done. Restart Playwright MCP (new Claude Code conversation) to apply."
