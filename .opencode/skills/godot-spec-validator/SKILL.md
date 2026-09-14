---
name: godot-spec-validator
description: 校验 SPEC.md 验收标准是否被代码满足。修改游戏逻辑、新增功能、更新 SPEC.md 时使用。KEYWORDS: validate, spec, acceptance, criteria, 验收, 规格, 校验
compatibility: opencode
metadata:
  category: validation
  triggers_en: ["SPEC.md", "game logic", "feature", "acceptance criteria"]
  triggers_zh: ["SPEC.md", "游戏逻辑", "新功能", "验收标准"]
  zh_name: "Godot 规格验证器"
  zh_desc: "校验 SPEC.md 验收标准是否被代码满足。修改游戏逻辑、新增功能、更新 SPEC.md 时使用。"
---

# godot-spec-validator

## What I do
- 解析 SPEC.md 第 5 节"验收标准"为可执行规则
- 对比变更文件与相关验收标准
- 输出合规报告：通过/失败、违规位置、覆盖率

## When to use me
Use when modifying game logic, adding features, or updating SPEC.md.
Ask clarifying questions if acceptance criteria are ambiguous.

## Inputs
- `spec_path`: Path to SPEC.md (default: "SPEC.md")
- `changed_files`: List of files modified in this change

## Outputs
- `compliance_report`: { passed: bool, violations: [...], coverage: float }
- Violation format: { rule_id, file, line, message, severity }

## Enforcement
- severity >= ERROR blocks commit
- Runs in pre-commit and CI