#!/usr/bin/env python3
# tools/check_docs_fresh.py
# 活文档新鲜度守卫：改了游戏脚本，必须同批更新 STATUS.md 或 PITFALLS.md
# 追溯：红队演练 D7（改代码不更新活文档，无机制发现）
# 逃生阀：设置 HARNESS_ALLOW_STALE_DOC=1 或存在 .harness/allow-stale-doc 时跳过

import os
import sys
from pathlib import Path

for _stream in (sys.stdout, sys.stderr):
    _reconf = getattr(_stream, "reconfigure", None)
    if _reconf is not None:
        try:
            _reconf(encoding="utf-8")
        except Exception:
            pass

sys.path.insert(0, str(Path(__file__).parent))
from diff_scope import get_staged_files

CODE_PREFIX = "scripts/"
CODE_SUFFIX = ".gd"
LIVING_DOCS = {"STATUS.md", "PITFALLS.md"}
ALLOW_MARKER = Path(".harness/allow-stale-doc")


def main():
    if os.environ.get("HARNESS_ALLOW_STALE_DOC") == "1" or ALLOW_MARKER.exists():
        print("ℹ️  活文档新鲜度守卫已被逃生阀跳过")
        return 0

    staged = get_staged_files()
    if not staged:
        print("ℹ️  无暂存文件")
        return 0

    code_changed = [
        f for f in staged
        if f.startswith(CODE_PREFIX) and f.endswith(CODE_SUFFIX)
    ]
    docs_changed = [f for f in staged if Path(f).name in LIVING_DOCS]

    if code_changed and not docs_changed:
        print("❌ 改动了游戏脚本，但未同批更新活文档：")
        for f in code_changed:
            print(f"   - {f}")
        print("   请更新 STATUS.md 或 PITFALLS.md 后一并提交；")
        print("   若确属无需记录的微改，可设 HARNESS_ALLOW_STALE_DOC=1 或建 .harness/allow-stale-doc")
        return 1

    print("✅ 活文档新鲜度通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
