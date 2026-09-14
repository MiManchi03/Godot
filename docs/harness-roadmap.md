# Harness 升级路线图

- **制定日期**: 2026-09-14
- **依据**: `docs/harness-audit-2026-09-14.md`（体检，成熟度 H1）+ `docs/harness-drill-2026-09-14.md`（红队演练，拦截率 0/7）
- **交付节奏**: 严格逐阶段——每阶段完成后停下等验收，未批准不动下一阶段

---

## 0. 硬性原则

1. **渐进演进，禁止推倒重建**：现有能用的部分保留，只补缺口、修致命伤。
2. **每阶段独立可用**：哪怕只做完阶段 1 就停工，体系也应比现在强。
3. **每阶段工作量 ≤ 一周业余时间可验收**。
4. **优先级**：未拦截漏洞（D1–D7）> 文档腐烂（D7/A9）> 测试覆盖缺口（D2/D3/A6）> 规则完善（A7/A10）> 锦上添花。
5. **AGENTS.md 去膨胀**：重构为目录式，细节下沉 `docs/`。

## 0.1 已确认执行决策

| 决策点 | 结论 |
|---|---|
| 产出顺序 | 先落盘审计报告 + 本路线图，再逐阶段施工 |
| 静态分析 | **gdtoolkit（提交时 lint，纯 pip，不依赖引擎）+ Godot `--headless`（无头测试）两者都要** |
| CI 托管 | **GitHub 私有仓库**（`harness.yml` 已按 GitHub Actions 写好） |
| 交付节奏 | **逐阶段，每阶段后停下验收** |

## 0.2 缺口编号索引

引用 `docs/harness-audit-2026-09-14.md` 的 A1–A14 与演练报告 D1–D7。

| 编号 | 缺口 |
|---|---|
| A1 | 术语检查崩溃（`cursor:` 拼写） |
| A2 | 术语表自相矛盾（`村民`） |
| A3 | Harness 未入库 + 无 remote |
| A4 | pre-commit / hook 未安装 |
| A5 | 无一键 `verify.sh` |
| A6 | `tests/` 空、无 GUT、Godot 不可运行 |
| A7 | 项目 `AGENTS.md` 缺失（悬空引用） |
| A8 | 契约腐烂 |
| A9 | 无 STATUS/PITFALLS/ADR/VISION、无范围纪律 |
| A10 | 无 spec 的裸奔模块 |
| A11 | `git *` 放行破坏性命令 |
| A12 | Skills 全 markdown，无实现 |
| A13 | 提交无 spec/task 追溯 |
| A14 | SPEC AC 无测试映射 |
| D1–D7 | 演练 7 项违规，拦截率 0/7 |

> 因 D2/D3 的堵法本身就是测试、D7 本身就是文档，故按"要建哪一层"归并，避免重复建设。

---

## 阶段 1 — 地基入库 + 让唯一闸口活过来

**目标**：A1、A2、A3、A4、A7。这是所有 D 项能被拦截的前提（演练证明：无 hook 运行，一切拦截为空谈）。

**改动清单**

| 文件 | 动作 | 追溯 |
|---|---|---|
| `.opencode/terminology/TERMINOLOGY.yaml` | `cursor:` → `canonical:`；解决 `村民` 冲突 | 演练 Gate A 实测崩溃；A2 |
| `.opencode/routing/zh-en-map.yaml` | 由 registry 重新同步生成 | A1 修复后的一致性 |
| `AGENTS.md`（新建，目录式 ≤40 行） | 只做索引，细节指向 `docs/` | `opencode.json:8` 悬空引用（A7） |
| `.pre-commit-config.yaml` | 暂不接入 `godot-static-analyzer`（留待阶段 2/4） | 避免"配了但跑不了"的假象 |
| git 操作 | `git add` 全部 Harness 文件并提交；`pre-commit install`；`git remote add origin <GitHub 私有仓库>` | A3/A4 |
| `docs/harness-audit-2026-09-14.md` | 已补写 | 本路线图基准 |

**验收标准**
1. `python tools/check_terminology.py --all` 不再抛 `TypeError`（对照演练 Gate A 输出）。
2. 在隔离分支提交一个含禁用词的文件 → 被 hook 拦截（新增小演练 D0）。
3. `git remote -v` 非空；`git ls-files | grep -E 'HARNESS|tools/|opencode'` 非空。
4. 明确记录：重跑 D7 仍不拦截（属阶段 3）。

**对日常流程的影响**：提交开始走 hook，首次需 `pre-commit run --all-files` 清理存量；不可再用 `--no-verify`。

**你的验收耗时**：约 1–2 小时。

---

## 阶段 2 — 架构与依赖拦截（关掉 D1）

**目标**：D1；附带 A11、A12（部分）。

**改动清单**

| 文件 | 动作 | 追溯 |
|---|---|---|
| `tools/check_architecture.py`（新建） | 检测 `_process` 内分配、跨模块私有成员访问 | 演练 D1 |
| `tools/check_dependencies.py`（新建） | `project.godot` autoload 与 `deps.allowlist.json` 一致性校验 | A6/A12 drift |
| `deps.allowlist.json` | 补 `VillageService`；移除并非 autoload 的 `WorldManager`（对齐 `project.godot:19-26`） | A6 drift |
| `.pre-commit-config.yaml` | 接入上述两脚本 | D1 拦截层 |
| `opencode.json` | `"git *"` 收窄：`push/reset --hard/clean/rebase/checkout -f` 改 `ask` | A11 |

**验收标准**
1. 重跑 D1 注入 → `check_architecture.py` 报告/阻断。
2. `check_dependencies.py` 对当前 allowlist drift 报错。
3. 执行 `git reset --hard` 触发人工确认。

**对日常流程的影响**：改 autoload 必须同步 allowlist；架构违规提交会被拦。

**你的验收耗时**：约 2–3 小时。

---

## 阶段 3 — 文档与纪律三重闸（关掉 D7 / D4 / D5）

**目标**：D7、D4、D5；A9、A13。

**改动清单**

| 文件 | 动作 | 追溯 |
|---|---|---|
| `STATUS.md`（新建） | 活文档：当前目标/进行中/阻塞 | D7（对照目标缺失） |
| `PITFALLS.md`（新建） | 记录本次演练 7 项 + 历史教训 | A9 |
| `tools/check_scope.py`（新建） | 比对"任务声明的允许文件集"与 `git diff --name-only` | 演练 D4 |
| `tools/check_docs_fresh.py`（新建） | 代码变更未同步 STATUS/PITFALLS 则阻断 | 演练 D7 |
| `.opencode/agent/godot-engineer.md` | 增"完成前必须粘贴真实命令输出"硬条款 | 演练 D5 |
| `.github/workflows/plan-sync.yml` | `echo` 警告改为 `exit 1` | D7 |

**验收标准**
1. 重跑 D4 → 越界文件被 `check_scope.py` 拦。
2. 重跑 D5 → 无测试产物的"测试通过"声明被拒。
3. 重跑 D7 → 代码变更未更新 STATUS 被拦。

**对日常流程的影响**：开工先声明将修改的文件；收尾贴输出；核心行为变更要记 STATUS/PITFALLS。

**你的验收耗时**：约 3–4 小时。

---

## 阶段 4 — 测试地基（关掉 D2 / D3）

**目标**：D2、D3；A5、A6、A14。

**改动清单**

| 文件 | 动作 | 追溯 |
|---|---|---|
| gdtoolkit（pip 安装 `gdtoolkit`） | 提交时 `gdscript-lint`，不依赖引擎 | 已确认决策 |
| `Godot.exe` 路径固化为 `GODOT_PATH` | 无头测试可运行 | A6 |
| `addons/gut`（接入） | 测试框架 | A6 |
| `tests/unit/test_resource_spawner.gd`（新建） | 断言 SPEC 3.3 概率分布 | 演练 D2 |
| `tests/unit/test_biome_generator.gd`、`test_world_state.gd`（新建） | 纯逻辑层单测 | A6/A14 |
| `tests/unit/test_boundary.gd`（新建） | 空/负/超大输入用例 | 演练 D3 |
| `verify.sh`（新建） | 一键串联 术语+架构+依赖+静态+单测 | A5 |
| `.pre-commit-config.yaml` + `harness.yml` | 接入 `verify.sh` | A5 |

**验收标准**
1. 重跑 D2 → 单测失败被拦。
2. 重跑 D3 → 边界用例失败被拦。
3. `bash verify.sh` 一条命令跑通并记录耗时。

**对日常流程的影响**：提交前/后跑 `bash verify.sh`；新逻辑必须带测试。

**你的验收耗时**：约 3–5 小时。

---

## 阶段 5 — 存档契约与迁移守护（关掉 D6）

**目标**：D6；A8、A12。

**改动清单**

| 文件 | 动作 | 追溯 |
|---|---|---|
| `tools/check_save_schema.py`（新建） | 读写键集合一致性；`DATA_VERSION` 变更必须伴随迁移函数 | 演练 D6 |
| `.opencode/contracts/scripts/world/world_state.contract.json`（新建） | WorldState 公开接口 | A8 |
| `world_manager.contract.json` | 移除已删除的 4 个方法 | A8 |
| `tools/validate_contracts.py`（新建） | 实现 CI 里被注释掉的占位校验 | A12 |

**验收标准**
1. 重跑 D6 → 被 `check_save_schema.py` 拦。
2. 重跑"契约腐烂" → `validate_contracts.py` 报错。

**对日常流程的影响**：改存档结构必须升版本 + 写迁移。

**你的验收耗时**：约 2–3 小时。

---

## 阶段 6 — 规则完善与 AGENTS.md 去膨胀

**目标**：A7（收敛）、A9（VISION/ADR）、A10。

**改动清单**

| 文件 | 动作 | 追溯 |
|---|---|---|
| `docs/VISION.md`（新建） | 所有 spec 的上游依据 | A10 |
| `docs/specs/*.md`（新建） | 拆分道路/建筑/村民/背包/设置为模块 spec | A10 |
| `AGENTS.md` | 保持目录式，细节下沉 `docs/` | A7 + 原则 5 |
| `.opencode/agent/godot-engineer.md` | 删除重复映射行（151 → ~60 行） | 审计 M1（映射重复 3 次） |

**验收标准**：每个已实现模块有 spec；`AGENTS.md` 为纯索引；agent 文件无重复行。

**你的验收耗时**：约 3–4 小时。

---

## 阶段 7（可选）— 回归与性能基线

**目标**：锦上添花。回归守护（改前基线 / 改后对比）、性能基准可复跑。建议前六阶段稳定后按需启动。

**你的验收耗时**：约 3–4 小时。

---

## 总览表

| 阶段 | 解决什么 | 验收方式 | 你的验收耗时 |
|---|---|---|---|
| 1 地基+术语闸口 | A1,A2,A3,A4,A7 | 术语检查不再崩；禁用词提交被拦；remote 建立 | 1–2 h |
| 2 架构+依赖 | D1,A11,A12(部分) | 重跑 D1 被拦；依赖 drift 报错；`git reset --hard` 需确认 | 2–3 h |
| 3 文档+纪律 | D7,D4,D5,A9,A13 | 重跑 D4/D5/D7 均被拦 | 3–4 h |
| 4 测试地基 | D2,D3,A5,A6,A14 | 重跑 D2/D3 被拦；`verify.sh` 跑通 | 3–5 h |
| 5 存档契约 | D6,A8,A12 | 重跑 D6 被拦；契约腐烂报错 | 2–3 h |
| 6 规则+去膨胀 | A7,A9,A10 | 模块 spec 齐全；AGENTS.md 目录式 | 3–4 h |
| 7 回归/性能（可选） | 锦上添花 | 基线对比可定位新失败 | 3–4 h |

---

## 施工前置输入（阶段 1/4 需要）

1. `Godot.exe` 实际路径 → 固化为 `GODOT_PATH`；若暂缺，阶段 4 先用 gdtoolkit 兜底。
2. GitHub 私有仓库地址 → 阶段 1 `git remote add origin`。

## 纪律

- 未批准的阶段不许动手。
- 每阶段完成后停下，等验收。
- 每阶段只补缺口，不顺手重构无关代码。
