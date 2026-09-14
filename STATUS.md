# STATUS.md — 活文档（当前状态）

> 会话开工先读：本文件 + `PITFALLS.md` + `HARNESS_PLAN.md`。
> 追溯：红队演练 D7（改代码不更新活文档，无机制发现）；审计 A9

## 当前 Phase
Phase 4（测试地基）完成待验收

## 进行中
- 无（等待 Phase 5 批准）

## 阻塞
- 无

## 最近变更
- 2026-09-14 Phase 1：术语闸口复活 + Harness 入库
- 2026-09-14 Phase 2：架构 / 依赖拦截上线
- 2026-09-14 Phase 3：文档与纪律三重闸
- 2026-09-14 Phase 4：GUT 单测 + gdlint + verify.sh 上线；修正 VillageService 非法语法

## 关键入口
- 一键：`bash verify.sh`（术语 / 架构 / 依赖 / gdlint / 单测）
- 单测：`python tools/run_tests.py`（GUT 无头，17 项）
- 静态分析：`python tools/run_gdlint.py`
- 引擎：`GODOT_PATH` 或默认 4.6.1 安装路径

## 维护规则
- 改 `scripts/**` 的 `.gd` 后，本文件或 `PITFALLS.md` 必须同批变更（`check_docs_fresh.py` 强制）
