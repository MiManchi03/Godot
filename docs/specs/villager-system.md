# Spec: 村民系统（villager_system / villager）

## Why
村民让村庄从「几栋建筑」变成「有人生活的聚居地」（VISION 支柱 3）。

## What
- `scripts/npc/villager_system.gd`：注册 / 注销村民，广播注册与任务信号。
- `scripts/npc/villager.gd`：单个村民的位置、朝向、状态。
- `scripts/village/village_service.gd`：入住关系查询与分配（读世界状态）。

## 可测试 AC
- [ ] `register_villager(v)` 后，`get_all_villagers()` 含该村民。
- [ ] 分配任务时广播 `task_bound` 信号。
- [ ] 从 save 读回后，村民被自动注册回村民系统。
- [ ] 分配入住后，`get_house_occupant(建筑)` 返回该村民标识。

## 非目标
- 不做复杂需求模拟（饥饿 / 情绪）。
- 不做多人协作。
