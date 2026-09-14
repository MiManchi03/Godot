#!/usr/bin/env python3
# tools/check_dependencies.py
# 依赖白名单检查：project.godot 的 autoload 必须与 deps.allowlist.json 一致
# 追溯：审计 A6/A12 drift（allowlist 缺 VillageService、多出非 autoload 的 WorldManager）

import sys
import json
import re
import argparse
from pathlib import Path
from typing import List, Set

for _stream in (sys.stdout, sys.stderr):
    _reconf = getattr(_stream, "reconfigure", None)
    if _reconf is not None:
        try:
            _reconf(encoding="utf-8")
        except Exception:
            pass

PROJECT_FILE = Path("project.godot")
ALLOWLIST_FILE = Path("deps.allowlist.json")

AUTOLOAD_ENTRY = re.compile(r'^([A-Za-z_]\w*)="\*res://')


def parse_autoloads(project_path: Path) -> Set[str]:
    names: Set[str] = set()
    in_section = False
    for raw in project_path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if line.startswith('[') and line.endswith(']'):
            in_section = (line == '[autoload]')
            continue
        if not in_section or not line or line.startswith(';'):
            continue
        m = AUTOLOAD_ENTRY.match(line)
        if m:
            names.add(m.group(1))
    return names


def main():
    parser = argparse.ArgumentParser(description="依赖白名单检查器")
    parser.add_argument("--fail-on-warning", action="store_true", help="WARNING 也视为失败")
    args = parser.parse_args()

    if not PROJECT_FILE.exists():
        print("❌ 找不到 project.godot")
        return 1
    if not ALLOWLIST_FILE.exists():
        print("❌ 找不到 deps.allowlist.json")
        return 1

    try:
        allowlist = json.loads(ALLOWLIST_FILE.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        print(f"❌ deps.allowlist.json 解析失败: {e}")
        return 1

    allowed = set(allowlist.get("allowed_autoloads", []))
    registered = parse_autoloads(PROJECT_FILE)

    errors = 0
    warnings = 0

    unauthorized = sorted(registered - allowed)
    for name in unauthorized:
        print(f"❌ autoload [{name}] 未在 deps.allowlist.json 授权")
        errors += 1

    stale = sorted(allowed - registered)
    for name in stale:
        print(f"⚠️  allowlist 中的 [{name}] 并非当前 autoload（漂移，请清理）")
        warnings += 1

    print(f"\n📊 依赖检查完成: {errors} 个错误, {warnings} 个警告")
    print(f"   project.godot autoload: {sorted(registered)}")

    if errors > 0:
        print("❌ 依赖检查失败")
        return 1
    if warnings > 0 and args.fail_on_warning:
        print("⚠️  存在警告，且配置为警告即失败")
        return 1
    print("✅ 依赖检查通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
