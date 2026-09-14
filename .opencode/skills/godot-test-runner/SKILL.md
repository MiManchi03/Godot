---
name: godot-test-runner
description: 运行单元/集成/无头测试并检查覆盖率阈值。实现逻辑后、提交前、CI 中使用。KEYWORDS: test, unit, integration, headless, coverage, gut, 测试, 单元, 集成, 覆盖率
compatibility: opencode
metadata:
  category: testing
  triggers_en: ["test", "unit", "integration", "headless", "coverage", "gut"]
  triggers_zh: ["测试", "单元", "集成", "覆盖率"]
  zh_name: "Godot 测试运行器"
  zh_desc: "运行单元/集成/无头测试并检查覆盖率阈值。实现逻辑后、提交前、CI 中使用。"
---

# godot-test-runner

## What I do
- 运行单元测试：纯逻辑类
- 运行集成测试：场景级交互
- 运行无头测试：完整游戏流程
- 检查覆盖率阈值

## Test Types
- unit: 纯逻辑类
- integration: 场景级交互
- headless: 完整游戏流程

## Coverage Thresholds
- statements: 80%
- branches: 70%
- functions: 85%

## CI Integration
- 每次 PR 自动运行
- 失败即阻塞合并
- 覆盖率下降即阻塞

## When to use me
Use after implementing logic, before commit, in CI.