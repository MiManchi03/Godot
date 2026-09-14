---
name: godot-code-generator
description: 生成样板代码：组件、场景、资源、测试。新增组件类型（建筑、资源、NPC）时使用。强制术语注册。KEYWORDS: generate, boilerplate, component, scene, resource, template, 生成, 样板, 组件, 场景, 资源, 模板
compatibility: opencode
metadata:
  category: generation
  triggers_en: ["generate", "boilerplate", "component", "scene", "resource", "template"]
  triggers_zh: ["生成", "样板", "组件", "场景", "资源", "模板"]
  zh_name: "Godot 代码生成器"
  zh_desc: "生成样板代码：组件、场景、资源、测试。新增组件类型（建筑、资源、NPC）时使用。强制术语注册。"
---

# godot-code-generator

## What I do
- component_template: 新增可破坏物/建筑/村民类型
- signal_boilerplate: 信号声明+发射+连接模板
- scene_factory: 按规范生成 .tscn + .gd 配套文件
- resource_def: 物品/方块/实体数据定义生成
- test_scaffold: 针对新类自动生成测试桩

## Enforcement
- 所有新增类型必须通过生成器创建
- 生成代码自动包含：类型注解、文档注释、测试桩、契约文件
- 强制术语注册：生成前必须注册标准术语

## Generators
- component_template: 新增实体类型
- signal_boilerplate: 信号模板
- scene_factory: 场景工厂
- resource_def: 资源定义
- test_scaffold: 测试脚手架

## When to use me
Use when adding new component types (buildings, resources, NPCs).