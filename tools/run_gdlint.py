#!/usr/bin/env python3
# tools/run_gdlint.py
# gdtoolkit(gdlint) 驱动：对 scripts/ 与 tests/ 下的 .gd 做静态分析
#   - 跳过超大文件（> 1MB，如 world_manager.gd，避免解析卡死）
# 追溯：审计 A6（无静态分析）；Phase 4 接入

import sys
import subprocess
from pathlib import Path

for _stream in (sys.stdout, sys.stderr):
    _reconf = getattr(_stream, "reconfigure", None)
    if _reconf is not None:
        try:
            _reconf(encoding="utf-8")
        except Exception:
            pass

MAX_BYTES = 1_000_000
ROOTS = ("scripts", "tests")


def collect() -> list:
    files = []
    for root in ROOTS:
        base = Path(root)
        if not base.exists():
            continue
        for p in base.rglob("*.gd"):
            try:
                if p.stat().st_size <= MAX_BYTES:
                    files.append(p.as_posix())
            except OSError:
                continue
    return sorted(files)


def main() -> int:
    files = collect()
    if not files:
        print("ℹ️  没有可分析的 .gd")
        return 0
    print(f"🔎 gdlint 分析 {len(files)} 个脚本（已跳过超大文件）")
    result = subprocess.run(
        [sys.executable, "-m", "gdtoolkit.linter", *files],
        text=True, encoding="utf-8", errors="replace"
    )
    return result.returncode


if __name__ == "__main__":
    sys.exit(main())
