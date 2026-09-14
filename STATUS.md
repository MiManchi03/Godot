# STATUS.md — 活文档（当前状态）

> 会话开工先读：本文件 + `PITFALLS.md` + `HARNESS_PLAN.md`。
> 追溯：红队演练 D7（改代码不更新活文档，无机制发现）；审计 A9

## 当前 Phase
Phase 3（文档与纪律三重闸）进行中

## 进行中
- [ ] 范围守卫 `tools/check_scope.py`
- [ ] 活文档新鲜度 `tools/check_docs_fresh.py`
- [ ] 测试声明取证 `tools/check_claims.py`

## 阻塞
- 无

## 最近变更
- 2026-09-14 Phase 1：术语闸口复活 + Harness 入库
- 2026-09-14 Phase 2：架构 / 依赖拦截上线
- 2026-09-14 Phase 3：文档与纪律三重闸（进行中）

## 维护规则
- 改 `scripts/**` 的 `.gd` 后，本文件或 `PITFALLS.md` 必须同批变更（`check_docs_fresh.py` 强制）
