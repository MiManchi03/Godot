#!/usr/bin/env python3
# tools/diff_scope.py
# 差异范围工具：计算本次暂存新增行，供 pre-commit 钩子做"仅新增行"拦截
# 追溯：审计 A1（历史遗留不应阻断新提交）

import os
import re
import subprocess
from pathlib import Path
from typing import Dict, List, Set


def get_added_lines(files: List[Path]) -> Dict[str, Set[int]]:
    """返回 {绝对路径: 本次暂存新增的行号集合}

    仅对"确有暂存改动"的文件建立键；未暂存的文件不建键，
    调用方据此回退为整文件检查（例如 pre-commit run --all-files）。
    Windows 下强制 UTF-8，避免 GBK 解码 git diff 输出时崩溃。
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


def get_staged_files() -> List[str]:
    """返回暂存区新增/修改的文件相对路径列表（POSIX 分隔）"""
    try:
        result = subprocess.run(
            ["git", "diff", "--cached", "--name-only", "--diff-filter=ACM"],
            capture_output=True, text=True, encoding="utf-8", errors="replace", check=True
        )
    except Exception:
        return []
    return [l.strip() for l in (result.stdout or "").splitlines() if l.strip()]
