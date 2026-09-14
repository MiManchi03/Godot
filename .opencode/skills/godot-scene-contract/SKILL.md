---
name: godot-scene-contract
description: 校验 .tscn 场景与 .gd 脚本一致性（节点路径、信号连接、导出变量、组名）。编辑场景或其脚本时使用。KEYWORDS: scene, node, signal, export, consistency, 场景, 节点, 信号, 导出, 一致性
compatibility: opencode
metadata:
  category: validation
  triggers_en: ["scene", "node", "signal", "export", "consistency", "tscn"]
  triggers_zh: ["场景", "节点", "信号", "导出", "一致性"]
  zh_name: "Godot 场景契约"
  zh_desc: "校验 .tscn 场景与 .gd 脚本一致性（节点路径、信号连接、导出变量、组名）。编辑场景或其脚本时使用。"
---

# godot-scene-contract

## What I do
- 验证 @onready 节点路径在场景中存在
- 检查信号连接的目标方法是否存在
- 校验导出变量类型/默认值与脚本一致
- 校验组名拼写一致性
- 校验子场景实例化参数一致性

## When to use me
Use when editing scenes (.tscn) or their attached scripts (.gd).

## Checks
- @onready 节点路径存在性
- 信号连接目标方法存在性
- 导出变量类型/默认值一致性
- 组名拼写一致性
- 子场景实例化参数一致性

## Enforcement
- Missing nodes → ERROR
- Signal mismatches → ERROR
- Export mismatches → WARNING
- Group mismatches → WARNING