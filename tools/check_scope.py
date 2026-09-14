#!/usr/bin/env python3
# tools/check_scope.py
# 变更范围守卫：本次提交的文件必须落在任务声明的白名单内
# 声明文件: .harness/scope.txt（每行一个 glob；缺失或全为注释 = 关闭本守卫）
# 追溯：红队演练 D4（"顺手"修改无关文件，无任何机制发现）

import sys
import fnmatch
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

SCOPE_FILE = Path(".harness/scope.txt")
ALLOW_ALL = ("*", "**", "**/*")


def load_scope():
    if not SCOPE_FILE.exists():
        return None
    patterns = []
    for line in SCOPE_FILE.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        patterns.append(line)
    return patterns or None


def main():
    scope = load_scope()
    if scope is None:
        print(f"ℹ️  未声明任务范围（{SCOPE_FILE} 缺失或为空），跳过范围守卫")
        return 0

    if any(p in ALLOW_ALL for p in scope):
        print("ℹ️  范围声明为全放开，跳过范围守卫")
        return 0

    staged = get_staged_files()
    if not staged:
        print("ℹ️  无暂存文件")
        return 0

    out_of_scope = [
        f for f in staged
        if not any(fnmatch.fnmatch(f, pat) for pat in scope)
        and f != str(SCOPE_FILE)
    ]

    print(f"🔒 范围守卫：声明 {len(scope)} 条 glob，暂存 {len(staged)} 个文件")
    if out_of_scope:
        print("❌ 以下文件超出任务声明范围（.harness/scope.txt）：")
        for f in out_of_scope:
            print(f"   - {f}")
        print("   如确需修改，请先更新 .harness/scope.txt 再提交（防范围蔓延）")
        return 1

    print("✅ 所有变更都在声明范围内")
    return 0


if __name__ == "__main__":
    sys.exit(main())
