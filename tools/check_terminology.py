#!/usr/bin/env python3
# tools/check_terminology.py
# 术语一致性检查器 - Pre-commit / CI 双重运行

import sys
import os
import re
import argparse
import subprocess
from pathlib import Path
from typing import List, Dict, Set

# Windows 默认 GBK stdout 会在输出中文/emoji 时崩溃；强制 UTF-8
for _stream in (sys.stdout, sys.stderr):
    _reconf = getattr(_stream, "reconfigure", None)
    if _reconf is not None:
        try:
            _reconf(encoding="utf-8")
        except Exception:
            pass

sys.path.insert(0, str(Path(__file__).parent))
from terminology_registry import TerminologyRegistry
from diff_scope import get_added_lines_range, get_range_files

SUFFIXES = {'.gd', '.tscn', '.md', '.yaml', '.yml', '.json', '.py'}
EXCLUDE_DIRS = {'.git', '.godot', 'node_modules', 'addons'}
# 术语治理机制自身的文件目录（定义/实现术语规则，必然包含原始词条，不对其自检）
EXCLUDE_PREFIXES = (
    '.opencode/terminology',
    '.opencode/routing',
    '.opencode/skills',
    '.opencode/agent',
    'tools',
)


def _is_excluded(filepath: Path) -> bool:
    if any(part in EXCLUDE_DIRS for part in filepath.parts):
        return True
    try:
        rel = filepath.resolve().relative_to(Path.cwd()).as_posix()
    except ValueError:
        rel = filepath.as_posix()
    return any(rel == p or rel.startswith(p + '/') for p in EXCLUDE_PREFIXES)


def should_check_file(filepath: Path) -> bool:
    return filepath.suffix in SUFFIXES and not _is_excluded(filepath)


def _expand(path: Path) -> List[Path]:
    if path.is_dir():
        return [p for p in path.rglob('*') if p.is_file() and should_check_file(p)]
    return [path]


def get_changed_files(only_staged: bool = False) -> List[Path]:
    """获取变更的文件列表"""
    try:
        if only_staged:
            result = subprocess.run(
                ["git", "diff", "--cached", "--name-only", "--diff-filter=ACM"],
                capture_output=True, text=True, encoding="utf-8", errors="replace", check=True
            )
        else:
            result = subprocess.run(
                ["git", "diff", "--name-only", "--diff-filter=ACM"],
                capture_output=True, text=True, encoding="utf-8", errors="replace", check=True
            )
        files = [Path(f).resolve() for f in result.stdout.strip().split('\n') if f.strip()]
        return [f for f in files if should_check_file(f) and f.exists()]
    except subprocess.CalledProcessError:
        return []


def get_added_lines(files: List[Path]) -> Dict[str, Set[int]]:
    """返回 {绝对路径: 本次暂存新增的行号集合}（来自 git diff --cached -U0）

    仅对"确有暂存改动"的文件建立键；未暂存的文件不建键，调用方将回退为整文件检查。
    """
    added: Dict[str, Set[int]] = {}
    root = Path.cwd()
    for f in files:
        try:
            rel = os.path.relpath(f, root)
            result = subprocess.run(
                ["git", "diff", "--cached", "-U0", "--", rel],
                capture_output=True, text=True, encoding="utf-8", errors="replace", check=True
            )
        except Exception:
            continue
        if not (result.stdout or "").strip():
            continue
        lines: Set[int] = set()
        cur = 0
        for ln in result.stdout.splitlines():
            m = re.match(r'^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@', ln)
            if m:
                cur = int(m.group(1))
                continue
            if ln.startswith('+++') or ln.startswith('---'):
                continue
            if ln.startswith('+'):
                lines.add(cur)
                cur += 1
        added[str(f)] = lines
    return added


def _rel(filepath: Path) -> Path:
    try:
        return filepath.relative_to(Path.cwd())
    except ValueError:
        return filepath


def main():
    parser = argparse.ArgumentParser(description="术语一致性检查器")
    parser.add_argument("--changed-only", action="store_true", help="仅检查变更文件")
    parser.add_argument("--staged", action="store_true", help="仅检查暂存区文件")
    parser.add_argument("--all", action="store_true", help="检查所有相关文件（已排除 vendor 目录）")
    parser.add_argument("--base", help="提交区间起点；只查 base..head 的新增行")
    parser.add_argument("--head", default="HEAD", help="提交区间终点（默认 HEAD）")
    parser.add_argument("--added-lines-only", action="store_true",
                        help="仅检查本次暂存新增行（供 pre-commit 用，避免历史遗留阻断）")
    parser.add_argument("--suggest", action="store_true",
                        help="额外提示疑似未注册术语（启发式，噪声大，默认关闭）")
    parser.add_argument("--fail-on-warning", action="store_true", help="WARNING 也视为失败")
    parser.add_argument("files", nargs="*", help="指定检查的文件或目录")
    args = parser.parse_args()

    registry = TerminologyRegistry()

    # 确定要检查的文件
    if args.base:
        files = [Path(f).resolve() for f in get_range_files(args.base, args.head)]
    elif args.files:
        collected: List[Path] = []
        for f in args.files:
            collected.extend(_expand(Path(f)))
        files = [f.resolve() for f in collected if f.exists()]
    elif args.changed_only or args.staged:
        files = get_changed_files(only_staged=args.staged)
    elif args.all:
        files = [p for p in Path(".").rglob("*") if p.is_file()]
    else:
        files = get_changed_files()

    # 过滤 + 去重
    files = [f for f in files if should_check_file(f) and f.exists()]
    seen: Set[str] = set()
    unique: List[Path] = []
    for f in files:
        key = str(f.resolve())
        if key not in seen:
            seen.add(key)
            unique.append(f)
    files = unique

    if not files:
        print("ℹ️  无需检查的文件")
        return 0

    if args.base:
        added_map = get_added_lines_range(files, args.base, args.head)
    elif args.added_lines_only:
        added_map = get_added_lines(files)
    else:
        added_map = {}

    scope = "（仅新增行）" if (args.added_lines_only or args.base) else ""
    print(f"🔍 检查 {len(files)} 个文件的术语一致性...{scope}")

    total_errors = 0
    total_warnings = 0

    for filepath in files:
        try:
            content = filepath.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        except Exception as e:
            print(f"⚠️  读取失败 {filepath}: {e}")
            continue

        violations = registry.check_content(content, str(filepath), suggest=args.suggest)
        allowed_lines = added_map.get(str(filepath))

        for v in violations:
            if allowed_lines is not None and v["line"] not in allowed_lines:
                continue
            rel_path = _rel(filepath)
            if v["severity"] == "ERROR":
                print(f"❌ {rel_path}:{v['line']}: {v['message']}")
                total_errors += 1
            elif v["severity"] == "WARNING":
                print(f"⚠️  {rel_path}:{v['line']}: {v['message']}")
                total_warnings += 1

    print(f"\n📊 检查完成: {total_errors} 个错误, {total_warnings} 个警告")

    if total_errors > 0:
        print("❌ 术语检查失败，请修复上述错误后重试")
        return 1

    if total_warnings > 0 and args.fail_on_warning:
        print("⚠️  存在警告，且配置为警告即失败")
        return 1

    if total_warnings > 0:
        print("✅ 术语检查通过（有警告但不阻断）")
    else:
        print("✅ 术语检查完全通过")

    return 0


if __name__ == "__main__":
    sys.exit(main())
