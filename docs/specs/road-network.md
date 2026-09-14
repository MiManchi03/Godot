# Spec: 道路网络（road_network / road_renderer）

## Why
村庄与建筑之间需要可通行、可视觉识别的道路，才能形成「聚居地」的空间感（VISION 支柱 2/3）。

## What
- `scripts/world/road_network.gd`：维护道路格集合，供放置 / 移除建筑时连通。
- `scripts/world/road_renderer.gd`：用 GridMap 统一渲染道路，减少 draw call；并做限时高亮。

## 可测试 AC
- [ ] 在建筑旁放置建筑后，相邻道路格被登记进道路网络。
- [ ] 道路渲染整合为 1–2 个 GridMap，而非逐格独立对象。
- [ ] 高亮在 `HIGHLIGHT_DURATION` 秒后自动消失。
- [ ] 卸载区块后，该区块的道路状态可从世界状态重建。

## 非目标
- 不做村民沿路寻路（由村民系统负责）。
- 不做道路损毁 / 老化。
