---
name: godot-static-analyzer
description: GDScript 静态分析：类型安全、命名规范、性能反模式、死代码。保存文件、提交前、重构时使用。KEYWORDS: static, analysis, type, naming, performance, dead, code, lint, 静态, 分析, 类型, 命名, 性能, 死代码
compatibility: opencode
metadata:
  category: analysis
  triggers_en: ["static", "analysis", "type", "lint", "naming", "performance", "dead", "code"]
  triggers_zh: ["静态", "分析", "类型", "命名", "性能", "死代码", "检查"]
  zh_name: "Godot 静态分析"
  zh_desc: "GDScript 静态分析：类型安全、命名规范、性能反模式、死代码。保存文件、提交前、重构时使用。"
---

# godot-static-analyzer

## What I do
- 类型安全：类型注解完整性、类型不匹配、null 安全
- 命名规范：snake_case / PascalCase / CONST_SNAKE_CASE
- 性能反模式：_process/_physics_process 中 new()、频繁 get_node、字符串拼接
- Godot 最佳实践：信号优于轮询、单例规范、资源管理
- 死代码：未使用的变量/函数/常量/导入

## When to use me
Use on save, before commit, or when refactoring GDScript.

## Toolchain
- gdtoolkit / gdscript-lint / godot --check-only

## Rules Categories
- type_safety: 类型注解完整性、类型不匹配、null 安全
- naming: snake_case / PascalCase / CONST_SNAKE_CASE
- performance: _process 中 new()、频繁 get_node、字符串拼接
- godot_best_practices: 信号优先、单例规范、资源管理
- dead_code: 未使用的变量/函数/常量/导入

## Output
- diagnostics: { file, line, col, code, message, severity, fix_suggestion }