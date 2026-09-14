# PITFALLS.md — 错误与教训台账

> 每次 AI 犯错后追加一条；已固化为自动拦截的标注 [自动]。
> 追溯：审计 A9（无 PITFALLS，0 条教训沉淀）

## 红队演练（2026-09-14，拦截率 0/7）
| 编号 | 违规 | 拦截层 | 现状 |
|---|---|---|---|
| D1 | 架构违规（_process 分配 + 跨脚本私有访问） | 架构闸口 | [自动] Phase 2 |
| D2 | 逻辑错误（改概率违反 SPEC 3.3） | 单测 | Phase 4 计划 |
| D3 | 边界崩溃（空 / 负 / 超大输入） | 单测 | Phase 4 计划 |
| D4 | 范围蔓延（顺手改无关文件） | 范围守卫 | [自动] Phase 3 |
| D5 | 虚假测试结论（谎称 tests passed，实际未运行） | 取证闸口 | [自动] Phase 3 |
| D6 | save schema 变更无迁移 | save 守卫 | Phase 5 计划 |
| D7 | 文档腐烂（改代码不更新活文档） | 新鲜度闸口 | [自动] Phase 3 |

## Harness 教训

### pre-commit 暂存机制在 Windows 下丢改动
- 现象：钩子运行前 pre-commit 暂存未提交改动，还原时 `project.godot` 的 VillageService 行被丢弃
- 还原：从 `~/.cache/pre-commit/patch*` 提取补丁写回
- 现状：[自动] 移除会清空文件的本地空白钩子后复测通过

### 本地钩子以 GBK 读取 UTF-8 文件即崩溃
- 现象：`open(f)` 未指定编码，遇中文注释抛 UnicodeDecodeError
- 现状：[自动] 已移除相关本地钩子，改用官方实现

### VillageService 使用了非法语法 `?.` / `??`
- 现象：`?.`、`??` 并非合法 GDScript，autoload 加载失败；且 `class_name VillageService` 与同名 autoload 冲突
- 处置：Phase 4 机械改为显式 null 判断，并移除同名 `class_name`
- 现状：[自动] gdlint 与 GUT 无头运行都能拦下该类语法错误

### gdtoolkit 对超大脚本会耗尽资源
- 现象：`world_manager.gd` 达 84 MB，全量 gdlint 会卡住
- 现状：[自动] `run_gdlint.py` 跳过 > 1 MB 的脚本并给出提示
