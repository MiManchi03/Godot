#!/usr/bin/env python3
# tools/diff_scope.py
# 差异范围工具：计算"本次改动的新增行"，供钩子/verify 做只查新增行的拦截
# 追溯：审计 A1（历史遗留不应阻断新提交）

import os
import re
import subprocess
from pathlib import Path
from typing import Dict, List, Set


def _run_git(args: List[str]) -> str:
    try:
        result = subprocess.run(
            ["git", *args],
            capture_output=True, text=True, encoding="utf-8", errors="replace", check=True
        )
        return result.stdout or ""
    except Exception:
        return ""


def _parse_added(diff_text: str) -> Set[int]:
    lines: Set[int] = set()
    cur = 0
    for ln in diff_text.splitlines():
        m = re.match(r'^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@', ln)
        if m:
            cur = int(m.group(1))
            continue
        if ln.startswith('+++') or ln.startswith('---'):
            continue
        if ln.startswith('+'):
            lines.add(cur)
            cur += 1
    return lines


def _add_lines_for(diff_args: List[str], files: List[Path]) -> Dict[str, Set[int]]:
    """对给定 git diff 参数前缀，逐文件计算新增行号。

    仅对确有差异的文件建立键；无差异的文件不建键，调用方回退为整文件检查。
    """
    added: Dict[str, Set[int]] = {}
    root = Path.cwd()
    for f in files:
        rel = os.path.relpath(f, root)
        out = _run_git(["diff", *diff_args, "-U0", "--", rel])
        if not out.strip():
            continue
        added[str(f)] = _parse_added(out)
    return added


def get_added_lines(files: List[Path]) -> Dict[str, Set[int]]:
    """本次暂存区新增行"""
    return _add_lines_for(["--cached"], files)


def get_added_lines_range(files: List[Path], base: str, head: str = "HEAD") -> Dict[str, Set[int]]:
    """base..head 提交区间的 added 行（供 verify.sh / CI 用）"""
    return _add_lines_for([base, head], files)


def get_staged_files() -> List[str]:
    """暂存区新增/修改文件（相对路径）"""
    out = _run_git(["diff", "--cached", "--name-only", "--diff-filter=ACM"])
    return [l.strip() for l in out.splitlines() if l.strip()]


def get_range_files(base: str, head: str = "HEAD") -> List[str]:
    """base..head 提交区间的新增/修改文件（相对路径）"""
    out = _run_git(["diff", "--name-only", "--diff-filter=ACM", base, head])
    return [l.strip() for l in out.splitlines() if l.strip()]
