---
description: "图片去版权化 — AI 重绘生成可商用替代"
dependencies:
  mcp: []
  cli:
    - name: python3
      verify: "python3 --version"
  api_keys:
    - GEMINI_API_KEY
  scripts: []
smoke_test:
  command: "grep -q GEMINI_API_KEY ~/.config/ae/credentials.env 2>/dev/null"
  expected_exit: 0
  description: "GEMINI_API_KEY configured"
---

# Skill: 图片去版权化 (image-decopyrighter)

## 触发条件

当用户需要将有版权风险的图片处理为可商用素材时触发。典型场景：
- PM 在 vibe coding 阶段使用了网络图片作为 demo 占位素材，需要替换为可商用版本
- 用户提供一张或多张图片，要求"去版权"、"重绘"、"生成可商用替代"

## 核心原则

**保留含义，改变表现** — 不能完全不改（会侵权），也不能乱改（会失真）。

1. **语义一致性**：输出图片必须与原图保持相同的视觉语义（运动卡→运动卡，鞋子→鞋子）
2. **视觉差异性**：输出必须与原图有足够视觉差异，无法被举证为同一张图片
3. **版权安全**：不包含品牌名、logo、具体人名、受版权保护的角色

## 前置条件

**全程只需一个 key**：`GEMINI_API_KEY`。语义提取用 Gemini 2.5 Flash Vision，图片生成用 Imagen 4.0。

```bash
# 默认配置 — 只需一个 key：
export GEMINI_API_KEY="AIza..."      # Google AI Studio 获取，或向管理员领取

# 备选后端（按需配置）：
export TOGETHER_API_KEY="..."        # Together AI ($0.003/张)
export OPENAI_API_KEY="sk-..."       # DALL-E 3 ($0.04/张)
```

建议写入 `~/.config/ae/credentials.env` 以便持久化。

## 执行流程

### Step 1: 确认输入

确认用户提供的图片：
- 单张图片路径，或一个包含多张图片的目录
- 可选：用户期望的风格（如"插画风"、"扁平化"、"水彩"）
- 可选：输出尺寸偏好

如果用户没有指定图片路径，询问。

### Step 2: 查看原图

使用 Read 工具读取原始图片，理解其内容：
- 图片的主题是什么？（产品、人物、场景、图标、卡片...）
- 有哪些版权风险点？（品牌 logo、具体人物、受版权保护的设计）
- 图片的用途是什么？（UI 占位图、产品展示、背景...）

向用户简要描述你看到的内容，确认理解正确。

### Step 3: 执行去版权化

调用工具脚本处理图片。

**单张图片（默认 Gemini/Imagen 4.0，免费）：**

```bash
python3 "$AE_HOME/cli/lib/image_decopyrighter.py" auto <image_path> [--style <风格>] [--size <尺寸>]
```

**切换后端：**

```bash
python3 "$AE_HOME/cli/lib/image_decopyrighter.py" auto <image_path> --backend together  # Flux
python3 "$AE_HOME/cli/lib/image_decopyrighter.py" auto <image_path> --backend dalle      # DALL-E 3
```

**批量处理：**

```bash
python3 "$AE_HOME/cli/lib/image_decopyrighter.py" batch <img1> <img2> ... [--output <输出目录>] [--style <风格>]
```

**如果需要更精细控制（分步执行）：**

```bash
# Step A: 提取语义描述
python3 "$AE_HOME/cli/lib/image_decopyrighter.py" describe <image_path> --style <风格>

# Step B: 人工审核/修改 prompt 后生成（可选后端）
python3 "$AE_HOME/cli/lib/image_decopyrighter.py" generate "<prompt>" <output_path>                # gemini (默认)
python3 "$AE_HOME/cli/lib/image_decopyrighter.py" generate "<prompt>" <output_path> --backend dalle  # DALL-E 3
```

尺寸选项：
- `1024x1024` — 正方形（默认，适合产品图、头像）
- `1792x1024` — 横版（适合 banner、背景）
- `1024x1792` — 竖版（适合手机壁纸、竖屏素材）

### Step 4: 验证结果

使用 Read 工具查看生成的图片，对比原图：

检查清单：
- [ ] **语义一致**：新图与原图表达的是同一类内容吗？
- [ ] **视觉差异**：新图与原图看起来明显不同吗？
- [ ] **品牌清除**：新图中没有任何品牌标识、具体人名吗？
- [ ] **质量可用**：新图的质量是否满足实际使用需求？

如果不满意，可以：
1. 调整风格提示重新生成（`--style "illustration"`, `--style "flat design"` 等）
2. 手动修改 describe 输出的 prompt，再单独 generate
3. 换一个尺寸重试

### Step 5: 输出报告

向用户汇报结果：

```
✅ 图片去版权化完成

| 原图 | 新图 | 状态 |
|------|------|------|
| source.png | source_decopyrighted.png | ✅ 语义一致，视觉差异充分 |

📁 输出目录: <path>
📋 元数据: <path>_decopyrighted.meta.json

⚠️ 提示：AI 生成图片可降低版权风险，但无法提供法律保证。
建议在正式上线前进行人工审核。
```

## 支持的风格提示

| 风格 | 适用场景 |
|------|----------|
| (空) | 默认自然风格，保持写实感 |
| illustration | 插画风格，适合 UI 配图 |
| flat design | 扁平化设计，适合 icon 和简约界面 |
| watercolor | 水彩风格，适合艺术感素材 |
| 3d render | 3D 渲染风格，适合产品展示 |
| sketch | 手绘素描风格 |
| minimalist | 极简风格 |

## 故障排查

| 问题 | 解决方案 |
|------|----------|
| `GEMINI_API_KEY not set` | 配置 Gemini API Key（向管理员获取或从 Google AI Studio 创建）|
| `TOGETHER_API_KEY not set` | 仅 `--backend together` 时需要 |
| `OPENAI_API_KEY not set` | 仅 `--backend dalle` 时需要 |
| 生成图片语义偏差大 | 用 `describe` 单独提取 prompt，手动修改后 `generate` |
| 图片内容被 DALL-E 拒绝 | DALL-E 有内容策略限制，尝试修改 prompt 去除敏感元素 |
| 生成速度慢 | DALL-E 3 单张约 15-30 秒，批量处理按顺序执行 |
