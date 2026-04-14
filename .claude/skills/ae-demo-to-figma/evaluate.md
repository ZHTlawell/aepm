# ae-demo-to-figma 评估报告

## 基本信息
- **Role**: pm
- **Skill**: ae-demo-to-figma

## Test Stories

### Story 1: 基础 Happy Path — Web SPA Demo 转 Figma 设计稿
- **Prompt**: "帮我把 ~/Projects/shoe-lens-demo 这个 demo 转成 Figma 设计稿"
- **Expect**: 
  - Step 1: 执行 `demo-to-figma-prepare.sh` 预处理管线，生成 pages.json + tokens.json + images.json + svgs.json
  - Step 2: 向 PM 展示页面清单（名称 + 入口文件 + render 函数），等待 PM 确认全部转换还是部分页面
  - Step 3: 调用 `mcp__figma__whoami` 确认连接，`create_new_file` 创建 Figma 文件（命名为 "{项目名} -- Design Draft"）
  - Step 4: 逐页构建 Figma 节点，每页独立顶层 Frame（430x932，iPhone 15 Pro），使用 auto-layout，颜色使用 tokens.json 的 rgb01 值
  - Step 5: 每页构建完执行自验证（Demo 截图 vs Figma 截图对比），输出差距报告，按严重度修复
  - Step 6: 输出 Figma 文件链接 + 页面清单 + 验证报告 + 已知限制
  - 所有节点有语义化命名（无 Frame 1 / Rectangle 2）
- **Max Time**: 600s

### Story 2: 带 --with-b64 参数的图片加载流程
- **Prompt**: "转 Figma，项目在 ~/Projects/wepray-demo，需要把图片也加载进去"
- **Expect**: 
  - 预处理使用 `--with-b64` 参数：`demo-to-figma-prepare.sh <dir> <output> --with-b64`
  - 生成 images/*.b64 文件和 images/manifest.json
  - 图片加载通过 Agent 工具委托给独立子 Agent（Image Loader），避免长对话 base64 损坏
  - 每次 use_figma 调用只嵌入 1-2 张图，base64 < 6000 字符
  - 使用纯 JS base64 解码器模板（Plugin API 无 fetch/atob）
  - 加载后立即用 get_screenshot 验证图片是否正确渲染
  - 未能加载的图片用深灰色占位色块（{r:0.12, g:0.12, b:0.14}），节点名标注图片用途
- **Max Time**: 900s

### Story 3: Figma MCP 未连接的异常处理
- **Prompt**: "把 demo 转 Figma，项目路径 ~/Projects/test-app"
- **Expect**: 
  - 检测到 Figma MCP 未连接（`claude mcp list` 不包含 figma）
  - 引导用户执行 `claude mcp add --transport http figma https://mcp.figma.com/mcp` 并完成 OAuth
  - 检查用户席位是否为 Full（非 View/Dev 席位）
  - 如果是 View 席位，明确告知需要升级才能写入 Figma
  - 不在 MCP 未连接状态下尝试调用 Figma 工具
  - 提供完整的排障指引（权限错误 / 字体加载失败 / 代码超长等）
- **Max Time**: 120s

### Story 4: 复杂页面的图层组织和 Auto Layout 质量
- **Prompt**: "转 Figma，~/Projects/recipe-app-demo，重点保证卡片列表页的设计师可编辑性"
- **Expect**: 
  - Card 组件遵循标准结构：Card[VERTICAL] > CoverArea[FILL,FIXED] > Content[FILL,HUG] > Footer[HORIZONTAL]
  - 语义分组正确：Cover Image + Tag 包裹在 CoverArea Frame 内（Tag 用 ABSOLUTE 定位）
  - Icon + Label 包裹在 MetaRow Frame 内，禁止平级堆叠
  - 嵌套深度控制在 3 层以内（Section > Card > Content）
  - Auto Layout 尺寸模式正确：HUG 用于文本容器/按钮，FILL 用于子元素拉伸，FIXED 用于页面 Frame/图标
  - SVG 图标通过 createNodeFromSvg 创建后 appendChild 到父容器内，尺寸标准化为 4 的倍数
  - 间距使用 4/8 的倍数（xs=4, sm=8, md=16, lg=24, xl=32）
  - 新建 Frame 默认高度 100px 问题已处理（设置 layoutSizingVertical = "HUG"）
  - 文字节点设置 textAutoResize = "HEIGHT" + layoutSizingHorizontal = "FILL"
- **Max Time**: 600s

### Story 5: 与 demo-to-speckit 和 capture-demo-screenshots 的集成
- **Prompt**: "我已经用 /ae-demo-to-speckit 生成了 speckit，现在帮我把同一个 demo 转 Figma，项目在 ~/Projects/shoe-lens-demo"
- **Expect**: 
  - 识别已有 speckit/ 目录，可参考 speckit 中的页面清单和设计规范辅助构建
  - 预处理管线独立执行（不复用 speckit 的提取结果，因为 tokens 格式不同）
  - Step 5 自验证使用 `capture-demo-screenshots.sh` 截取 Demo 截图与 Figma 截图对比
  - 迭代修复阶段使用 Agent Team 分工：Coordinator（主 Agent）+ Image Loader（子 Agent）+ SVG Builder + Layout Fixer
  - 逐页完成：一个页面验证达标后再开始下一个
  - 每轮修复后必须截图验证，不盲信 use_figma 返回值
  - 输出 Figma 链接后，提示下一步"将 Figma 链接发给设计师精修"
- **Max Time**: 900s

You've hit your limit · resets 2am (Asia/Shanghai)

## 最近一次评估
- **日期**: 2026-04-14
- **环境**: Mac Mini (macOS 26.2 arm64)
- **总体通过率**: 1/5 (20%)
- **平均耗时**: 48.8s

## 测试结果

| Story | 得分 | 耗时 | 瓶颈 | 备注 |
|-------|------|------|------|------|
| S1: 基础 Happy Path | 0/5 | 63.4s | max turns (10) 耗尽，未产出任何结果 | 核心流程完全未跑通，预处理+Figma构建链路在10轮内无法完成 |
| S2: --with-b64 图片加载 | 0/5 | 55.0s | max turns (10) 耗尽 | 同 S1，连预处理阶段都未能完成 |
| S3: MCP 未连接异常处理 | 4/5 | 51.4s | — | 正确检测未连接、引导 `claude mcp add`、席位说明、排障表格均覆盖，输出末尾轻微截断扣1分 |
| S4: 图层组织与 Auto Layout | 0/5 | 51.6s | max turns (10) 耗尽 | 未进入 Figma 构建阶段，无法验证图层质量 |
| S5: 与 speckit 集成 | 0/5 | 22.7s | API rate limit（"You've hit your limit"） | 基础设施层面失败，skill 逻辑未被执行 |

## 瓶颈分析
- **max turns 上限是致命瓶颈（S1/S2/S4）**：skill 流程涉及预处理脚本执行→读取JSON→用户确认→Figma API多次调用→截图验证，步骤多且每步都需要工具调用，10 轮 turn 远远不够。建议将 max turns 提高至 30-50，或将预处理+Figma构建合并为更少的大步骤（如一次 bash 调用完成全部预处理，一次 use_figma 调用构建整页）。
- **API rate limit 导致 S5 完全未执行**：这是测试基础设施问题而非 skill 缺陷，但说明测试编排需要在多 story 间加入冷却间隔或使用独立配额。
- **仅异常处理路径通过（S3）**：唯一通过的 story 是不需要实际调用 Figma MCP 的纯引导场景，说明 skill 的"检测+引导"逻辑健全，但核心的"分析代码→构建 Figma 节点"主路径在当前 turn 限制下完全不可用。

## 结论
Skill 的异常处理路径设计合理（S3 得 4/5），但核心转换流程在 10 轮 turn 限制下 0% 通过，**当前不可交付**。最高优先级：将 max turns 提升至 ≥30 后重测主路径（S1），确认端到端可跑通后再优化图层质量（S4）和图片加载（S2）。

## 历史基线

| 日期 | 通过率 | 平均耗时 |
|------|--------|----------|
（待执行）
| 2026-04-13 | N/A | N/A |
| 2026-04-14 | 1/5 (20%) | 48.8s |
