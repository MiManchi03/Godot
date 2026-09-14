---
name: godot-contract-guard
description: 守护公共接口契约（信号、方法、导出属性、枚举、常量）。修改 scripts/world/, scripts/player/, scripts/npc/ 下任何公共接口时使用。KEYWORDS: contract, signal, export, method, enum, interface, 契约, 接口, 信号
compatibility: opencode
metadata:
  category: contract
  triggers_en: ["contract", "signal", "export", "method", "enum", "interface", "api"]
  triggers_zh: ["契约", "接口", "信号", "导出", "枚举", "方法", "API"]
  zh_name: "Godot 契约守护"
  zh_desc: "守护公共接口契约（信号、方法、导出属性、枚举、常量）。修改 scripts/world/, scripts/player/, scripts/npc/ 下任何公共接口时使用。"
---

# godot-contract-guard

## What I do
- 对比 .contract.json 与实际代码，检测 breaking changes
- 验证信号签名、方法签名、导出属性、枚举值、常量
- 生成契约差异报告：breaking changes / safe changes / new APIs

## When to use me
Use when modifying any public API in scripts/world/, scripts/player/, scripts/npc/.
Breaking changes require human confirmation.

## Contract Format
```json
{
  "class": "WorldManager",
  "signals": [{"name": "player_spawn_ready", "params": [{"name": "safe_position", "type": "Vector3"}]}],
  "methods": [{"name": "_ready", "params": [], "return": "void"}],
  "exports": [{"name": "world_seed", "type": "int", "default": 91357}],
  "enums": [{"name": "BuildingType", "values": ["HOUSE", "WORKSHOP", "WAREHOUSE"]}],
  "constants": [{"name": "CHUNK_SIZE", "value": 32}]
}
```

## Enforcement
- Breaking changes → human_gate: true (must confirm)
- Safe changes → auto-approve
- Auto-generates migration guide for breaking changes