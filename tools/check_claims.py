#!/usr/bin/env python3
# tools/check_claims.py
# 测试声明取证：文档中出现"有数字的测试/覆盖率结论"时，必须有测试产物佐证
# 追溯：红队演练 D5（虚假测试声明 —— 谎称 tests passed，实际未运行）
# 设计：仅拦截带数字的强声明，避免误伤普通讨论

import sys
import re
import argparse
import fnmatch
from pathlib import Path
from typing import List

for _stream in (sys.stdout, sys.stderr):
    _reconf = getattr(_stream, "reconfigure", None)
    if _reconf is not None:
        try:
            _reconf(encoding="utf-8")
        except Exception:
            pass

sys.path.insert(0, str(Path(__file__).parent))
from diff_scope import get_added_lines, get_staged_files

CLAIM_PATTERNS = [
    re.compile(r'\d+\s*(?:个)?\s*(?:单元)?测试\s*(?:通过|passed|pass)', re.I),
    re.compile(r'\d+\s*passed\b', re.I),
    re.compile(r'\b0\s*failed\b', re.I),
    re.compile(r'(?:覆盖率|coverage)\s*[:：]?\s*\d+', re.I),
    re.compile(r'\d+\s*%\s*(?:覆盖|coverage)', re.I),
]

EVIDENCE_GLOBS = [
    "test-results/**",
    "docs/evidence/**",
    "**/*.trx",
    "**/junit*.xml",
    "**/test-report*.xml",
]


def evidence_present(staged: List[str]) -> bool:
    for f in staged:
        for g in EVIDENCE_GLOBS:
            if fnmatch.fnmatch(f, g):
                return True
    for g in EVIDENCE_GLOBS:
        if list(Path(".").glob(g)):
            return True
    return False


def main():
    parser = argparse.ArgumentParser(description="测试声明取证检查")
    parser.add_argument("--added-lines-only", action="store_true", help="仅扫描本次新增行")
    parser.add_argument("files", nargs="*", help="指定文件")
    args = parser.parse_args()

    files = [Path(f).resolve() for f in args.files if Path(f).is_file()]
    if not files:
        print("ℹ️  无需检查的文件")
        return 0

    added_map = get_added_lines(files) if args.added_lines_only else {}

    claims = []
    for filepath in files:
        try:
            lines = filepath.read_text(encoding="utf-8").split('\n')
        except UnicodeDecodeError:
            continue
        except Exception:
            continue
        allowed = added_map.get(str(filepath))
        for i, line in enumerate(lines, 1):
            if allowed is not None and i not in allowed:
                continue
            for pat in CLAIM_PATTERNS:
                if pat.search(line):
                    claims.append((filepath, i, line.strip()))
                    break

    if not claims:
        print("✅ 未发现需要取证的测试声明")
        return 0

    staged = get_staged_files()
    if evidence_present(staged):
        print(f"✅ 发现 {len(claims)} 条测试声明，且存在测试产物佐证")
        return 0

    print("❌ 发现测试/覆盖率声明，但无任何测试产物佐证（test-results/、*.trx、junit*.xml）：")
    for filepath, i, text in claims:
        try:
            rel = filepath.relative_to(Path.cwd())
        except ValueError:
            rel = filepath
        print(f"   - {rel}:{i}: {text}")
    print("   请先运行测试并把产物落盘，或删除该声明（禁止无凭据的完成断言）")
    return 1


if __name__ == "__main__":
    sys.exit(main())
