#!/usr/bin/env python3
# tools/regression_guard.py
# 回归守护：把当前 GUT 结果与基线对比，定位「原本通过、现在失败」的用例
# 追溯：审计（无回归守护）；Phase 7
# 用法：
#   python tools/regression_guard.py            # 对比基线，发现新失败则退出码 1
#   python tools/regression_guard.py --update   # 用当前结果刷新基线

import sys
import json
import argparse
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Dict

for _stream in (sys.stdout, sys.stderr):
    _reconf = getattr(_stream, "reconfigure", None)
    if _reconf is not None:
        try:
            _reconf(encoding="utf-8")
        except Exception:
            pass

DEFAULT_JUNIT = Path("test-results/junit.xml")
BASELINE = Path(".harness/test-baseline.json")


def parse_junit(path: Path) -> Dict[str, str]:
    """返回 {test_id: 'pass'|'fail'}"""
    tree = ET.parse(path)
    root = tree.getroot()
    results: Dict[str, str] = {}
    for tc in root.iter("testcase"):
        classname = tc.get("classname", "")
        name = tc.get("name", "")
        test_id = f"{classname}::{name}" if classname else name
        failed = any(child.tag in ("failure", "error") for child in tc)
        skipped = any(child.tag == "skipped" for child in tc)
        results[test_id] = "skip" if skipped else ("fail" if failed else "pass")
    return results


def main() -> int:
    parser = argparse.ArgumentParser(description="回归守护")
    parser.add_argument("--junit", default=str(DEFAULT_JUNIT), help="JUnit XML 路径")
    parser.add_argument("--update", action="store_true", help="用当前结果刷新基线")
    parser.add_argument("--fail-on-new", action="store_true", default=True,
                        help="发现新失败即退出码 1（默认开启）")
    args = parser.parse_args()

    junit = Path(args.junit)
    if not junit.exists():
        print(f"❌ 找不到 {junit}；请先运行 python tools/run_tests.py")
        return 1

    current = parse_junit(junit)

    if args.update:
        BASELINE.parent.mkdir(parents=True, exist_ok=True)
        BASELINE.write_text(json.dumps(current, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
                            encoding="utf-8")
        print(f"✅ 基线已刷新：{len(current)} 条用例 -> {BASELINE}")
        return 0

    if not BASELINE.exists():
        print(f"ℹ️  无基线（{BASELINE}）；请先运行 --update 建立基线。当前视为通过。")
        return 0

    baseline = json.loads(BASELINE.read_text(encoding="utf-8"))

    new_failures = []
    removed = []
    for test_id, status in sorted(current.items()):
        base_status = baseline.get(test_id)
        if base_status == "pass" and status == "fail":
            new_failures.append(test_id)
        elif base_status is None:
            # 基线中不存在：新用例，不视为回归
            pass
    for test_id, base_status in sorted(baseline.items()):
        if test_id not in current:
            removed.append(test_id)

    print(f"📊 回归对比：当前 {len(current)} 条 / 基线 {len(baseline)} 条")

    if removed:
        print("⚠️  基线中存在但当前缺失的用例（可能被改名或移除）：")
        for t in removed:
            print(f"   - {t}")
    if new_failures:
        print("❌ 新失败（原本通过、现在失败）：")
        for t in new_failures:
            print(f"   - {t}")
        if args.fail_on_new:
            return 1
    else:
        print("✅ 无新失败")
    return 0


if __name__ == "__main__":
    sys.exit(main())
