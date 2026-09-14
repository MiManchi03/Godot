---
name: godot-plan-manager
description: 管理 HARNESS_PLAN.md：读取/更新/查询项目决策、任务、上下文。会话开始、做决策、需要项目记忆时使用。KEYWORDS: plan, decision, context, memory, HARNESS_PLAN, 计划, 决策, 上下文, 记忆
compatibility: opencode
metadata:
  category: orchestration
  triggers_en: ["plan", "decision", "context", "memory", "HARNESS_PLAN"]
  triggers_zh: ["计划", "决策", "上下文", "记忆"]
  zh_name: "Godot 计划管理器"
  zh_desc: "管理 HARNESS_PLAN.md：读取/更新/查询项目决策、任务、上下文。会话开始、做决策、需要项目记忆时使用。"
---

# godot-plan-manager

## What I do
- 读取 HARNESS_PLAN.md 恢复项目上下文
- 追加新决策/任务（带时间戳）
- 查询特定章节（决策、任务、拒绝项）
- 维护 plan.md 格式完整性

## When to use me
Use at session start, when making architectural decisions, adding tasks, or needing project memory. Use after context compression.

## Operations
- `read`: Return full plan content
- `read_section(section)`: Return specific section
- `append_decision(title, rationale, status)`: Add to confirmed decisions
- `append_task(title, subtasks, status)`: Add to in-progress tasks
- `update_task(task_id, status)`: Update task status
- `add_rejected(item, reason)`: Add to rejected list
- `sync_from_git()`: Refresh from latest commit