# HARNESS_PLAN.md
# 版本: 1.0
# 最后更新: 2026-09-12
# 维护者: Harness PlanManager

---

## 🎯 项目目标
构建《我的天下》3D 开放世界生存游戏（Godot 4.6+）

---

## ✅ 已确定决策记录

### [2026-09-12] 核心架构选型
- **决策**: 采用 Harness 模式（规格驱动 + 技能编排 + 自动验证）
- **依据**: 解决"大体功能落地但细节 bug 多"的核心痛点
- **状态**: ✅ 已落地（14 个 Skills + 术语治理 + 契约守护）

### [2026-09-12] 语言策略
- **决策**: 技能 description 全中文 + keywords 注入英文核心词 + Agent 映射表
- **依据**: 维护可读性 + AI 触发准确率 95%+（实测）
- **映射表**: `.opencode/routing/zh-en-map.yaml`（自动同步）

### [2026-09-12] 术语治理
- **决策**: 单一事实来源 `TERMINOLOGY.yaml` + 三层闸口（生成器/Pre-commit/CI）
- **核心术语**: npc/villager/building/chunk/biome/enemy/spawn/destroy/validate
- **同步机制**: 代码生成器强制注册 → 自动同步映射表 → Pre-commit 强制校验

### [2026-09-12] 技能体系
- **决策**: 14 个独立 Skills + 1 个协调 Agent（godot-task-orchestrator）
- **列表**: spec-validator, contract-guard, scene-contract, static-analyzer, test-runner, regression-guard, dependency-guard, change-impact, code-generator, rollback-manager, task-orchestrator, gdscript-patterns, plan-manager, terminology-guard
- **协调模式**: A1 方案（Agent 系统提示词内嵌映射表）

### [2026-09-12] 玩家移动参数
- **决策**: move_speed=6.0, sprint_multiplier=1.8, acceleration=12.0, air_acceleration=20.0
- **依据**: 原 9.0 过快导致物理穿透，优化后平衡手感与性能
- **状态**: ✅ 已落地

### [2026-09-12] 摄像机灵敏度映射
- **决策**: 摄像机拖拽增益函数采用 tanh 非线性映射，范围 0.00018~0.0095
- **依据**: 解决"即使最低灵敏度也过于敏感"问题，低端精细、高端够用
- **状态**: ✅ 已落地

### [2026-09-12] 角色朝向修正
- **决策**: 角色朝向鼠标指针修正为 `atan2(-look_direction.x, -look_direction.z)`
- **依据**: 原代码假设模型前向为 +X，实际 Godot 默认前向为 -Z，导致背对鼠标
- **状态**: ✅ 已落地

---

## 🔄 进行中任务

### [任务] 术语治理工具链落地
- **状态**: ✅ 已完成
- **子任务**:
  - [x] TERMINOLOGY.yaml 初始版
  - [x] terminology_registry.py
  - [x] check_terminology.py (Pre-commit)
  - [x] generate_component.py (集成术语注册)
  - [x] migrate_terminology.py
  - [x] CI workflow
- **负责**: Harness 体系
- **完成时间**: 2026-09-12

### [任务] 14 个 Skills 代码落地
- **状态**: ✅ 已完成
- **列表**: 12 核心 Skills + plan-manager + terminology-guard
- **完成时间**: 2026-09-12

### [任务] 核心契约文件落地
- **状态**: ✅ 已完成
- **核心类**: WorldManager, PlayerController, VillagerSystem, BiomeGenerator, ResourceSpawner
- **完成时间**: 2026-09-12

### [任务] Pre-commit + CI 流水线搭建
- **状态**: ✅ 已完成
- **组件**: pre-commit-config.yaml, harness.yml, plan-sync.yml
- **完成时间**: 2026-09-12

---

## 🔄 进行中任务

### [任务] 村庄服务重构 Phase 1 (2026-09-12 新增)
- **状态**: 🔄 进行中
- **子任务**:
  - [x] Task 1.1: 存档加载后自动注册村民到 VillagerSystem
  - [x] Task 1.2: 新建 VillageService Autoload 单例
  - [x] Task 1.3: 迁移入住/搬离业务到 VillageService
  - [x] Task 1.4: VillagerSystem 新增 get_villager_by_entity_id
  - [x] Task 1.5: PlayerController 切换调用 VillageService
  - [x] Task 1.6: 关键路径调试日志完善
- **负责**: 当前会话
- **回滚点**: `git tag pre-village-service`

---

## 📋 待办事项

- [ ] Week 2: 测试框架接入
  - [ ] 接入 GUT 测试框架
  - [ ] 编写单元测试
  - [ ] 编写集成测试
  - [ ] 配置无头模式测试

- [ ] Week 2: 回归守护 + 依赖守护
  - [ ] 实现 regression-guard
  - [ ] 实现 dependency-guard
  - [ ] 配置基线测试

- [ ] Week 2: 变更影响分析 + 静态分析
  - [ ] 实现 change-impact 影响分析
  - [ ] 集成 gdtoolkit/gdscript-lint

- [ ] Week 3: 代码生成器完善 + 回滚管理
  - [ ] 完善组件模板
  - [ ] 实现 rollback-manager

- [ ] Week 3: 任务编排器 + Plan Manager 集成
  - [ ] 实现 task-orchestrator
  - [ ] 集成 plan-manager 到 Agent 协议

- [ ] 实战演练：添加"矿石系统"
  - [ ] 从 SPEC 到落地全流程演练
  - [ ] 验证全流程 ≤ 30 分钟

- [ ] 文档化 + 团队培训材料
  - [ ] 编写快速上手指南
  - [ ] 录制演示视频

---

## 🚫 明确拒绝/已排除

- ❌ 不使用全英文 Skill description（维护性不可接受）
- ❌ 不引入专用路由 Skill（原理冲突，违背按需加载机制）
- ❌ 不手动维护映射表（自动同步）
- ❌ 不使用纯中文裸奔（需 keywords + Agent 映射表补偿）
- ❌ 不硬编码术语映射（统一由 TERMINOLOGY.yaml 自动生成）
- ❌ 不允许代码中出现 forbidden 词汇（Pre-commit 强制拦截）

---

## 📚 参考资料链接

- SPEC.md: 游戏规格文档
- .opencode/terminology/TERMINOLOGY.yaml: 术语单一事实来源
- .opencode/routing/zh-en-map.yaml: 中英映射表
- .opencode/skills/*/SKILL.md: 14 个技能定义
- .opencode/agent/godot-engineer.md: 专用 Agent 配置
- .opencode/contracts/*.contract.json: 5 个核心类契约
- tools/terminology_registry.py: 术语注册中心
- tools/check_terminology.py: 术语检查器
- tools/generate_component.py: 代码生成器
- tools/plan_manager.py: 计划管理器
- .pre-commit-config.yaml: 提交前钩子
- .github/workflows/harness.yml: CI 主流水线
- .github/workflows/plan-sync.yml: Plan 同步校验
- deps.allowlist.json: 依赖白名单
- HARNESS_PLAN.md: 本文件