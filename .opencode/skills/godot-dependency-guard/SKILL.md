---
name: godot-dependency-guard
description: 检测未授权依赖、全局状态污染、单例滥用、循环引用。新增文件、修改 autoload 时使用。KEYWORDS: dependency, global, singleton, circular, autoload, 依赖, 全局, 单例, 循环, 自动加载
compatibility: opencode
metadata:
  category: architecture
  triggers_en: ["dependency", "global", "singleton", "circular", "autoload", "import"]
  triggers_zh: ["依赖", "全局", "单例", "循环", "自动加载", "导入"]
  zh_name: "Godot 依赖守护"
  zh_desc: "检测未授权依赖、全局状态污染、单例滥用、循环引用。新增文件、修改 autoload 时使用。"
---

# godot-dependency-guard

## What I do
- autoload 注册表：只有白名单类可注册为 Autoload
- 单例滥用：禁止在非管理器类中滥用单例模式
- 全局状态：检测全局字典/数组的无序写入
- 循环引用：节点树/脚本引用循环检测
- 资源泄漏：未释放的动态创建节点/资源
- 未授权导入：禁止引入白名单外的第三方库

## Allowlist File
- `deps.allowlist.json`

## Checks
- autoload 注册白名单
- 单例滥用检测
- 全局字典/数组无序写入
- 循环引用检测
- 资源泄漏检测
- 未授权导入检测

## Allowlist File
`deps.allowlist.json`

## When to use me
Use when adding files, modifying autoloads, or refactoring architecture.