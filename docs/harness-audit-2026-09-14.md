# Harness 体系体检报告

- **审计日期**: 2026-09-14
- **项目**: `D:\Godot\Project\my-world`
- **方式**: 只读 + 运行验证类命令，所有结论附证据（文件路径 / 真实命令输出 / git 记录）
- **基准**: Agent = Model + Harness，六大模块 + Spec 层
- **配套报告**: `docs/harness-drill-2026-09-14.md`（红队演练，拦截率 0/7）

---

## 0. 结论摘要

> 一套**文档形态完备、但自动化验证完全没跑起来**的 Harness。唯一的真闸口（术语检查）**每次调用必崩**；测试目录是空的；pre-commit 未装、Git hook 未装；CI 是纯 `echo` 占位且**仓库没有 remote、Harness 文件全部未入库**。

**总体成熟度：H1（有规则文档但无自动验证）**

模块评分：M1=1 · M2=1 · M3=2 · M4=0 · M5=0 · M6=1 · Spec=1

---

## 1. 逐模块评分（0=缺失，1=存在但形同虚设，2=可用但有缺口，3=完善）

### 模块1 规则与约束 — **1/3**

| 检查项 | 证据 | 判定 |
|---|---|---|
| 项目级 `AGENTS.md` | `Test-Path AGENTS.md` → **False**；但 `opencode.json:8` 的 `instructions` 引用了 `"AGENTS.md"` | ❌ 悬空引用 |
| 规则可机器判定 | 唯一可判定载体是术语表；`.opencode/agent/godot-engineer.md` 全是"必须调用/失败即回滚"等不可执行协议 | ❌ 空话条款占多数 |
| 规则膨胀 | `godot-engineer.md` 151 行，映射表中 `村民/群系/方块/生成` **重复出现 3 次**（行 43–52） | ⚠️ 冗余 |
| 修改范围纪律（禁顺手重构/禁超范围） | 全项目 grep 未发现 scope discipline 条款 | ❌ 缺失 |

> 全局 `C:\Users\梁骆富\.config\opencode\AGENTS.md`（SOP）存在，但属**用户级**、非项目宪法。

### 模块2 上下文与记忆 — **1/3**

- 活文档：`HARNESS_PLAN.md`(161 行) + `plan_village_service.md`(286 行)。**无** `STATUS.md` / `PITFALLS.md` / `ADR` / `VISION`（全部 `Test-Path` = False）。
- 开工仪式：`godot-engineer.md:56-64` 定义了"会话启动协议"，但调用 `skill("godot-plan-manager").read()`——**技能是纯 markdown，无任何可执行代码**（`skills/**` 下 0 个 `.py/.gd/.sh`），该调用无法发生。
- **文档腐烂（致命）**：`HARNESS_PLAN.md:76-79` 宣称 "Pre-commit + CI 流水线搭建 ✅ 已完成"；实测 `.git/hooks` 只有 `.sample`、`pre-commit` 未安装、无 remote、Harness 未入库 → **该状态为假**。git HEAD 停在 `2026-04-14`，30 个提交无一记录进 Plan。

### 模块3 工具与权限（沙箱）— **2/3**

`opencode.json:31-40` 配置了真实白/问名单：`git/python/godot/dotnet/timeout/head` allow，`*: ask`；`external_directory` 放行 `D:\Godot\**`、`D:\Skills\**`。

缺口：
- `"git *": "allow"` 连 `git push --force`、`git reset --hard`、`git clean -fdx` 都**无需确认**；配合 `plan_village_service.md:286` 明写的 `git reset --hard pre-village-service` = 随时可能不可逆毁工作区。
- `"edit": "allow"` 全局无限制，无"改宪法/改已批准 spec 需人工确认"闸口。

### 模块4 测试与验证 — **0/3**

- 无一键入口：`verify.sh` 不存在（全盘无 `.sh` / `Makefile` / `justfile`）。
- `tests/{unit,integration,headless}` 三目录**存在但为空（0 文件）**；无 GUT（`addons/` 不存在）。
- Godot 不可运行：PATH 无 `godot`；MCP 路径 `C:\Program Files\Godot\Godot.exe` → **ENOENT**。
- AC↔测试映射：`SPEC.md` 第 5 节 AC 全是未勾选 `[ ]`，**零测试覆盖**。
- 性能基准测试：无。

### 模块5 反馈闭环 — **0/3**

- 无 Git hook、无 pre-commit 安装 → 提交零拦截。
- 无 remote → `.github/workflows/*.yml` **永不运行**；且 8/9 个 job 是 `echo "would run here"` 占位（`harness.yml:32-169`）。
- **唯一真闸口已死**：`python tools/check_terminology.py --all --fail-on-warning` 实测崩溃：
  ```
  File "tools/terminology_registry.py", line 36, in load
      term = Term(**item)
  TypeError: Term.__init__() got an unexpected keyword argument 'cursor'
  ```
  根因：`TERMINOLOGY.yaml:122` 把 `canonical:` 写成 `cursor:`（destructible 条目）。`load()` 在 `__init__` 执行 → **任何调用都崩**，pre-commit 与 CI 的术语检查一起失效。
- 设计级矛盾：`npc.forbidden` 含 `"村民"`（行 12），而 `villager.aliases` 也含 `"村民"`（行 18）→ 即使修复崩溃，也**自相矛盾**（任何含"村民"的文件都会被报 ERROR）。
- 无"完成前必须贴真实输出"诚实条款。

### 模块6 观测与审计 — **1/3**

- 提交规范：有稳定习惯 `新增:/修复: <描述> | 下一步: <描述>`（30 条一致）。**但无 spec/task 编号**，无法定位"每个功能对应哪个 spec/任务"。
- `PITFALLS` 条目数 = **0**（文件不存在），固化为自动拦截 = 0。

### Spec 层 — **1/3**

- 单一 `SPEC.md`(170 行)，覆盖：角色/地形/资源/村庄。**无 spec 的裸奔模块**：道路系统（`road_network/road_renderer`）、玩家建筑（`player_buildings`）、村民 AI/任务、背包（`inventory_*`）、设置（`game_settings`）、光标（`cursor_manager`）、可破坏物（`destructible`）。
- 四要素：What 有、AC 有（不可测的 `[ ]`）、Why 弱、**非目标缺失**。
- 无 VISION 上游文档。

---

## 2. 缺口编号索引（供路线图引用）

| 编号 | 缺口 | 来源模块 |
|---|---|---|
| A1 | 术语检查崩溃（`TERMINOLOGY.yaml:122` `cursor:` 拼写） | M5 |
| A2 | 术语表自相矛盾（`村民` 同时 forbidden + alias） | M5 |
| A3 | Harness 全部未入库（`git ls-files` 命中 0）+ 无 remote | M5/M2 |
| A4 | pre-commit / git hook 未安装 | M5 |
| A5 | 无一键 `verify.sh` | M4 |
| A6 | `tests/` 空、无 GUT、Godot 不可运行 | M4 |
| A7 | 项目 `AGENTS.md` 缺失（`opencode.json:8` 悬空引用） | M1 |
| A8 | 契约腐烂（`world_manager.contract.json` 列已删除的 4 方法） | Spec/契约 |
| A9 | 无 STATUS/PITFALLS/ADR/VISION，无范围纪律条款 | M2/M6 |
| A10 | 无 spec 的裸奔模块（道路/建筑/背包/设置…） | Spec 层 |
| A11 | `opencode.json` `"git *": "allow"` 含破坏性命令 | M3 |
| A12 | 14 个 Skills 全是 markdown，无实现 | M3/M5 |
| A13 | 提交无 spec/task 追溯 | M6 |
| A14 | SPEC 验收标准无测试映射 | Spec 层 |

---

## 3. 缺口清单（按 风险 × 修复成本 排序）

| # | 缺口 | 风险 | 修复成本 | 致命伤 |
|---|---|---|---|---|
| 1 | A1 术语检查崩溃 + A2 术语表自相矛盾 | 高 | 极低 | ☠️ 长久使用致命（唯一闸口） |
| 2 | A3 Harness 全未入库 + 无 remote → CI 是幻觉 | 高 | 低 | ☠️ 长久使用致命 |
| 3 | A4 pre-commit/hook 未安装 | 高 | 低 | ☠️ |
| 4 | A6 零测试 + Godot 不可运行 | 高 | 中 | ☠️ |
| 5 | A7 项目 AGENTS.md 缺失（悬空引用） | 中 | 极低 | — |
| 6 | A8 契约腐烂 | 中 | 低 | — |
| 7 | A9 无 PITFALLS/ADR/VISION、无范围纪律 | 中 | 低 | — |
| 8 | A10 无 spec 的裸奔模块 | 中 | 中 | — |
| 9 | A11 `git *` 全放行含破坏性命令 | 中 | 低 | ☠️ |

> A8 证据：`grep 'func (assign_villager_to_house|remove_house_occupant|get_house_occupant|get_villager_house)' scripts/` 在 `world_manager.gd` **0 命中**（已迁至 `village_service.gd` + `world_state.gd`），但 `world_manager.contract.json:158-209` 仍列这 4 个方法。

---

## 4. 三个最优先修复项（建议）

1. **复活并修正术语闸口**：`TERMINOLOGY.yaml:122` `cursor:`→`canonical:`；解决 `村民` 同时是 forbidden 与 alias 的矛盾；`check_terminology.py --all` 默认的 `--fail-on-warning` 降级（其 `_extract_potential_terms` 启发式会对几乎每个文件误报）。成本 <30 分钟，恢复唯一自动化门。
2. **让 Harness 进版本库 + 装 hook + 加 remote**：`git add` 全部 Harness 文件并提交；`pip install pre-commit && pre-commit install`；建 GitHub 私有远程仓库。否则一切验证都只在本机口头存在。
3. **建立最小可运行验证闭环**：修 `GODOT_PATH`（当前 `C:\Program Files\Godot\Godot.exe` 不存在）；gdtoolkit + GUT 接入；为纯逻辑类（`biome_generator`、`resource_spawner`、`world_state`）写首批单测；新增 `verify.sh` 一键入口。
