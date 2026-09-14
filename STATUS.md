# STATUS.md — 活文档（当前状态）

> 会话开工先读：本文件 + `PITFALLS.md` + `HARNESS_PLAN.md`。
> 追溯：红队演练 D7（改代码不更新活文档，无机制发现）；审计 A9

## 当前 Phase
Phase 7（回归守护 + 性能基准）完成待验收

## 进行中
- 无（路线图全部完成）

## 阻塞
- 无

## 最近变更
- 2026-09-14 Phase 1：术语闸口复活 + Harness 入库
- 2026-09-14 Phase 2：架构 / 依赖拦截上线
- 2026-09-14 Phase 3：文档与纪律三重闸
- 2026-09-14 Phase 4：GUT 单测 + gdlint + verify.sh 上线；修正 VillageService 非法语法
- 2026-09-14 Phase 5：save schema 守卫 + 契约校验；清理 14 处契约腐烂
- 2026-09-14 Phase 6：VISION + 6 份子系统 spec；agent 去重（164→78 行）；术语表修 5 处子串冲突
- 2026-09-14 Phase 7：回归守护 + 性能基准；GUT 产出 JUnit XML 作为测试产物

## 关键入口
- 一键：`bash verify.sh`（术语 / 架构 / 依赖 / 契约 / save schema / gdlint / 单测）
- 单测：`python tools/run_tests.py`（GUT 无头，17 项）
- 静态分析：`python tools/run_gdlint.py`
- 契约：`python tools/validate_contracts.py`
- 回归守护：`python tools/regression_guard.py`（基线 `.harness/test-baseline.json`）
- 性能基准：`python tools/benchmark.py`（基线 `.harness/bench-baseline.json`）
- save schema：`python tools/check_save_schema.py`
- 引擎：`GODOT_PATH` 或默认 4.6.1 安装路径

## 维护规则
- 改 `scripts/**` 的 `.gd` 后，本文件或 `PITFALLS.md` 必须同批变更（`check_docs_fresh.py` 强制）
