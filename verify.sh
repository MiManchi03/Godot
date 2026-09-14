#!/usr/bin/env bash
# verify.sh —— 一键校验入口
# 用法:
#   bash verify.sh                 默认只查「上次提交」的新增行（避免历史遗留阻断）
#   bash verify.sh --base <ref>    指定提交区间起点（CI 用，如 github.event.before）
#   bash verify.sh --full          对全仓库校验（术语/架构，可能因历史遗留报错）
# 追溯: 审计 A5（无一键校验入口）；红队演练 D2/D3（逻辑/边界无测试）
set -u
cd "$(dirname "$0")"

PY="${PYTHON:-python}"

BASE=""
FULL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --full) FULL=1; shift ;;
    --base) BASE="${2:-}"; shift 2 ;;
    *) echo "未知参数: $1"; exit 2 ;;
  esac
done

if [ "$FULL" -eq 0 ] && [ -z "$BASE" ]; then
  if git rev-parse --verify -q HEAD~1 >/dev/null 2>&1; then
    BASE="HEAD~1"
  fi
fi

FAIL=0
run() {
  local name="$1"; shift
  local start; start=$(date +%s)
  echo "───────── $name ─────────"
  if "$@"; then
    echo "✅ $name 通过 ($(( $(date +%s) - start ))s)"
  else
    echo "❌ $name 失败 ($(( $(date +%s) - start ))s)"
    FAIL=1
  fi
}

if [ "$FULL" -eq 1 ] || [ -z "$BASE" ]; then
  run "术语校验 (全仓库)" "$PY" tools/check_terminology.py --all
  run "架构校验 (全仓库)" "$PY" tools/check_architecture.py --all
else
  run "术语校验 ($BASE..HEAD)" "$PY" tools/check_terminology.py --base "$BASE"
  run "架构校验 ($BASE..HEAD)" "$PY" tools/check_architecture.py --base "$BASE"
fi

run "依赖白名单" "$PY" tools/check_dependencies.py
run "契约校验" "$PY" tools/validate_contracts.py
run "存档 schema" "$PY" tools/check_save_schema.py
run "静态分析 gdlint" "$PY" tools/run_gdlint.py

run "单元测试 GUT" "$PY" tools/run_tests.py
run "回归守护" "$PY" tools/regression_guard.py
run "性能基准" "$PY" tools/benchmark.py

echo "=================================="
if [ "$FAIL" -eq 0 ]; then
  echo "✅ verify.sh 全部通过"
  exit 0
fi
echo "❌ verify.sh 存在失败项"
exit 1
