# Spec: 建筑系统（player_buildings / build_preview_controller）

## Why
玩家能自主放置与移除建筑，才有「这是我的地盘」的归属感（VISION 支柱 2）。

## What
- `scripts/world/player_buildings.gd`：登记玩家放置的建筑。
- `scripts/player/build_preview_controller.gd`：预览、旋转、落地放置。
- `scripts/world/world_state.gd`：把放置 / 移除写入持久化数据。

## 可测试 AC
- [ ] 预览态可绕 Y 轴旋转，放置点吸附地面。
- [ ] 放置成功后，世界状态新增该建筑记录（`add_player_building`）。
- [ ] 移除建筑后，世界状态记录移除项（`add_removed_original`）。
- [ ] 重新进入游戏后，玩家建筑仍存在（读回世界状态）。

## 非目标
- 不做建筑升级树。
- 不做多人同步与权限。
