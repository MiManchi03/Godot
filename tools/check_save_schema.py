#!/usr/bin/env python3
# tools/check_save_schema.py
# 存档 schema 守卫
#   R1 读写键对称：同一存档文件的 _save_X 写入键集合 必须与 _load_X 读取键集合一致
#   R2 版本迁移：DATA_VERSION 变化时，必须新增迁移函数（名字含 migrat）
# 追溯：红队演练 D6（改写出键而不改读取端、且不升版本/不写迁移，未被拦截）

import sys
import re
import subprocess
from pathlib import Path
from typing import Dict, Set

for _stream in (sys.stdout, sys.stderr):
    _reconf = getattr(_stream, "reconfigure", None)
    if _reconf is not None:
        try:
            _reconf(encoding="utf-8")
        except Exception:
            pass

TARGETS = ["scripts/world/world_state.gd"]
# 元数据键：读写不对称属正常
IGNORED_KEYS = {"version", "chunk", "coord", "dirty"}

WRITER_RE = re.compile(r'"([^"]+)"\s*:')            # dict 字面量键  "k":
READER_RE = re.compile(r'\.get\(\s*"([^"]+)"')      # dict.get("k")
VERSION_RE = re.compile(r'const\s+DATA_VERSION\s*:=\s*(\d+)')


def split_functions(text: str) -> Dict[str, str]:
    funcs: Dict[str, str] = {}
    cur = None
    body = []
    for line in text.split('\n'):
        m = re.match(r'^func\s+([A-Za-z_]\w*)\s*\(', line)
        if m:
            if cur is not None:
                funcs[cur] = '\n'.join(body)
            cur = m.group(1)
            body = []
        elif cur is not None:
            body.append(line)
    if cur is not None:
        funcs[cur] = '\n'.join(body)
    return funcs


def _head_text(rel: str) -> str:
    try:
        r = subprocess.run(
            ["git", "show", f"HEAD:{rel}"],
            capture_output=True, text=True, encoding="utf-8", errors="replace"
        )
        return r.stdout if r.returncode == 0 else ""
    except Exception:
        return ""


def check_file(rel: str) -> int:
    path = Path(rel)
    if not path.exists():
        print(f"❌ 目标脚本不存在: {rel}")
        return 1

    text = path.read_text(encoding="utf-8")
    funcs = split_functions(text)
    errors = 0

    # R1 读写键对称
    for name, body in funcs.items():
        if not name.startswith("_save_"):
            continue
        suffix = name[len("_save_"):]
        load_name = "_load_" + suffix
        if load_name not in funcs:
            continue
        writer = set(WRITER_RE.findall(body)) - IGNORED_KEYS
        reader = set(READER_RE.findall(funcs[load_name])) - IGNORED_KEYS
        if not writer:
            continue
        only_writer = sorted(writer - reader)
        only_reader = sorted(reader - writer)
        for k in only_writer:
            print(f"❌ {rel}: [{name}] 写出键 \"{k}\" 在 [{load_name}] 读取端缺失（schema 漂移）")
            errors += 1
        for k in only_reader:
            print(f"❌ {rel}: {load_name} 读取键 \"{k}\" 在 {name} 写出端缺失（schema 漂移）")
            errors += 1

    # R2 版本迁移
    head = _head_text(rel)
    if head:
        v_now = VERSION_RE.search(text)
        v_head = VERSION_RE.search(head)
        if v_now and v_head and v_now.group(1) != v_head.group(1):
            new_funcs = set(split_functions(text)) - set(split_functions(head))
            if not any("migrat" in f.lower() for f in new_funcs):
                print(f"❌ {rel}: DATA_VERSION {v_head.group(1)} -> {v_now.group(1)}，但没有新增迁移函数（名字含 migrat）")
                errors += 1

    return errors


def main() -> int:
    total = 0
    for rel in TARGETS:
        total += check_file(rel)
    print(f"\n📊 存档 schema 检查完成: {total} 个错误")
    if total > 0:
        print("❌ 存档 schema 检查失败")
        return 1
    print("✅ 存档 schema 检查通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
