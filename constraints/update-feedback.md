# 查收更新

## 被告知有更新时

当用户说“ae-qa 更新了”、“有更新”、“拉一下最新”等类似表述时，执行：

```bash
cd ~/.ae/qa && git pull origin main
```

如果当前安装仍复用旧目录，则使用实际安装目录。更新后读取 `CHANGELOG.md` 的最新版本条目，向用户汇报变化。

## 更新后反馈

拉取更新并汇报 CHANGELOG 内容后，执行反馈引导：

1. 从本次更新条目中提取 issue 编号。
2. 展示待验证列表，并给出具体验证建议。
3. 用户验证后，按 `.qa-agent.yml` 配置的 issue provider 回写验证结果；未配置 provider 时输出可复制的评论正文。
4. 汇总哪些通过、哪些有问题、哪些跳过。

示例：

```text
本次更新关联了以下 issue，请逐个验证：

1. #IHQXXX - /ae-qa-intake-check 资料评分规则调整
   建议：准备一个缺少数据库说明的入驻包，确认输出会标注缺口影响。

2. #IHQXXY - /ae-qa-generate-cases 增加自动化候选字段
   建议：对已有 qa/06-risk-map.md 的项目重新生成用例，检查每条用例是否有自动化建议。
```

## 本地 workaround 清理

如果 CHANGELOG 标注某个 workaround 已被内置，验证通过后提醒用户清理本地覆盖规则，避免旧规则与官方修复冲突。
