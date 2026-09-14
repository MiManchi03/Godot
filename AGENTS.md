# AGENTS.md — 项目宪法（目录式索引）

> 本文件只做**索引**，细节一律下沉到 `docs/` 与 `.opencode/`。
> 追溯：`opencode.json:8` 曾引用不存在的 `AGENTS.md`（审计 A7）。

## 1. 项目速览
- 《我的天下》3D 开放世界生存游戏（Godot 4.6+）
- 主场景 `World.tscn`；引擎配置 `project.godot`

## 2. 上游依据（先读）
| 文档 | 作用 |
|---|---|
| `docs/VISION.md` | 项目愿景（所有 spec 的上游） |
| `SPEC.md` | 游戏规格与验收标准 |
| `docs/specs/*.md` | 各子系统的 Why / What / AC / 非目标 |
| `HARNESS_PLAN.md` | 决策 / 任务 / 拒绝项的长期记忆 |
| `docs/harness-roadmap.md` | Harness 升级路线 |

## 3. 工作协议（指向细节）
| 主题 | 权威位置 |
|---|---|
| Agent 行为与会话启动 | `.opencode/agent/godot-engineer.md` |
| 技能清单 | `.opencode/skills/*/SKILL.md` |
| 术语唯一来源 | `.opencode/terminology/TERMINOLOGY.yaml` |
| 中英映射 | `.opencode/routing/zh-en-map.yaml` |
| 接口契约 | `.opencode/contracts/**/*.contract.json` |
| 活文档入口 | `STATUS.md`、`PITFALLS.md` |

## 4. 硬性纪律
1. **范围纪律**：只改任务声明的文件，禁止顺手重构无关代码。
2. **术语一致**：代码 / 文档统一用 canonical 词，禁用 forbidden 词（`.pre-commit-config.yaml` 闸口）。
3. **完成取证**：宣称完成前必须贴真实命令输出，禁止口头断言。
4. **回滚点**：高风险改动先打 git tag。
5. **计划同步**：架构级决策写入 `HARNESS_PLAN.md`。

## 5. 校验入口
- 提交时：`.pre-commit-config.yaml`（术语 / 架构 / 依赖 / 范围 / 活文档 / 取证 / gdlint / 单测 / 契约 / save schema）
- 一键：`bash verify.sh`
