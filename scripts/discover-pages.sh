#!/bin/bash
# discover-pages.sh
# 自动发现 Demo 项目中的所有页面，输出结构化 JSON
#
# 用法: ./scripts/discover-pages.sh <demo_dir> [output_file]
#   demo_dir    - Demo 项目目录
#   output_file - 输出 JSON 路径（默认 stdout）
#
# 支持项目类型:
#   - Web SPA: 扫描 *.html + JS 路由配置（case 'xxx': / route: 模式）
#   - iOS: 扫描 SwiftUI View 文件 + TabView/NavigationStack
#
# 输出 JSON 结构:
#   {
#     "type": "web",
#     "pages": [
#       { "name": "home", "entry": "home.html", "render_fn": "renderHome()" },
#       ...
#     ]
#   }
#
# 示例:
#   ./scripts/discover-pages.sh ~/Documents/git/pmagenttest/ShoeLens/ShoeLens/www

set -euo pipefail

DEMO_DIR="${1:?用法: $0 <demo_dir> [output_file]}"
OUTPUT="${2:-}"

# ── 项目类型检测 ──────────────────────────────────────────
detect_type() {
  # 检查 iOS 标志
  if find "$DEMO_DIR" -maxdepth 3 -name '*.xcodeproj' -o -name '*.xcworkspace' | grep -q .; then
    echo "ios"
    return
  fi
  if find "$DEMO_DIR" -maxdepth 3 -name '*.swift' | grep -q .; then
    echo "ios"
    return
  fi
  # 默认 Web
  echo "web"
}

PROJECT_TYPE=$(detect_type)

# ── Web SPA 页面发现 ──────────────────────────────────────
discover_web_pages() {
  # 策略 1: 扫描 HTML 文件（排除 index.html 入口）
  local html_pages=()
  while IFS= read -r f; do
    name=$(basename "$f" .html)
    if [ "$name" != "index" ]; then
      html_pages+=("$name")
    fi
  done < <(find "$DEMO_DIR" -maxdepth 1 -name '*.html' | sort)

  # 策略 2: 从 JS 中提取路由配置
  # 模式: case 'xxx': content = renderXxx(); break;
  local route_pages=()
  local route_fns=()
  local js_files
  js_files=$(find "$DEMO_DIR" -name '*.js' -not -path '*/node_modules/*' -not -path '*/.git/*' | sort)

  if [ -n "$js_files" ]; then
    while IFS= read -r line; do
      # 提取 case 'pageName': ... renderXxx() 模式
      page=$(echo "$line" | sed -E "s/.*case[[:space:]]*'([^']+)'.*/\1/")
      fn=$(echo "$line" | grep -oE 'render[A-Za-z]+\(\)' | head -1 || true)
      if [ -n "$page" ] && [ "$page" != "$line" ]; then
        route_pages+=("$page")
        route_fns+=("${fn:-}")
      fi
    done < <(grep -hE "case[[:space:]]*'[a-zA-Z]" $js_files 2>/dev/null || true)

    # 模式: { path: 'xxx', component: Xxx } 或 route: 'xxx'
    if [ ${#route_pages[@]} -eq 0 ]; then
      while IFS= read -r line; do
        page=$(echo "$line" | sed -E "s/.*path:[[:space:]]*'([^']+)'.*/\1/" | sed 's/^\///')
        if [ -n "$page" ] && [ "$page" != "$line" ] && [ "$page" != "*" ]; then
          route_pages+=("$page")
          route_fns+=("")
        fi
      done < <(grep -hE "path:[[:space:]]*'" $js_files 2>/dev/null || true)
    fi
  fi

  # 合并：路由为主，HTML 补充（用字符串去重）
  local seen_names=""
  local pages_json=""
  local count=0

  is_seen() { echo "$seen_names" | grep -qF "|$1|"; }
  mark_seen() { seen_names="${seen_names}|$1|"; }

  # 先添加路由发现的页面
  # 只保留有 render 函数或对应 HTML 文件的条目（过滤 action handler 噪音）
  for i in "${!route_pages[@]}"; do
    local name="${route_pages[$i]}"
    local fn="${route_fns[$i]:-}"
    local entry=""
    if [ -f "$DEMO_DIR/${name}.html" ]; then
      entry="${name}.html"
    fi
    # 过滤：必须有 render 函数或对应 HTML 文件才算页面
    if [ -z "$fn" ] && [ -z "$entry" ]; then
      continue
    fi
    if ! is_seen "$name"; then
      mark_seen "$name"
      [ $count -gt 0 ] && pages_json="${pages_json},"
      pages_json="${pages_json}
    { \"name\": \"${name}\", \"entry\": \"${entry}\", \"render_fn\": \"${fn}\" }"
      count=$((count + 1))
    fi
  done

  # 再添加仅 HTML 发现的（路由中可能遗漏的独立页面）
  for name in "${html_pages[@]}"; do
    if ! is_seen "$name"; then
      mark_seen "$name"
      [ $count -gt 0 ] && pages_json="${pages_json},"
      pages_json="${pages_json}
    { \"name\": \"${name}\", \"entry\": \"${name}.html\", \"render_fn\": \"\" }"
      count=$((count + 1))
    fi
  done

  cat <<ENDJSON
{
  "type": "web",
  "page_count": ${count},
  "pages": [${pages_json}
  ]
}
ENDJSON
}

# ── iOS 页面发现 ──────────────────────────────────────────
discover_ios_pages() {
  local pages_json=""
  local count=0

  # 查找 SwiftUI View 文件
  local swift_files
  swift_files=$(find "$DEMO_DIR" -name '*.swift' -not -path '*/Pods/*' -not -path '*/.build/*' | sort)

  if [ -z "$swift_files" ]; then
    cat <<ENDJSON
{
  "type": "ios",
  "page_count": 0,
  "pages": []
}
ENDJSON
    return
  fi

  # 策略 1: 从 TabView 提取 tab 页面
  while IFS= read -r line; do
    # TabView 中的 .tabItem 对应的 View
    view=$(echo "$line" | grep -oE '[A-Z][a-zA-Z]*View' | head -1 || true)
    label=$(echo "$line" | sed -E 's/.*Label\("([^"]+)".*/\1/' || true)
    if [ -n "$view" ]; then
      name=$(echo "$view" | sed 's/View$//' | tr '[:upper:]' '[:lower:]')
      [ $count -gt 0 ] && pages_json="${pages_json},"
      pages_json="${pages_json}
    { \"name\": \"${name}\", \"entry\": \"${view}.swift\", \"render_fn\": \"\" }"
      count=$((count + 1))
    fi
  done < <(grep -hE '\.tabItem|TabView' $swift_files 2>/dev/null || true)

  # 策略 2: 如果 TabView 没发现，搜索独立的 View struct
  if [ $count -eq 0 ]; then
    while IFS= read -r line; do
      view=$(echo "$line" | sed -E 's/.*struct[[:space:]]+([A-Z][a-zA-Z]*View).*/\1/')
      if [ -n "$view" ] && [ "$view" != "$line" ]; then
        name=$(echo "$view" | sed 's/View$//' | tr '[:upper:]' '[:lower:]')
        file=$(grep -rlE "struct[[:space:]]+${view}" $swift_files | head -1 || true)
        entry=$(basename "${file:-${view}.swift}")
        [ $count -gt 0 ] && pages_json="${pages_json},"
        pages_json="${pages_json}
    { \"name\": \"${name}\", \"entry\": \"${entry}\", \"render_fn\": \"\" }"
        count=$((count + 1))
      fi
    done < <(grep -hE 'struct[[:space:]]+[A-Z][a-zA-Z]*View[[:space:]]*:' $swift_files 2>/dev/null || true)
  fi

  cat <<ENDJSON
{
  "type": "ios",
  "page_count": ${count},
  "pages": [${pages_json}
  ]
}
ENDJSON
}

# ── 执行 ──────────────────────────────────────────────────
if [ "$PROJECT_TYPE" = "ios" ]; then
  RESULT=$(discover_ios_pages)
else
  RESULT=$(discover_web_pages)
fi

if [ -n "$OUTPUT" ]; then
  echo "$RESULT" > "$OUTPUT"
  echo "pages 已输出到: $OUTPUT" >&2
else
  echo "$RESULT"
fi
