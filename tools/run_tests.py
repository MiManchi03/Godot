#!/usr/bin/env python3
# tools/run_tests.py
# 无头单元测试驱动：定位 Godot 可执行文件并运行 GUT
# 追溯：审计 A6（Godot 不可运行、无测试框架）；红队演练 D2/D3
# 用法：python tools/run_tests.py
#   Godot 位置可用环境变量 GODOT_PATH 覆盖

import os
import sys
import shutil
import subprocess
from pathlib import Path

for _stream in (sys.stdout, sys.stderr):
    _reconf = getattr(_stream, "reconfigure", None)
    if _reconf is not None:
        try:
            _reconf(encoding="utf-8")
        except Exception:
            pass

DEFAULT_GODOT = r"D:\Godot\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe"


def find_godot() -> str:
    env = os.environ.get("GODOT_PATH")
    if env and Path(env).exists():
        return env
    if Path(DEFAULT_GODOT).exists():
        return DEFAULT_GODOT
    which = shutil.which("godot") or shutil.which("godot4")
    return which or ""


def main() -> int:
    godot = find_godot()
    if not godot:
        print("❌ 未找到 Godot 可执行文件；请设置 GODOT_PATH 环境变量")
        return 1

    cmd = [
        godot, "--headless", "--path", ".",
        "-s", "addons/gut/gut_cmdln.gd",
        "-gdir=res://tests/unit", "-gexit",
    ]
    print(f"🧪 运行 GUT：{godot}")
    result = subprocess.run(cmd, text=True, encoding="utf-8", errors="replace")
    if result.returncode != 0:
        print(f"❌ 单元测试失败（exit={result.returncode}）")
        return 1
    print("✅ 单元测试通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
