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

### 契约长期失修（14 处腐烂）
- 现象：`contract.json` 声明的方法 / 枚举早已从脚本移除，长期无人发现
- 处置：Phase 5 引入 `validate_contracts.py` 并清理 14 处；`resource_spawner` 契约目录错位已纠正
- 现状：[自动] pre-commit 与 verify.sh 每次都比对契约与实现一致

### 术语表的禁用词是白名单词的子串
- 现象：`路网` 是 `道路网络` 的子串，`破坏物` 是 `可破坏物` 的子串，写成 allowed 词也会被报错
- 处置：Phase 6 移除 5 处此类禁用词（无法被子串匹配区分）
- 现状：[自动] 已清理；登记术语时需自检「禁用词是否为某别名子串」

### 契约不得声明尚未提交的接口
- 现象：`villager_system` 契约声明了 `get_villager_by_entity_id`，该方法仅存在于未提交 WIP，pre-commit 暂存后比对失败
- 处置：先移除该声明，待 WIP 落地后补回
- 现状：半自动（需人工在 WIP 提交时同步契约）
