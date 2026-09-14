# 村庄服务重构计划 (Village Service Refactor Plan)
# 版本: 1.0
# 创建时间: 2026-09-12
# 状态: 🔄 执行中

---

## 🎯 目标
解决"房屋详情面板无村民可入住、入住按钮无反应"的核心问题，并按分层架构重构村庄/村民/建筑关系管理。

---

## 📐 架构决策（已确认）

| 决策点 | 方案 | 理由 |
|--------|------|------|
| VillageService 形式 | **Autoload 单例** | 跨系统访问最干净，无需节点树查找 |
| 村庄 ID 持久化 | **Phase 1 暂不持久化**，运行时重算 | 先跑通主流程，Phase 2 再加持久化避免抖动 |
| WorldManager 旧业务方法 | **直接删除迁移**，不保留委托 | 强制切换，避免双维护，代码更简洁 |

---

## 🏗️ 目标架构分层

```
┌─────────────────────────────────────────────────────────────┐
│  Presentation: PlayerController → HouseDetailUI              │
└─────────────────────────────────────────────────────────────┘
                              ↑ 信号/查询
┌─────────────────────────────────────────────────────────────┐
│  Service: VillageService (Autoload)                          │
│    - get_villagers_for_house()                               │
│    - assign_villager_to_house()                              │
│    - remove_house_occupant()                                 │
│    - get_village_of_house()                                  │
└─────────────────────────────────────────────────────────────┘
      ↑                    ↑                    ↑
┌─────┴─────┐       ┌──────┴──────┐      ┌────┴──────┐
│Registry   │       │ Persistence │      │ Spatial   │
│VillagerSys│       │ WorldState  │      │WorldManager│
└───────────┘       └─────────────┘      └───────────┘
```

---

## 📋 Phase 1 任务清单（最小可行，可独立验收）

### Task 1.1: 存档加载后自动注册村民到 VillagerSystem
- **文件**: `scripts/world/world_manager.gd`
- **位置**: `_apply_saved_villagers()` 末尾（第 668 行附近 `villager.call("on_loaded_from_save")` 后）
- **代码**:
```gdscript
# 新增：将恢复的村民实例注册回运行时系统
if villager.has_method("get_instance_id"):
    var vs = get_tree().get_first_node_in_group("villager_system")
    if vs and vs.has_method("register_villager"):
        vs.call("register_villager", villager)
        print("[VILLAGE] Restored villager registered: ", villager.get_meta("entity_id", ""))
```
- **验收**: 控制台出现 `[VILLAGE] Restored villager registered: ...` 日志

---

### Task 1.2: 新建 VillageService Autoload
- **文件**: `scripts/village/village_service.gd` (新建)
- **核心接口**:
```gdscript
extends Node
class_name VillageService

signal village_boundaries_changed
signal villager_assigned(villager_id: String, house_id: String)
signal villager_unassigned(villager_id: String, house_id: String)

# 依赖（_ready 绑定）
var _world_manager: Node
var _villager_system: Node
var _world_state: Node

func _ready() -> void:
    add_to_group("village_service")
    _world_manager = get_node_or_null("/root/World/WorldManager")
    _villager_system = get_tree().get_first_node_in_group("villager_system")
    _world_state = _world_manager?.get("world_state")
    print("[VILLAGE] VillageService initialized")

# ===== 核心查询 =====
func get_villagers_for_house(house_entity_id: String) -> Array[Node3D]:
    var village_id = _get_village_id_of_house(house_entity_id)
    if village_id.is_empty():
        return []
    var boundary = _world_manager?._village_boundaries.get(village_id, [])
    if boundary.is_empty():
        return []
    return _filter_villagers_in_boundary(boundary)

func get_house_occupant(house_entity_id: String) -> String:
    return _world_state?.get_house_occupant(house_entity_id) ?? ""

func get_village_of_house(house_entity_id: String) -> String:
    return _get_village_id_of_house(house_entity_id)

# ===== 业务操作 =====
func assign_villager_to_house(house_entity_id: String, villager_entity_id: String) -> bool:
    if not _can_assign(villager_entity_id, house_entity_id):
        return false
    var ok = _world_state?.assign_villager_to_house(house_entity_id, villager_entity_id) ?? false
    if ok:
        villager_assigned.emit(villager_entity_id, house_entity_id)
        _world_state?.save_dirty(true)
    return ok

func remove_house_occupant(house_entity_id: String) -> bool:
    var villager_id = _world_state?.get_house_occupant(house_entity_id) ?? ""
    var ok = _world_state?.remove_house_occupant(house_entity_id) ?? false
    if ok and not villager_id.is_empty():
        villager_unassigned.emit(villager_id, house_entity_id)
        _world_state?.save_dirty(true)
    return ok

# ===== 内部辅助 =====
func _get_village_id_of_house(house_entity_id: String) -> String:
    if not _world_manager:
        return ""
    return _world_manager._building_to_village.get(house_entity_id, "")

func _filter_villagers_in_boundary(boundary: Array[Vector3]) -> Array[Node3D]:
    var all_v = _villager_system?.get_all_villagers() ?? []
    var result: Array[Node3D] = []
    for v in all_v:
        if _point_in_polygon(v.global_position, boundary):
            result.append(v)
    return result

func _can_assign(villager_id: String, house_id: String) -> bool:
    # 规则：同村庄、该村民未入住他处
    var v_village = _get_village_id_of_villager(villager_id)
    var h_village = _get_village_id_of_house(house_id)
    if v_village != h_village:
        return false
    var current_house = _world_state?.get_villager_house(villager_id) ?? ""
    return current_house.is_empty() or current_house == house_id

func _get_village_id_of_villager(villager_id: String) -> String:
    # 通过已入住房屋反推，或位置测试
    var house_id = _world_state?.get_villager_house(villager_id) ?? ""
    if not house_id.is_empty():
        return _get_village_id_of_house(house_id)
    # 兜底：位置测试
    var villager = _villager_system?.get_villager_by_entity_id(villager_id)
    if villager:
        for vid in _world_manager._village_boundaries.keys():
            if _point_in_polygon(villager.global_position, _world_manager._village_boundaries[vid]):
                return vid
    return ""

func _point_in_polygon(point: Vector3, polygon: Array[Vector3]) -> bool:
    # 射线法：XZ 平面投影
    var inside = false
    var j = polygon.size() - 1
    for i in range(polygon.size()):
        var pi = polygon[i]
        var pj = polygon[j]
        if ((pi.z > point.z) != (pj.z > point.z)) and \
           (point.x < (pj.x - pi.x) * (point.z - pi.z) / (pj.z - pi.z) + pi.x):
            inside = not inside
        j = i
    return inside
```

- **Autoload 注册**: `project.godot` → `autoload` 添加 `VillageService = "*res://scripts/village/village_service.gd"`
- **验收**: 启动游戏控制台出现 `[VILLAGE] VillageService initialized`

---

### Task 1.3: 迁移入住/搬离业务到 VillageService
- **文件**: `scripts/world/world_manager.gd`
- **动作**: **删除**以下方法（第 1017-1036 行）:
  - `assign_villager_to_house()`
  - `remove_house_occupant()`
  - `get_house_occupant()` (保留委托或删除，PlayerController 改调 Service)
  - `get_villager_house()` (同理)
- **原因**: 业务逻辑下沉到 Service，WorldManager 只做空间/Chunk

---

### Task 1.4: 新增 VillagerSystem 精确查找
- **文件**: `scripts/npc/villager_system.gd`
- **新增方法** (第 88 行后):
```gdscript
func get_villager_by_entity_id(entity_id: String) -> Node:
    if entity_id.is_empty():
        return null
    for v in _villagers:
        if str(v.get_meta("entity_id", "")) == entity_id:
            return v
    return null
```
- **验收**: VillageService._get_village_id_of_villager() 可调用

---

### Task 1.5: PlayerController 切换调用 VillageService
- **文件**: `scripts/player/player_controller.gd`
- **修改**: `_open_house_detail_for()` (第 866-978 行)
- **核心变更**:
```gdscript
# 旧：本地 chunk 过滤 + 直接查 WorldManager
# 新：统一调用 VillageService
func _open_house_detail_for(house_node: Node3D) -> void:
    if _house_detail_ui == null or house_node == null:
        return
    var house_entity_id := str(house_node.get_meta("entity_id", ""))
    if house_entity_id.is_empty():
        house_entity_id = "house|%.3f|%.3f" % [house_node.global_position.x, house_node.global_position.z]
        house_node.set_meta("entity_id", house_entity_id)

    var vs = get_node_or_null("/root/VillageService")  # Autoload 路径
    if vs == null:
        print("[VILLAGE_UI] VillageService not found")
        return

    var villagers = vs.get_villagers_for_house(house_entity_id)
    var occupant_id = vs.get_house_occupant(house_entity_id)
    # ... 后续构建 villager_items 同原逻辑，但用 villagers 变量
```
- **移除**: 第 901-941 行的 chunk 过滤逻辑、VillagerSystem 直接查找
- **验收**: 打开房屋面板，村民列表正确显示同村庄村民

---

### Task 1.6: 关键路径调试日志
- **文件**: `world_manager.gd`, `village_service.gd`, `player_controller.gd`
- **日志前缀**: `[VILLAGE]`, `[VILLAGE_UI]`, `[VILLAGE_SYS]`
- **关键点**:
  - 村民注册/注销
  - 入住/搬离操作
  - 面板打开时的村庄 ID、边界顶点数、筛选结果数

---

## 📋 Phase 2 任务（Phase 1 验收后）

| 任务 | 说明 |
|------|------|
| 2.1 VillageService 单元测试 | Mock 三大依赖，覆盖核心查询/业务 |
| 2.2 村庄 ID 持久化 | WorldState 新增 `_village_definitions`，启动时恢复 |
| 2.3 契约测试 | godot-contract-guard 覆盖 VillageService 公共接口 |
| 2.4 集成测试 | 多村庄场景、存档重启、入住全流程 |

---

## ✅ 验收标准（端到端）

| 场景 | 预期结果 |
|------|----------|
| 新游戏/载入档有村民 | 村民自动注册到 VillagerSystem，控制台有注册日志 |
| 走到房屋按 F | 面板显示该村庄所有村民（含已入住他处标记"已入住"） |
| 点入住 → 选村民 | 面板刷新显示入住者名字、疲劳值 |
| 存档 → 重启 | 入住关系保持、村民仍在系统中 |
| 两村庄相邻 | 各自面板只显示自家村民，无跨村干扰 |

---

## ⚠️ 风险与回滚点

| 风险 | 缓解 | 回滚点 |
|------|------|--------|
| VillageService Autoload 加载顺序 | _ready 中延迟绑定依赖 | Git tag `pre-village-service` |
| 村庄边界重算导致 ID 变 | Phase 1 不持久化，接受运行时重算 | 同上 |
| PlayerController 找不到 Autoload | 使用 `/root/VillageService` 绝对路径 | 同上 |

---

## 🚀 执行顺序

1. `git tag pre-village-service` (建立回滚点)
2. Task 1.1 (最小改动，立即见效)
3. Task 1.2 (新建文件 + Autoload 注册)
4. Task 1.4 (VillagerSystem 微增)
5. Task 1.3 (删除 WorldManager 旧业务)
6. Task 1.5 (PlayerController 切换)
7. Task 1.6 (日志完善)
8. 启动游戏端到端验收
9. 通过 → Phase 2 规划
10. 失败 → `git reset --hard pre-village-service`