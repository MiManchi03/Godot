---
name: godot-task-orchestrator
description: 将高层任务分解为可验证的微步骤，编排 12 个 Skills，强制检查点，人工关口。多步骤功能开发时使用。KEYWORDS: orchestrate, decompose, checkpoint, task, orchestration, 编排, 分解, 检查点, 任务
compatibility: opencode
metadata:
  category: orchestration
  triggers_en: ["orchestrate", "decompose", "checkpoint", "task", "plan", "step"]
  triggers_zh: ["编排", "分解", "检查点", "任务", "计划", "步骤"]
  zh_name: "Godot 任务编排器"
  zh_desc: "将高层任务分解为可验证的微步骤，编排 12 个 Skills，强制检查点，人工关口。多步骤功能开发时使用。"
---

# godot-task-orchestrator

## What I do
- task_decomposition: 高层需求 → 有序步骤清单（每步含目标、输入、输出、验收技能、回滚点）
- checkpoint_gate: 每步结束强制运行关联 Skills，失败即回滚
- skill_invocation: 按依赖顺序调用 12 个核心 Skills
- context_management: 维护任务上下文，防止遗忘
- human_gate: 关键决策点暂停等待人工确认
- progress_report: 实时进度 + 风险预警 + 完成度

## Execution Model
- 单任务单线程执行
- 步骤间强制同步
- 全程可观测

## When to use me
Use for multi-step feature work requiring multiple skills.