---
name: godot-regression-guard
description: 回归测试守护：改前跑基线、改后对比、自动定位新失败。任意代码修改前后使用。KEYWORDS: regression, baseline, compare, guard, test, 回归, 基线, 对比, 守护
compatibility: opencode
metadata:
  category: testing
  triggers_en: ["regression", "baseline", "compare", "guard", "test"]
  triggers_zh: ["回归", "基线", "对比", "守护"]
  zh_name: "Godot 回归守护"
  zh_desc: "回归测试守护：改前跑基线、改后对比、自动定位新失败。任意代码修改前后使用。"
---

# godot-regression-guard

## What I do
1. pre_change: 运行全量测试记录 baseline_results
2. apply_change: 用户/模型应用代码变更
3. post_change: 运行全量测试得 new_results
4. diff: 对比 baseline vs new
   - new_failures: 本次变更导致的新失败
   - fixed: 本次变更修复的旧失败
   - flaky: 不稳定测试标记
5. report: 生成回归报告 + 定位建议

## Enforcement
- new_failures > 0 且非预期 → 阻止提交
- 自动关联变更文件与失败测试

## When to use me
Use before/after any code modification.