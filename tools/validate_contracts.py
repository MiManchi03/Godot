#!/usr/bin/env python3
# tools/validate_contracts.py
# 契约校验：核对 .opencode/contracts/**/*.contract.json 声明的接口是否仍存在于脚本
# 追溯：审计 A8（契约腐烂：world_manager.contract.json 仍列已删除的 4 个方法）；审计 A12（原实现缺失）

import sys
import json
import re
from pathlib import Path

for _stream in (sys.stdout, sys.stderr):
    _reconf = getattr(_stream, "reconfigure", None)
    if _reconf is not None:
        try:
            _reconf(encoding="utf-8")
        except Exception:
            pass

CONTRACTS_ROOT = Path(".opencode/contracts")


def contract_to_script(contract_path: Path) -> Path:
    rel = contract_path.relative_to(CONTRACTS_ROOT)
    rel_str = rel.as_posix().replace(".contract.json", ".gd")
    return Path(rel_str)


def _has_method(text: str, name: str) -> bool:
    return re.search(r'^func\s+' + re.escape(name) + r'\s*\(', text, re.M) is not None


def _has_signal(text: str, name: str) -> bool:
    return re.search(r'^signal\s+' + re.escape(name) + r'\b', text, re.M) is not None


def _has_const(text: str, name: str) -> bool:
    return re.search(r'^const\s+' + re.escape(name) + r'\b', text, re.M) is not None


def _has_var(text: str, name: str) -> bool:
    return re.search(r'^(@export[^\n]*\s+)?var\s+' + re.escape(name) + r'\b', text, re.M) is not None


def _has_enum(text: str, name: str) -> bool:
    return re.search(r'^enum\s+' + re.escape(name) + r'\b', text, re.M) is not None


def validate_contract(contract_path: Path) -> int:
    errors = 0
    try:
        data = json.loads(contract_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        print(f"❌ {contract_path}: JSON 解析失败: {e}")
        return 1

    script = contract_to_script(contract_path)
    if not script.exists():
        print(f"❌ {contract_path}: 目标脚本不存在 {script}")
        return 1
    text = script.read_text(encoding="utf-8")

    for m in data.get("methods", []):
        if not _has_method(text, m["name"]):
            print(f"❌ {script}: 契约声明的方法 [{m['name']}] 已不存在")
            errors += 1
    for s in data.get("signals", []):
        if not _has_signal(text, s["name"]):
            print(f"❌ {script}: 契约声明的信号 [{s['name']}] 已不存在")
            errors += 1
    for c in data.get("constants", []):
        if not _has_const(text, c["name"]):
            print(f"❌ {script}: 契约声明的常量 [{c['name']}] 已不存在")
            errors += 1
    for e in data.get("exports", []):
        if not _has_var(text, e["name"]):
            print(f"❌ {script}: 契约声明的导出 [{e['name']}] 已不存在")
            errors += 1
    for en in data.get("enums", []):
        if not _has_enum(text, en["name"]):
            print(f"❌ {script}: 契约声明的枚举 [{en['name']}] 已不存在")
            errors += 1

    return errors


def main() -> int:
    if not CONTRACTS_ROOT.exists():
        print("ℹ️  无契约目录")
        return 0
    contracts = sorted(CONTRACTS_ROOT.rglob("*.contract.json"))
    if not contracts:
        print("ℹ️  无契约文件")
        return 0

    total = 0
    for c in contracts:
        total += validate_contract(c)

    print(f"\n📊 契约校验完成: {len(contracts)} 份契约, {total} 个不一致")
    if total > 0:
        print("❌ 契约校验失败")
        return 1
    print("✅ 契约校验通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
