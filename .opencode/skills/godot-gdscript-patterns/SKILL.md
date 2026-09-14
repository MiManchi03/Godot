---
name: godot-gdscript-patterns
description: Godot 4.x GDScript 最佳实践：类型提示、信号模式、节点生命周期、性能优化。编写/审查 GDScript 时使用。KEYWORDS: gdscript, pattern, best, practice, type, hint, signal, lifecycle, performance, 最佳, 实践, 类型, 提示, 信号, 生命周期
compatibility: opencode
metadata:
  category: reference
  triggers_en: ["gdscript", "pattern", "best", "practice", "type", "hint", "signal", "lifecycle"]
  triggers_zh: ["gdscript", "模式", "最佳", "实践", "类型", "提示", "信号", "生命周期"]
  zh_name: "Godot GDScript 模式"
  zh_desc: "Godot 4.x GDScript 最佳实践：类型提示、信号模式、节点生命周期、性能优化。编写/审查 GDScript 时使用。"
---

# godot-gdscript-patterns

## What I do
提供 GDScript 4.x 开发的标准化模式库，防止常见错误，提升代码质量。

## Core Patterns

### 类型提示
```gdscript
@export var speed: float = 5.0
@export var names: Array[String] = []
var _cache: Dictionary = {}
func process(data: Dictionary) -> bool:
    return true
```

### 信号模式
```gdscript
signal health_changed(old: int, new: int)
func take_damage(amount: int) -> void:
    health -= amount
    health_changed.emit(health + amount, health)
```

### 节点生命周期
```gdscript
func _ready() -> void:
    # 初始化
    pass

func _enter_tree() -> void:
    # 进入场景树
    pass

func _exit_tree() -> void:
    # 清理资源
    pass
```

### 性能优化
- 避免在 _process/_physics_process 中 new()
- 缓存 get_node 结果
- 使用对象池而非频繁实例化
- 字符串拼接用 Array + join

## When to use me
Use when writing or reviewing GDScript code.