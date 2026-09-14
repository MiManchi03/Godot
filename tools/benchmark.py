#!/usr/bin/env python3
# tools/benchmark.py
# 性能基准：运行 tests/bench/bench_core.gd 并与基线对比
# 追溯：审计（无性能基准）；Phase 7
# 用法：
#   python tools/benchmark.py            # 与基线对比，超阈值退出码 1
#   python tools/benchmark.py --update   # 用当前结果刷新基线

import os
import re
import sys
import json
import shutil
import argparse
import subprocess
from pathlib import Path
from typing import Dict

for _stream in (sys.stdout, sys.stderr):
    _reconf = getattr(_stream, "reconfigure", None)
    if _reconf is not None:
        try:
            _reconf(encoding="utf-8")
        except Exception:
            pass

DEFAULT_GODOT = r"D:\Godot\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe"
BASELINE = Path(".harness/bench-baseline.json")
BENCH_SCRIPT = "res://tests/bench/bench_core.gd"
TOLERANCE = 1.5  # 超过基线 150% 视为退化

BENCH_RE = re.compile(r'BENCH\s+(\w+)=([\d.]+)')


def find_godot() -> str:
    env = os.environ.get("GODOT_PATH")
    if env and Path(env).exists():
        return env
    if Path(DEFAULT_GODOT).exists():
        return DEFAULT_GODOT
    return shutil.which("godot") or shutil.which("godot4") or ""


def run_bench(godot: str) -> Dict[str, float]:
    cmd = [godot, "--headless", "--path", ".", "-s", BENCH_SCRIPT]
    result = subprocess.run(cmd, capture_output=True, text=True,
                            encoding="utf-8", errors="replace")
    metrics = {}
    for m in BENCH_RE.finditer(result.stdout or ""):
        metrics[m.group(1)] = float(m.group(2))
    return metrics


def main() -> int:
    parser = argparse.ArgumentParser(description="性能基准")
    parser.add_argument("--update", action="store_true", help="用当前结果刷新基线")
    args = parser.parse_args()

    godot = find_godot()
    if not godot:
        print("❌ 未找到 Godot 可执行文件；请设置 GODOT_PATH")
        return 1

    metrics = run_bench(godot)
    if not metrics:
        print("❌ 未获得任何基准结果（脚本可能失败）")
        return 1

    print("📊 当前基准（毫秒）:")
    for k, v in sorted(metrics.items()):
        print(f"   {k} = {v:.2f}")

    if args.update:
        BASELINE.parent.mkdir(parents=True, exist_ok=True)
        BASELINE.write_text(json.dumps(metrics, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
                            encoding="utf-8")
        print(f"✅ 基线已刷新 -> {BASELINE}")
        return 0

    if not BASELINE.exists():
        print(f"ℹ️  无基线（{BASELINE}）；请先运行 --update。当前视为通过。")
        return 0

    baseline = json.loads(BASELINE.read_text(encoding="utf-8"))
    regressions = []
    for k, v in metrics.items():
        base = baseline.get(k)
        if base is None:
            print(f"ℹ️  新指标 {k}（基线无记录）")
            continue
        if v > base * TOLERANCE:
            regressions.append((k, base, v))

    if regressions:
        print(f"❌ 性能退化（阈值 {TOLERANCE:g}x）:")
        for k, base, v in regressions:
            print(f"   - {k}: 基线 {base:.2f} -> 当前 {v:.2f}")
        return 1
    print("✅ 无性能退化")
    return 0


if __name__ == "__main__":
    sys.exit(main())
