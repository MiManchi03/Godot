---
name: godot-rollback-manager
description: Git 自动检查点、瞬时回滚、语义化标签。每个验证通过的检查点自动创建，失败时一键回退。KEYWORDS: rollback, checkpoint, git, rollback, undo, snapshot, 回滚, 检查点, 快照
compatibility: opencode
metadata:
  category: safety
  triggers_en: ["rollback", "checkpoint", "git", "snapshot", "undo"]
  triggers_zh: ["回滚", "检查点", "快照", "撤销"]
  zh_name: "Godot 回滚管理器"
  zh_desc: "Git 自动检查点、瞬时回滚、语义化标签。每个验证通过的检查点自动创建，失败时一键回退。"
---

# godot-rollback-manager

## What I do
- auto_checkpoint: 每个验证通过的检查点自动 `git commit -m "checkpoint: <task> <step>"`
- instant_rollback: `rollback <checkpoint_id>` 一键回退到干净状态
- semantic_tags: `git tag checkpoint/<task>/<step>/<timestamp>`
- dirty_worktree_protection: 工作区脏时禁止开始新任务
- bisect_helper: 回归时自动 `git bisect` 定位引入 commit

## Features
- 自动检查点：每个验证门通过后自动提交
- 瞬时回滚：一键回退到任意检查点
- 语义化标签：结构化 tag 便于追溯
- 脏工作区保护：禁止在脏状态下开始新任务
- bisect 辅助：自动二分查找回归引入点

## When to use me
Use at every validation gate, on failure, before risky changes.