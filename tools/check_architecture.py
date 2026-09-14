#!/usr/bin/env python3
# tools/check_architecture.py
# 架构规则检查器
#   R1 process-allocation       : _process / _physics_process 内每帧分配内存
#   R2 cross-module-private     : 跨模块访问私有成员（obj._member，排除 self）
# 追溯：红队演练 D1（"_process 分配内存 + 跨模块直接访问私有状态"未被拦截）

import sys
import re
import argparse
from pathlib import Path
from typing import List, Dict, Set

for _stream in (sys.stdout, sys.stderr):
    _reconf = getattr(_stream, "reconfigure", None)
    if _reconf is not None:
        try:
            _reconf(encoding="utf-8")
        except Exception:
            pass

sys.path.insert(0, str(Path(__file__).parent))
from diff_scope import get_added_lines

MAX_FILE_BYTES = 8 * 1024 * 1024  # 超大脚本跳过，避免卡死

FUNC_RE = re.compile(r'^(\s*)func\s+(_process|_physics_process)\s*\(')

ALLOC_PATTERNS = [
    re.compile(r'=\s*\[\s*\]'),            # 空数组字面量
    re.compile(r'=\s*\{\s*\}'),            # 空字典字面量
    re.compile(r'\bArray\s*\('),
    re.compile(r'\bDictionary\s*\('),
    re.compile(r'\bPacked\w+Array\s*\('),
    re.compile(r'\.new\s*\('),
    re.compile(r'\.instantiate\s*\('),
    re.compile(r'\.duplicate\s*\('),
    re.compile(r'\bcreate_tween\s*\('),
]

PRIVATE_RE = re.compile(r'(?<![\w.])([A-Za-z_]\w*)\._(\w+)')


def _indent(line: str) -> int:
    return len(line) - len(line.lstrip(' \t'))


def _strip_comment(line: str) -> str:
    idx = line.find('#')
    return line if idx < 0 else line[:idx]


def check_file(path: Path) -> List[Dict]:
    violations: List[Dict] = []
    try:
        if path.stat().st_size > MAX_FILE_BYTES:
            print(f"⚠️  跳过超大文件（>{MAX_FILE_BYTES // 1024 // 1024}MB）: {path}")
            return violations
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return violations
    except Exception as e:
        print(f"⚠️  读取失败 {path}: {e}")
        return violations

    lines = text.split('\n')

    # R1: _process / _physics_process 内的每帧分配
    in_process = False
    body_indent = 0
    for i, raw in enumerate(lines, 1):
        line = _strip_comment(raw)
        m = FUNC_RE.match(line)
        if m:
            in_process = True
            body_indent = len(m.group(1))
            continue
        if not in_process:
            continue
        if line.strip() == '':
            continue
        if _indent(line) <= body_indent:
            in_process = False
            continue
        for pat in ALLOC_PATTERNS:
            if pat.search(line):
                violations.append({
                    "file": str(path), "line": i, "severity": "ERROR",
                    "rule": "process-allocation",
                    "message": f'_process/_physics_process 内每帧分配，请缓存或复用（命中 {pat.pattern}）',
                })
                break

    # R2: 跨模块私有成员访问
    for i, raw in enumerate(lines, 1):
        line = _strip_comment(raw)
        for mm in PRIVATE_RE.finditer(line):
            obj, member = mm.group(1), mm.group(2)
            if obj == 'self':
                continue
            violations.append({
                "file": str(path), "line": i, "severity": "ERROR",
                "rule": "cross-module-private",
                "message": f'跨模块访问私有成员 {obj}._{member}，请改用公开接口',
            })

    return violations


def _collect_files(args) -> List[Path]:
    if args.files:
        out: List[Path] = []
        for f in args.files:
            p = Path(f)
            if p.is_dir():
                out.extend(p.rglob('*.gd'))
            else:
                out.append(p)
        return [p.resolve() for p in out if p.exists() and p.suffix == '.gd']
    if args.all:
        return [p for p in Path('.').rglob('*.gd')
                if not any(x in p.parts for x in {'.git', '.godot', 'node_modules', 'addons'})]
    return []


def main():
    parser = argparse.ArgumentParser(description="架构规则检查器")
    parser.add_argument("--all", action="store_true", help="检查所有 .gd")
    parser.add_argument("--added-lines-only", action="store_true",
                        help="仅检查本次暂存新增行（供 pre-commit 用）")
    parser.add_argument("files", nargs="*", help="指定文件或目录")
    args = parser.parse_args()

    files = _collect_files(args)
    if not files:
        print("ℹ️  无需检查的文件")
        return 0

    added_map = get_added_lines(files) if args.added_lines_only else {}

    scope = "（仅新增行）" if args.added_lines_only else ""
    print(f"🧱 架构规则检查 {len(files)} 个脚本...{scope}")

    total = 0
    for filepath in files:
        allowed = added_map.get(str(filepath))
        for v in check_file(filepath):
            if allowed is not None and v["line"] not in allowed:
                continue
            try:
                rel = filepath.relative_to(Path.cwd())
            except ValueError:
                rel = filepath
            print(f"❌ {rel}:{v['line']}: [{v['rule']}] {v['message']}")
            total += 1

    print(f"\n📊 架构检查完成: {total} 个违规")
    if total > 0:
        print("❌ 架构规则检查失败")
        return 1
    print("✅ 架构规则检查通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
