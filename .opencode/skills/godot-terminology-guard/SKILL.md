---
name: godot-terminology-guard
description: 术语治理三层闸口：生成器强制注册、Pre-commit 扫描、CI 双重校验。新增/修改术语时使用。KEYWORDS: terminology, term, forbidden, alias, canonical, register, 术语, 禁用词, 别名, 标准词, 注册
compatibility: opencode
metadata:
  category: governance
  triggers_en: ["terminology", "term", "forbidden", "alias", "canonical", "register"]
  triggers_zh: ["术语", "术语表", "禁用词", "别名", "标准词", "注册"]
  zh_name: "Godot 术语守护"
  zh_desc: "术语治理三层闸口：生成器强制注册、Pre-commit 扫描、CI 双重校验。新增/修改术语时使用。"
---

# godot-terminology-guard

## What I do
- 节点1 代码生成器层：源头治理，生成代码前强制术语注册
- 节点2 Pre-commit 层：兜底校验，扫描 forbidden 词、未注册术语
- 节点3 CI 层：双重校验，映射表同步性检查

## Terminology Source
- `.opencode/terminology/TERMINOLOGY.yaml` (单一事实来源)

## Three Gates
1. **生成器层**：代码生成器强制注册新术语 → 自动同步映射表
2. **Pre-commit层**：扫描 forbidden 词 → ERROR 阻断；发现未注册术语 → WARNING
3. **CI层**：双重校验 + 映射表同步性检查

## Forbidden Words Example
- npc: forbidden ["人物", "角色", "居民", "村民", "单位", "实体"]
- spawn: forbidden ["创建", "新建", "添加", "产生", "出现"]

## When to use me
Use when adding/modifying terminology, or when pre-commit/CI flags terminology issues.