# Skill: Demo 原型转 Figma 设计稿 (demo-to-figma)

## 触发条件

当 PM 使用 vibe coding 完成产品 demo 原型后，需要将其转为可编辑的 Figma 设计稿，供设计师精修时触发。

## 核心原则

**Figma 设计稿是 PM 与设计师协作的关键衔接件。** PM 负责产品逻辑和原型，设计师负责视觉精修和组件化。`use_figma` 让 agent 读代码理解 UI 后程序化创建 Figma 节点，输出设计师可直接编辑的原生图层。

## 前置条件

- **Figma MCP 已连接**：运行 `claude mcp list`，确认 `figma: ✓ Connected`
- **Figma Full 席位**：用户需有 Pro 或以上计划的 Full 席位（非 View/Dev 席位）
- 如 MCP 未连接，引导用户执行 `claude mcp add --transport http figma https://mcp.figma.com/mcp` 并完成 OAuth 认证

## 输入

- **demo 项目目录**：PM 的 vibe coding 产出（HTML/CSS/JS Web SPA 或 iOS Xcode 项目）

## 输出

- **Figma 文件 URL**：包含所有页面的可编辑设计稿
- **页面截图**：每个页面的 Figma 截图（供 PM 确认还原度）
- **限制说明**：图片为占位色块、无交互原型等已知限制

## 执行流程

### Step 1: 项目识别与页面发现

1. 判断项目类型：
   - **Web SPA**：扫描 `*.html` 文件、JS 路由配置（`case 'xxx':`、`route:` 等）、tab 导航结构
   - **iOS**：扫描 SwiftUI View 文件、`NavigationStack`/`TabView` 结构
2. 列出所有页面清单（名称 + 入口文件）
3. 展示页面清单，询问 PM：全部转换还是选择部分页面？

### Step 2: 设计规范提取

从代码中提取 design tokens，不凭空编造任何值：

**Web 项目（CSS 变量）：**
- `:root` 中的 CSS 变量（`--bg-primary`、`--text-primary`、`--accent-*` 等）
- 字体族（`font-family`）
- 间距/圆角（`--radius-*`、`padding`）
- 画布宽度（`max-width` 或 viewport 设置，移动端通常 430px）

**iOS 项目（SwiftUI）：**
- `Color` 定义和 `Assets.xcassets` 中的颜色集
- `.font()` 修饰符提取字体规范
- `.cornerRadius()`、`.padding()` 提取间距/圆角
- 画布宽度固定 393px（iPhone 15 Pro）

输出设计规范摘要供后续步骤使用。

### Step 3: Figma 连接与文件创建

1. 调用 `mcp__figma__whoami` 确认连接正常
2. 从返回的 plans 中选择合适的 team（优先选 Pro/Full 席位的 team）
3. 调用 `mcp__figma__create_new_file` 创建文件：
   - 文件名：`{项目名} — Design Draft`
   - planKey：选中的 team key
   - editorType：`design`
4. 记录 fileKey，后续所有操作使用此 key

### Step 4: 逐页构建

对每个页面按以下流程构建：

#### 4a. 读取源码

读取该页面涉及的所有 HTML/CSS/JS（或 SwiftUI）源码，理解：
- 组件层级结构（哪些是容器、哪些是子元素）
- 布局方式（flex/grid/stack → Figma auto-layout 方向和间距）
- 样式细节（颜色、字体、圆角、阴影、渐变）
- 文案内容（标题、按钮文字、描述文本）

#### 4b. 构建 Figma 节点

使用 `mcp__figma__use_figma` 执行 Figma Plugin API 代码：

**必须遵守的规则：**
- 所有容器使用 `layoutMode`（auto-layout），不使用绝对定位（底部导航栏等固定元素除外）
- 先创建父节点并设置 `layoutMode`，再 `appendChild` 子节点，最后设置 `layoutSizingHorizontal = "FILL"`（顺序不能反）
- 图层命名语义化：使用 "Header"、"Hero Card"、"Tab Bar" 等描述性名称
- 颜色使用 Step 2 提取的精确值（RGB 0-1 范围）
- 字体优先使用 `Inter`（Figma 默认可用），加载所需 style：`await figma.loadFontAsync({ family: "Inter", style: "Bold" })`
- **图片加载（重要：必须委托给独立 Agent）**：从源码提取图片 URL，用 bash 下载为小尺寸（150x110）JPEG，base64 编码后嵌入 `use_figma` 代码。Plugin API 无 `fetch`/`atob`，需自行实现 base64 解码器（见下方模板）。每张图约 5K base64 字符，单次调用可嵌入 2-3 张图。**图片加载必须通过 `Agent` 工具委托给独立子 Agent 执行**——长对话中 base64 字符串会在传递过程中损坏，导致图片显示为色块。子 Agent 拥有独立短上下文，base64 传递完整无损
- **每个页面创建一个独立的顶层 Frame**，尺寸固定为 430×932（iPhone 15 Pro），`clipsContent = true`
- Content 子 Frame 使用 `layoutSizingVertical = "FIXED"`，高度按实际内容设置（可超过 932px，表示可滚动）
- 每次 `use_figma` 调用的代码不超过 200 行，复杂页面分多次调用
- **新建 Frame 默认高度为 100px**，必须显式设置 `layoutSizingVertical = "HUG"` 避免高度异常

**构建顺序（由外到内）：**
1. 页面 Frame（背景色 + 尺寸 + auto-layout）
2. 头部/导航栏
3. 各内容区块（按页面从上到下的顺序）
4. 固定元素（底部导航栏等，使用 `layoutPositioning = "ABSOLUTE"`）

#### 4c. 进度报告

每完成一个页面后：
- 报告当前进度（X/N 页完成）
- 如遇到 `use_figma` 错误，诊断并修复后继续

### Step 5: 自验证与迭代修复

**这是保证还原质量的核心环节。** 每构建完一个页面后，立即执行验证-修复循环：

#### 5a. 截取对比截图

1. **Demo 截图**：执行 `scripts/capture-demo-screenshots.sh <demo_dir> <output_dir> <page_name>` 截取该页面的原始 Demo 截图
2. **Figma 截图**：调用 `mcp__figma__get_screenshot` 获取对应页面 Frame 的截图

#### 5b. Vision 对比分析

同时查看两张截图（Demo 截图用 `Read` 工具读取 PNG 文件，Figma 截图通过 `get_screenshot` 获取），逐区块对比并输出结构化差距报告：

```
| 区域 | Demo 表现 | Figma 表现 | 差距类型 | 严重度 |
|------|----------|-----------|---------|--------|
| Header | Logo 图片 + 文字 | 占位方块 + 文字 | 缺图片 | 中 |
| ... | ... | ... | ... | ... |
```

差距类型分类：
- **缺图片**：图片为占位色块，需 `figma.createImage()` 加载
- **缺 SVG**：图标为方块/圆形替代，需 `figma.createNodeFromSvg()` 还原
- **文字截断**：text 节点宽度不够，需设置 `textAutoResize` 和 `layoutSizingHorizontal`
- **section 遗漏**：整个区块未构建，需补建
- **布局偏差**：间距/圆角/对齐与原始不符，需调整属性值
- **视觉效果缺失**：阴影/模糊/渐变等效果未还原，需设置 `effects`
- **位置异常**：元素位置错误（如导航栏重复），需修复布局逻辑

#### 5c. 自动修复

针对差距报告中的每个问题，按严重度从高到低依次修复：

1. **section 遗漏**（高）：补建缺失的 UI 区块
2. **文字截断**（高）：修复 text 节点的宽度和 autoResize 设置
3. **位置异常**（高）：修复布局逻辑错误
4. **布局偏差**（中）：调整间距、圆角、对齐等属性
5. **缺 SVG**（中）：如果源码中有 SVG 字符串，用 `createNodeFromSvg` 还原
6. **视觉效果缺失**（低）：添加阴影、模糊等效果
7. **缺图片**（低）：目前用占位色块，标注图片用途即可

每次修复后，重新截图验证，确认问题已解决。

#### 5d. 迭代终止条件

当满足以下条件时，该页面验证通过：
- 无"高严重度"差距
- 所有 section 都已构建
- 文字内容完整无截断
- 布局结构与原始 Demo 基本一致

### Step 6: 输出

向 PM 展示最终结果：

```
## Figma 设计稿已生成

**文件链接**: https://www.figma.com/design/{fileKey}

### 页面清单
| 页面 | 状态 | 验证轮次 | 说明 |
|------|------|---------|------|
| Home | ✅ | 2 轮 | 含 X 个区块，Y 个已修复 |
| Category | ✅ | 1 轮 | 含 X 个区块 |
| ... | ... | ... | ... |

### 验证报告
每页的最终对比结果：剩余差距（仅低严重度）

### 已知限制
- 图片为灰色占位色块，需设计师替换为实际素材
- 无交互原型（Prototype Flow），仅静态页面
- 字体使用 Inter 替代原始字体，设计师可按需更换

### 下一步
1. 将 Figma 链接发给设计师
2. 设计师精修视觉、替换图片、组件化
3. 精修完成后可用 Figma MCP 反向同步 design tokens
```

## 图片加载模板

Plugin API 中无 `fetch`/`atob`，需使用以下模板：

```javascript
// 纯 JS base64 解码器（Plugin API 兼容）
function decodeBase64(str) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
  let output = [];
  let i = 0;
  str = str.replace(/[^A-Za-z0-9\+\/\=]/g, '');
  while (i < str.length) {
    const e1 = chars.indexOf(str.charAt(i++));
    const e2 = chars.indexOf(str.charAt(i++));
    const e3 = chars.indexOf(str.charAt(i++));
    const e4 = chars.indexOf(str.charAt(i++));
    output.push((e1 << 2) | (e2 >> 4));
    if (e3 !== 64) output.push(((e2 & 15) << 4) | (e3 >> 2));
    if (e4 !== 64) output.push(((e3 & 3) << 6) | e4);
  }
  return new Uint8Array(output);
}
function loadImg(b64) { return figma.createImage(decodeBase64(b64)); }
function fillImg(node, hash) {
  node.fills = [{ type: "IMAGE", imageHash: hash, scaleMode: "FILL" }];
}

// 使用：先用 bash 下载图片并 base64 编码
// curl -sL "IMAGE_URL?w=150&h=110&fm=jpg&q=70" | base64 | tr -d '\n'
// 然后将 base64 字符串嵌入代码
const B1 = "...base64...";
const img = loadImg(B1);
fillImg(targetNode, img.hash);
```

## 故障排查

| 问题 | 原因 | 解决 |
|------|------|------|
| `mcp__figma__whoami` 不可用 | Figma MCP 未连接 | 运行 `claude mcp add --transport http figma https://mcp.figma.com/mcp` |
| `use_figma` 报权限错误 | 席位不是 Full | 需升级为 Full 席位（View/Dev 席位不支持写入） |
| `FILL can only be set on children of auto-layout frames` | 设置 layoutSizing 的顺序错误 | 先 appendChild 到父节点，再设置 layoutSizingHorizontal |
| 字体加载失败 | 未调用 loadFontAsync | 在创建文本前 `await figma.loadFontAsync(...)` |
| 代码超长报错 | 单次 use_figma 代码过长 | 拆分为多次调用，每次不超过 200 行 |
| `fetch is not defined` | Plugin API 无网络能力 | 用 bash 预下载图片，base64 嵌入代码 |
| `atob is not defined` | Plugin API 无 atob | 使用上方纯 JS base64 解码器模板 |
| Frame 高度异常（100px） | 新建 Frame 默认高度 | 创建后立即设置 `layoutSizingVertical = "HUG"` |
| 文字截断 | 父容器宽度 FIXED | 父容器设 `layoutSizingHorizontal = "FILL"`，文本设 `textAutoResize = "HEIGHT"` |
| 底部导航栏不可见 | 页面 Frame 高度不足 | 页面 Frame 固定 932px + `clipsContent = true` |
| 图片显示为色块/损坏 | base64 字符串在传递中被截断或损坏 | 保持单张图片 base64 < 8K 字符；每次 `use_figma` 调用只嵌入 1-2 张图；调用后立即用 `get_screenshot` 验证 |
| 图片节点名不匹配 | `findOne` 按名称搜索但节点名可能是默认值 "Rectangle" | 搜索时同时按 `name` 和 `type === "RECTANGLE"` 匹配 |
| 所有卡片使用相同图片 | 单次调用只能嵌入有限图片 | 分多次调用，每次加载不同图片的 base64；或接受设计稿中使用代表性图片 |

## Agent Team 分工（迭代修复阶段）

迭代修复阶段（Step 5）使用 Agent 工具将工作分配给专职子 Agent，提升并行效率并避免长对话导致的 base64 损坏。

### 角色与职责

| 角色 | 执行者 | 职责 | 关键约束 |
|------|--------|------|----------|
| **Coordinator** | 主 Agent | Vision 对比分析、制定修复计划、编排子 Agent、验证结果 | 不直接处理 base64 图片数据 |
| **Image Loader** | 独立子 Agent | 下载/压缩图片 → base64 编码 → 调用 `use_figma` 加载到指定节点 | 每次 max 2 张图，base64 < 6000 字符，用完即弃（短上下文防损坏） |
| **SVG Builder** | 独立子 Agent 或主 Agent | 从源码提取 SVG → `createNodeFromSvg()` 替换占位色块 | 一次可处理多个 SVG，需传入精确的 nodeId |
| **Layout Fixer** | 主 Agent | 调整间距/圆角/颜色/位置/auto-layout 属性 | 直接操作 `use_figma`，不涉及大数据传输 |

### 工作流

```
Coordinator: 截图对比 → 输出差距表
    ├── Image Loader Agent (background): 批量加载图片
    ├── SVG Builder Agent (background): 批量替换 SVG 图标
    └── Layout Fixer (foreground): 修间距/颜色/位置
Coordinator: 重新截图验证 → 未达标则再循环
```

### 关键规则

1. **逐页完成** — 一个页面验证达标后再开始下一个，不要同时铺开多页
2. **Image Loader 必须用独立 Agent** — 长对话中 base64 字符串会损坏
3. **图片尺寸梯度** — 140×140 q65 ≈ 6K chars（SOTD 验证可用）；大图拆多次调用
4. **每轮修复后必须截图验证** — 不盲信 use_figma 的返回值，截图才是真相
5. **差距表驱动** — 每轮修复从差距表中按严重度排序执行，修完标记

## 重要规则

1. **不编造数据** — 颜色、字体、文案全部从代码提取，不凭空编造
2. **先确认再执行** — Step 1 页面清单必须 PM 确认后再开始构建
3. **每页独立 Frame** — 每个页面是独立的顶层 Frame，不混在一个 Frame 中
4. **构建后必须验证** — 每个页面构建完成后，必须执行 Step 5 自验证流程，不能跳过
5. **不遗漏 section** — 读代码时必须完整遍历渲染函数，列出所有 UI section，逐个构建
6. **文字不可截断** — text 节点必须设置 `textAutoResize = "HEIGHT"` 和 `layoutSizingHorizontal = "FILL"`（在 auto-layout 父节点中）
7. **图片用占位色块** — 当前阶段用深灰色占位（`{r:0.12, g:0.12, b:0.14}`），节点名标注图片用途
8. **逐页完成** — 一个页面验证达标后再开始下一个页面，不铺开多页同时做
