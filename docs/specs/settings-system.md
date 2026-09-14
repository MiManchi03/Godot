# Spec: 设置系统（settings_menu / game_settings）

## Why
灵敏度、画面、音量是玩家最基础的可调项；不合适的默认值会直接破坏操作手感。

## What
- `scripts/ui/settings_menu.gd`：设置菜单 UI（`toggle_settings` 开关）。
- `scripts/game_settings.gd`：持久化设置项。

## 可测试 AC
- [ ] 调整灵敏度后立即生效（摄像机响应变化）。
- [ ] 重新进入游戏后，设置值保持不变。
- [ ] `toggle_settings` 打开 / 关闭设置菜单。

## 非目标
- 不做云同步。
- 不做键位重映射（Phase 1）。
