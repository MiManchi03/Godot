#!/usr/bin/env bash
# scripts/harness_health.sh
# Harness 健康度体检 —— 一键输出 7 项量化指标，并追加到 docs/harness-health.log
# 追溯：Harness 路线图收尾（可量化健康度 / 持续进化机制）
#
# 每月 1 号自动运行：
#   crontab:          0 3 1 * * cd /path/to/my-world && bash scripts/harness_health.sh
#   Windows 任务计划： 触发器「每月 1 日」，操作:
#                     bash -lc "cd /d/Godot/Project/my-world && bash scripts/harness_health.sh"
#   或纳入每周维护流程手动执行。
set -u
cd "$(dirname "$0")/.."

PY="${PYTHON:-python}"
LOG="docs/harness-health.log"
TS="$(date '+%Y-%m-%d %H:%M:%S')"

# ── [1] 体系是否还活着：运行 verify.sh ──────────────────────────
V_START=$(date +%s)
if bash verify.sh >/tmp/harness_verify.out 2>&1; then V_STATUS="PASS"; else V_STATUS="FAIL"; fi
V_DUR=$(( $(date +%s) - V_START ))

# ── [2]-[7] 由内嵌 Python 计算 ─────────────────────────────────
METRICS="$("$PY" - "$V_STATUS" "$V_DUR" <<'PYEOF'
import sys, re, time, subprocess
from pathlib import Path

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except Exception:
        pass

v_status = sys.argv[1] if len(sys.argv) > 1 else "?"
v_dur = sys.argv[2] if len(sys.argv) > 2 else "?"


def git(args):
    r = subprocess.run(["git", *args], capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    return r.stdout or ""


L = []
L.append("[1] 体系存活 (verify.sh)")
L.append(f"    状态: {v_status}    耗时: {v_dur}s")

# [2] 测试
test_files = list(Path("tests/unit").glob("*.gd")) if Path("tests/unit").exists() else []
total = sum(len(re.findall(r'^func test_', p.read_text(encoding="utf-8"), re.M)) for p in test_files)
added = git(["log", "--since=1 month ago", "-p", "--", "tests/"])
new = sum(1 for ln in added.splitlines() if re.match(r'^\+func test_', ln))
junit = Path("test-results/junit.xml")
skip = junit.read_text(encoding="utf-8").count("<skipped") if junit.exists() else 0
L.append("[2] 测试规模")
L.append(f"    总数: {total}    本月新增: {new}    跳过: {skip}")

# [3] PITFALLS 进化速度
pf = Path("PITFALLS.md")
text = pf.read_text(encoding="utf-8") if pf.exists() else ""
sections = re.split(r'^### ', text, flags=re.M)[1:]
tot_e = len(sections)
auto_e = sum(1 for s in sections if "[自动]" in s)
new_e = sum(1 for ln in git(["log", "--since=1 month ago", "-p", "--", "PITFALLS.md"]).splitlines()
            if ln.startswith("+### "))
ratio = (auto_e * 100 // tot_e) if tot_e else 0
L.append("[3] PITFALLS 进化速度")
L.append(f"    本月新增条目: {new_e}    已固化自动拦截: {auto_e}/{tot_e} ({ratio}%)")

# [4] 重复错误模式（>1 即红色警报）
SIGS = {
    "GBK 编码崩溃": r"GBK",
    "契约失修/失配": r"契约",
    "pre-commit 丢改动": r"丢改动",
    "文件被清空": r"清空",
    "非法语法": r"非法语法",
    "术语子串冲突": r"子串",
}
dups = [(n, sum(1 for s in sections if re.search(p, s))) for n, p in SIGS.items()]
dups = [(n, c) for n, c in dups if c > 1]
L.append("[4] 重复错误模式")
if dups:
    for n, c in dups:
        L.append(f"    🔴 {n}: {c} 次")
else:
    L.append("    ✅ 无重复模式")

# [5] 活文档新鲜度
def days_since(path):
    out = git(["log", "-1", "--format=%ct", "--", path]).strip()
    return int((time.time() - int(out)) / 86400) if out else -1

last = git(["log", "-1", "--format=%ct"]).strip()
L.append("[5] 活文档新鲜度")
L.append(f"    STATUS.md 距上次更新: {days_since('STATUS.md')} 天")
L.append(f"    距最后一次 commit: {int((time.time() - int(last)) / 86400) if last else -1} 天")

# [6] spec 覆盖（裸奔模块趋势）
MODULES = {
    "build": "docs/specs/building-system.md",
    "effects": "",
    "npc": "docs/specs/villager-system.md",
    "player": "SPEC.md",
    "resources": "SPEC.md",
    "system": "docs/specs/cursor-system.md",
    "ui": "docs/specs/inventory-system.md",
    "village": "docs/specs/villager-system.md",
    "world": "SPEC.md",
    "game_settings.gd": "docs/specs/settings-system.md",
}
covered = [m for m, s in MODULES.items() if s and Path(s).exists()]
bare = [m for m, s in MODULES.items() if not (s and Path(s).exists())]
L.append("[6] Spec 覆盖")
L.append(f"    有 spec: {len(covered)}/{len(MODULES)}    裸奔: {len(bare)} ({', '.join(bare) if bare else '无'})")

# [7] 规则膨胀监控
def nlines(path):
    p = Path(path)
    return len(p.read_text(encoding="utf-8").splitlines()) if p.exists() else 0


def flag(n, threshold):
    return "🔴 超阈值" if n > threshold else "✅"


agents = nlines("AGENTS.md")
agent_md = nlines(".opencode/agent/godot-engineer.md")
L.append("[7] 规则膨胀监控")
L.append(f"    AGENTS.md: {agents} 行 (阈值 150) {flag(agents, 150)}")
L.append(f"    agent 提示词: {agent_md} 行 (阈值 120) {flag(agent_md, 120)}")

print("\n".join(L))
PYEOF
)"

REPORT="$(printf '================================================================\nHarness Health Report — %s\n================================================================\n%s\n' "$TS" "$METRICS")"
mkdir -p docs
printf '%s\n' "$REPORT" >> "$LOG"
printf '%s\n' "$REPORT"
