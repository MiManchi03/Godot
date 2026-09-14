#!/usr/bin/env python3
# tools/generate_component.py
# 代码生成器 - 强制术语注册、生成规范代码骨架

import sys
import argparse
import re
from pathlib import Path
from dataclasses import dataclass
from typing import List, Optional, Dict
from typing import Optional as Opt

sys.path.insert(0, str(Path(__file__).parent))
from terminology_registry import TerminologyRegistry, Term


@dataclass
class ComponentSpec:
    name: str
    type: str  # entity, resource, component, system, ui
    description: str
    base_class: str = "Node3D"
    exports: List[Dict] = None
    signals: List[Dict] = None
    methods: List[Dict] = None

    def __post_init__(self):
        if self.exports is None:
            self.exports = []
        if self.signals is None:
            self.signals = []
        if self.methods is None:
            self.methods = []


class ComponentGenerator:
    def __init__(self):
        self.registry = TerminologyRegistry()
        self.templates_dir = Path("tools/templates")
        self.templates_dir.mkdir(parents=True, exist_ok=True)

    def generate_entity(self, spec: ComponentSpec) -> str:
        """生成实体类"""
        # 确保术语已注册
        canonical = self._ensure_term_registered(
            spec.name, 
            domain="entity",
            context=spec.description
        )
        
        class_name = self._to_pascal(canonical)
        file_name = f"{class_name}.gd"
        
        # 生成导出属性
        exports_code = ""
        for exp in spec.exports:
            exp_type = exp.get("type", "int")
            exp_name = exp.get("name", "value")
            exp_default = exp.get("default", "0")
            exports_code += f'@export var {exp_name}: {exp_type} = {exp_default}\n'

        # 生成信号
        signals_code = ""
        for sig in spec.signals:
            sig_name = sig.get("name", "signal")
            params = sig.get("params", [])
            if params:
                param_str = ", ".join([f"{p['name']}: {p['type']}" for p in params])
                signals_code += f'signal {sig_name}({param_str})\n'
            else:
                signals_code += f'signal {sig_name}\n'

        # 生成方法
        methods_code = ""
        for method in spec.methods:
            m_name = method.get("name", "method")
            params = method.get("params", [])
            return_type = method.get("return", "void")
            body = method.get("body", "pass")
            
            param_str = ", ".join([f"{p['name']}: {p['type']}" for p in params])
            methods_code += f'\nfunc {m_name}({param_str}) -> {return_type}:\n    {body}\n'

        template = f'''extends {spec.base_class}
class_name {class_name}

# @term: {canonical} (canonical)
# @forbidden: {", ".join(self.registry.terms[canonical].forbidden) if canonical in self.registry.terms else ""}
# @description: {spec.description}

{exports_code}
{signals_code}
{methods_code}

func _ready() -> void:
    pass
'''
        return file_name, template

    def generate_resource(self, spec: ComponentSpec) -> str:
        """生成 Resource 资源类"""
        canonical = self._ensure_term_registered(
            spec.name,
            domain="entity",
            context=spec.description
        )
        
        class_name = self._to_pascal(canonical)
        file_name = f"{class_name}.gd"
        
        exports_code = ""
        for exp in spec.exports:
            exp_type = exp.get("type", "int")
            exp_name = exp.get("name", "value")
            exp_default = exp.get("default", "0")
            exports_code += f'@export var {exp_name}: {exp_type} = {exp_default}\n'

        template = f'''extends Resource
class_name {class_name}

# @term: {canonical} (canonical)
# @forbidden: {", ".join(self.registry.terms[canonical].forbidden) if canonical in self.registry.terms else ""}
# @description: {spec.description}

{exports_code}
'''
        return file_name, template

    def generate_component(self, spec: ComponentSpec) -> str:
        """生成组件类（挂载在节点上的组件）"""
        canonical = self._ensure_term_registered(
            spec.name,
            domain="component",
            context=spec.description
        )
        
        class_name = self._to_pascal(canonical)
        file_name = f"{class_name}.gd"
        
        exports_code = ""
        for exp in spec.exports:
            exp_type = exp.get("type", "int")
            exp_name = exp.get("name", "value")
            exp_default = exp.get("default", "0")
            exports_code += f'@export var {exp_name}: {exp_type} = {exp_default}\n'

        signals_code = ""
        for sig in spec.signals:
            sig_name = sig.get("name", "signal")
            params = sig.get("params", [])
            if params:
                param_str = ", ".join([f"{p['name']}: {p['type']}" for p in params])
                signals_code += f'signal {sig_name}({param_str})\n'
            else:
                signals_code += f'signal {sig_name}\n'

        methods_code = ""
        for method in spec.methods:
            m_name = method.get("name", "method")
            params = method.get("params", [])
            return_type = method.get("return", "void")
            body = method.get("body", "pass")
            
            param_str = ", ".join([f"{p['name']}: {p['type']}" for p in params])
            methods_code += f'\nfunc {m_name}({param_str}) -> {return_type}:\n    {body}\n'

        template = f'''extends Node
class_name {class_name}

# @term: {canonical} (canonical)
# @forbidden: {", ".join(self.registry.terms[canonical].forbidden) if canonical in self.registry.terms else ""}
# @description: {spec.description}

{exports_code}
{signals_code}
{methods_code}

func _ready() -> void:
    pass
'''
        return file_name, template

    def generate_resource_def(self, spec: ComponentSpec) -> str:
        """生成 .tres 资源定义文件"""
        canonical = self._ensure_term_registered(
            spec.name,
            domain="entity",
            context=spec.description
        )
        
        class_name = self._to_pascal(canonical)
        file_name = f"{canonical}.tres"
        
        exports_text = ""
        for exp in spec.exports:
            exp_type = exp.get("type", "int")
            exp_name = exp.get("name", "value")
            exp_default = exp.get("default", "0")
            exports_text += f'{exp_name} = {exp_default}\n'

        content = f'''[gd_resource type="Resource" script_class="{class_name}" load_steps=2 format=3 uid="uid://{canonical}"]

[ext_resource type="Script" path="res://scripts/{canonical}.gd" id="1"]

[resource]
script = ExtResource("1")
{exports_text}
'''
        return file_name, content

    def _ensure_term_registered(self, raw: str, domain: str, context: str) -> str:
        """确保术语已注册，返回 canonical"""
        raw = raw.strip()
        canonical = self._to_canonical(raw)
        
        # 检查是否已存在
        for term in self.registry.all_terms():
            if raw in term.aliases or raw == term.zh_label:
                return term.canonical
            for alias in term.aliases:
                if raw in alias or alias in raw:
                    return term.canonical
        
        # 自动推断 canonical
        canonical = self._to_canonical(raw)
        
        # 默认 forbidden：中文原词 + 常见变体
        forbidden = [raw, raw + "s", raw + "实体", raw + "单位", raw + "对象"]
        
        # 默认 aliases
        aliases = [canonical, canonical.capitalize(), canonical.upper()]
        
        # zh_label 使用原始中文
        zh_label = raw
        
        # 生成描述
        description = context or f"{raw} 实体"
        
        self.registry.register(
            canonical=canonical,
            aliases=aliases,
            forbidden=forbidden,
            zh_label=zh_label,
            description=context,
            domain=domain
        )
        return canonical

    def _to_canonical(self, raw: str) -> str:
        """将中文/英文转为 canonical 格式"""
        # 如果已经是英文单词，直接返回小写
        if re.match(r'^[a-zA-Z_]+$', raw):
            return raw.lower()
        
        # 中文转拼音首字母（简化版）
        # 实际项目中建议使用 pypinyin 库
        chinese_map = {
            '村民': 'villager', 'NPC': 'npc', '玩家': 'player',
            '建筑': 'building', '建筑物': 'building', '房屋': 'building',
            '资源': 'resource', '物品': 'item', '道具': 'item',
            '村民系统': 'villager_system', '世界管理器': 'world_manager',
            '世界状态': 'world_state', '道路网络': 'road_network',
            '资源生成器': 'resource_spawner', '群系生成器': 'biome_generator',
            '村庄生成器': 'village_generator', '玩家控制器': 'player_controller',
            '背包管理器': 'inventory_manager', '可破坏物': 'destructible',
            '背包UI': 'inventory_ui', '快捷栏UI': 'hotbar_ui',
            '设置菜单': 'settings_menu', '游戏设置': 'game_settings',
            '建筑预览控制器': 'build_preview_controller',
            '村民任务UI': 'villager_task_ui', '房屋详情UI': 'house_detail_ui',
            '交互UI': 'interact_ui', '光标管理器': 'cursor_manager',
            '游戏设置': 'game_settings', '建筑预览控制器': 'build_preview_controller',
            '村民任务UI': 'villager_task_ui', '房屋详情UI': 'house_detail_ui',
            '交互UI': 'interact_ui', '光标管理器': 'cursor_manager',
            '生成': 'spawn', '销毁': 'destroy', '破坏': 'destroy',
            '生成资源': 'spawn_resource', '生成村民': 'spawn_villager',
            '分配任务': 'assign_task', '放置建筑': 'place_building',
            '旋转建筑': 'rotate_building', '生成资源节点': 'spawn_resource_node',
            '加载区块': 'load_chunk', '卸载区块': 'unload_chunk',
            '存档': 'save_game', '读档': 'load_game',
            '注册术语': 'register_term', '同步映射': 'sync_mapping',
            '校验': 'validate', '接口': 'contract', '契约': 'contract',
            '信号': 'signal', '导出': 'export', '枚举': 'enum', '方法': 'method',
            '场景': 'scene', '节点': 'node', '一致性': 'consistency',
            '静态': 'static', '分析': 'analysis', '类型': 'type',
            '命名': 'naming', '性能': 'performance', '死代码': 'dead_code',
            '测试': 'test', '单元': 'unit', '集成': 'integration',
            '覆盖率': 'coverage', '回归': 'regression', '基线': 'baseline',
            '对比': 'compare', '守护': 'guard', '依赖': 'dependency',
            '全局': 'global', '单例': 'singleton', '循环': 'circular',
            '自动加载': 'autoload', '导入': 'import',
            '影响': 'impact', '波及': 'blast', '风险': 'risk',
            '分析': 'analysis', '变更': 'change', '生成': 'generate',
            '样板': 'boilerplate', '组件': 'component', '场景': 'scene',
            '资源': 'resource', '模板': 'template', '回滚': 'rollback',
            '检查点': 'checkpoint', '快照': 'snapshot', '撤销': 'undo',
            '编排': 'orchestrate', '分解': 'decompose', '任务': 'task',
            '计划': 'plan', '步骤': 'step', '破坏物': 'destructible',
            '可破坏': 'destructible', '村民': 'villager', 'NPC': 'npc',
            '群系': 'biome', '生物群系': 'biome', '方块': 'chunk', '区块': 'chunk',
            '生成': 'spawn', '销毁': 'destroy', '敌人': 'enemy', '怪物': 'monster',
            '建筑': 'building', '建造': 'construction', '村民': 'villager',
            '居民': 'villager', '方块': 'chunk', '区块': 'chunk'
        }
        
        if raw in chinese_map:
            return chinese_map[raw]
        
        # 简化：移除非字母数字字符，转小写
        return re.sub(r'[^\w]', '', raw).lower()

    def _to_pascal(self, s: str) -> str:
        return ''.join(word.capitalize() for word in s.split('_'))

    def generate_test_scaffold(self, class_name: str, canonical: str) -> str:
        """生成测试脚手架"""
        test_class = f"Test{class_name}"
        file_name = f"test_{canonical}.gd"
        
        template = f'''extends GutTest
class_name {test_class}

# @term: {canonical} (test)

func test_{canonical}_initialization() -> void:
    var instance = {canonical}.new()
    assert_not_null(instance)
    assert_eq(instance.get_class(), "{class_name}")

func test_{canonical}_default_values() -> void:
    var instance = {canonical}.new()
    # 添加默认值测试
    pass

func test_{canonical}_signals() -> void:
    var instance = {canonical}.new()
    # 添加信号测试
    pass
'''
        return f"test_{canonical}.gd", template


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Harness 代码生成器")
    parser.add_argument("type", choices=["entity", "resource", "component", "resource_def", "test"])
    parser.add_argument("--name", required=True, help="组件名称（中文或英文）")
    parser.add_argument("--description", default="", help="组件描述")
    parser.add_argument("--base", default="Node3D", help="基类")
    parser.add_argument("--output", default=".", help="输出目录")
    parser.add_argument("--interactive", action="store_true", help="交互模式")
    args = parser.parse_args()

    generator = ComponentGenerator()
    
    spec = ComponentSpec(
        name=args.name,
        type=args.type,
        description=args.description,
        base_class=args.base
    )
    
    if args.type == "entity":
        file_name, content = generator.generate_entity(spec)
    elif args.type == "resource":
        file_name, content = generator.generate_resource(spec)
    elif args.type == "component":
        file_name, content = generator.generate_component(spec)
    elif args.type == "resource_def":
        file_name, content = generator.generate_resource_def(spec)
    elif args.type == "test":
        canonical = generator._to_canonical(args.name)
        class_name = generator._to_pascal(canonical)
        file_name, content = generator.generate_test_scaffold(class_name, canonical)
    else:
        print(f"未知类型: {args.type}")
        return 1
    
    output_path = Path(args.output) / file_name
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(content, encoding="utf-8")
    
    print(f"✅ 已生成: {output_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())