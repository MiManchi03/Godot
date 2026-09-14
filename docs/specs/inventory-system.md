# Spec: 背包系统（inventory_manager / inventory_ui / hotbar_ui）

## Why
收集与使用物品是生存循环的入口，玩家需要随时看到自己拥有什么。

## What
- `scripts/ui/inventory_manager.gd`：背包容量、快捷栏、物品堆叠。
- `scripts/ui/inventory_ui.gd`：背包 UI（`toggle_inventory` 开关）。
- `scripts/ui/hotbar_ui.gd`：游戏中的快捷栏 UI。

## 可测试 AC
- [ ] 同种物品按 `max_stack` 堆叠，超出则占用新格。
- [ ] 快捷栏可切换选中项，并同步到玩家手持。
- [ ] `toggle_inventory` 打开 / 关闭背包 UI。

## 非目标
- 不做合成树。
- 不做容器互连（箱子网格）。
