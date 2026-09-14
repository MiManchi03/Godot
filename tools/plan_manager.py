#!/usr/bin/env python3
# tools/plan_manager.py
# 计划管理器 - 管理 HARNESS_PLAN.md

import re
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import List, Optional

PLAN_FILE = Path("HARNESS_PLAN.md")

@dataclass
class PlanSection:
    title: str
    content: str
    level: int

class PlanManager:
    def __init__(self):
        self.file = PLAN_FILE
        self._cache = None
        self._mtime = 0
    
    def _read_raw(self) -> str:
        if self.file.exists():
            stat = self.file.stat()
            if stat.st_mtime > self._mtime:
                self._cache = self.file.read_text(encoding="utf-8")
                self._mtime = stat.st_mtime
        return self._cache or ""
    
    def read(self) -> str:
        return self._read_raw()
    
    def read_section(self, section_title: str) -> str:
        """读取指定章节内容"""
        content = self._read_raw()
        pattern = rf"(^##\s+{re.escape(section_title)}.*?)(?=^## |\Z)"
        match = re.search(pattern, content, re.MULTILINE | re.DOTALL)
        return match.group(1).strip() if match else ""
    
    def append_decision(self, title: str, rationale: str, status: str = "✅ 已落地") -> None:
        """追加已确定决策"""
        entry = f"""
### [{datetime.now().strftime('%Y-%m-%d')}] {title}
- **决策**: {title}
- **依据**: {rationale}
- **状态**: {status}
"""
        self._insert_after_section("## ✅ 已确定决策记录", entry)
    
    def append_task(self, title: str, subtasks: List[str] = None, status: str = "🔄 进行中") -> None:
        """追加进行中任务"""
        subtask_md = "\n".join([f"  - [ ] {s}" for s in (subtasks or [])])
        entry = f"""
### [任务] {title}
- **状态**: {status}
- **子任务":
{subtask_md}
- **负责**: Harness 体系
- **预计完成": TBD
"""
        self._insert_after_section("## 🔄 进行中任务", entry)
    
    def update_task_status(self, task_title: str, new_status: str) -> bool:
        """更新任务状态"""
        content = self._read_raw()
        pattern = rf"(### \[任务\] {re.escape(task_title)}.*?- \*\*状态\*\*: )(.+?)(\n)"
        new_content = re.sub(pattern, rf"\1{new_status}\3", content, flags=re.DOTALL)
        if new_content != content:
            self.file.write_text(new_content, encoding="utf-8")
            return True
        return False
    
    def add_rejected(self, item: str, reason: str) -> None:
        entry = f"- ❌ {item}（原因: {reason}）"
        self._insert_after_section("## 🚫 明确拒绝/已排除", entry)
    
    def add_todo(self, item: str) -> None:
        entry = f"- [ ] {item}"
        self._insert_after_section("## 📋 待办事项", entry)
    
    def complete_todo(self, item: str) -> bool:
        content = self._read_raw()
        pattern = rf"(- \[ \] {re.escape(item)})"
        new_content = re.sub(pattern, f"- [x] {item}", content)
        if new_content != content:
            self.file.write_text(new_content, encoding="utf-8")
            return True
        return False
    
    def _insert_after_section(self, section_header: str, entry: str) -> None:
        content = self._read_raw()
        pattern = rf"(^##\s+{re.escape(section_header)}.*?)(?=^## |\Z)"
        match = re.search(pattern, content, re.MULTILINE | re.DOTALL)
        if match:
            insert_pos = match.end()
            new_content = content[:insert_pos] + "\n" + entry + content[insert_pos:]
            self.file.write_text(new_content, encoding="utf-8")
    
    def get_context_summary(self, max_chars: int = 3000) -> str:
        """获取上下文摘要（用于会话开始时注入）"""
        content = self._read_raw()
        sections = ["## 🎯 项目目标", "## ✅ 已确定决策记录", "## 🔄 进行中任务"]
        summary = ""
        for sec in sections:
            summary += self.read_section(sec.replace("## ", "")) + "\n\n"
            if len(summary) > max_chars:
                break
        return summary[:max_chars]
    
    def ensure_file_exists(self):
        """确保 plan 文件存在"""
        if not self.file.exists():
            initial = """# HARNESS_PLAN.md
# 版本: 1.0
# 最后更新: 2026-09-12
# 维护者: Harness PlanManager

---

## 🎯 项目目标
构建《我的天下》3D 开放世界生存游戏（Godot 4.6+）

---

## ✅ 已确定决策记录

---

## 🔄 进行中任务

---

## 📋 待办事项

---

## 🚫 明确拒绝/已排除

---

## 📚 参考资料链接

- SPEC.md: 游戏规格文档
- .opencode/terminology/TERMINOLOGY.yaml: 术语单一事实来源
- .opencode/routing/zh-en-map.yaml: 中英映射表
- .opencode/skills/*/SKILL.md: 14 个技能定义
- .opencode/agent/godot-engineer.md: 专用 Agent 配置
"""
            self.file.write_text(initial, encoding="utf-8")


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Harness Plan Manager")
    parser.add_argument("action", choices=["read", "section", "decision", "task", "update", "reject", "todo", "complete", "summary", "init"])
    parser.add_argument("--title", help="标题")
    parser.add_argument("--rationale", help="理由")
    parser.add_argument("--status", default="✅ 已落地", help="状态")
    parser.add_argument("--subtasks", nargs="*", help="子任务列表")
    parser.add_argument("--section", help="章节标题")
    parser.add_argument("--item", help="事项")
    parser.add_argument("--reason", help="拒绝理由")
    parser.add_argument("--max-chars", type=int, default=3000, help="摘要最大字符数")
    args = parser.parse_args()

    pm = PlanManager()
    pm.ensure_file_exists()

    if args.action == "init":
        print("✅ HARNESS_PLAN.md 初始化完成")
    elif args.action == "read":
        print(pm.read())
    elif args.action == "section":
        if not args.section:
            print("❌ 需要 --section 参数")
            return 1
        print(pm.read_section(args.section))
    elif args.action == "decision":
        if not args.title or not args.rationale:
            print("❌ 需要 --title 和 --rationale 参数")
            return 1
        pm.append_decision(args.title, args.rationale, args.status)
        print(f"✅ 已添加决策: {args.title}")
    elif args.action == "task":
        if not args.title:
            print("❌ 需要 --title 参数")
            return 1
        pm.append_task(args.title, args.subtasks, args.status)
        print(f"✅ 已添加任务: {args.title}")
    elif args.action == "update":
        if not args.title or not args.status:
            print("❌ 需要 --title 和 --status 参数")
            return 1
        if pm.update_task_status(args.title, args.status):
            print(f"✅ 已更新任务状态: {args.title} -> {args.status}")
        else:
            print(f"❌ 未找到任务: {args.title}")
            return 1
    elif args.action == "reject":
        if not args.item or not args.reason:
            print("❌ 需要 --item 和 --reason 参数")
            return 1
        pm.add_rejected(args.item, args.reason)
        print(f"✅ 已添加拒绝项: {args.item}")
    elif args.action == "todo":
        if not args.item:
            print("❌ 需要 --item 参数")
            return 1
        pm.add_todo(args.item)
        print(f"✅ 已添加待办: {args.item}")
    elif args.action == "complete":
        if not args.item:
            print("❌ 需要 --item 参数")
            return 1
        if pm.complete_todo(args.item):
            print(f"✅ 已完成待办: {args.item}")
        else:
            print(f"❌ 未找到待办: {args.item}")
            return 1
    elif args.action == "summary":
        print(pm.get_context_summary(args.max_chars))
    else:
        print(f"未知操作: {args.action}")
        return 1

    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main())