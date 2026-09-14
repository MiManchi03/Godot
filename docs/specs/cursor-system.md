# Spec: 光标系统（cursor_manager）

## Why
光标显隐与鼠标捕获的切换直接决定操作手感：开局要捕获，打开 UI 要显光标。

## What
- `scripts/system/cursor_manager.gd`：统一管理光标显隐与鼠标模式。

## 可测试 AC
- [ ] `show()` 将鼠标模式设为 `MOUSE_MODE_VISIBLE`。
- [ ] `hide()` 将鼠标模式设为 `MOUSE_MODE_CAPTURED`。
- [ ] 打开任一 UI 时显光标，回到游戏时重新捕获。

## 非目标
- 不做自定义光标皮肤。
