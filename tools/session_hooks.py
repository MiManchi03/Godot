#!/usr/bin/env python3
# tools/session_hooks.py
# 会话钩子 - 用于上下文压缩前自动保存关键信息

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from plan_manager import PlanManager


def on_session_start():
    """会话开始时自动注入 plan 摘要"""
    pm = PlanManager()
    summary = pm.get_context_summary(3000)
    if summary.strip():
        output = f"""
=== HARNESS_PLAN 恢复上下文 ===
{summary}
=== 恢复完成，继续执行 ===
"""
        print(output)
    return 0


def on_compaction():
    """上下文压缩前自动保存关键进展"""
    # 此函数由 opencode 在压缩前调用
    # 实际使用中，Agent 应显式调用 plan_manager.append_decision
    # 这里提供一个模板供参考
    pm = PlanManager()
    # 实际使用时，Agent 应手动调用并传入当前会话摘要
    # pm.append_decision(
    #     title=f"会话压缩前快照",
    #     rationale="自动保存压缩前的关键进展",
    #     status="📝 会话记录"
    # )
    return 0


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Session Hooks")
    parser.add_argument("hook", choices=["start", "compaction"])
    args = parser.parse_args()

    if args.hook == "start":
        return on_session_start()
    elif args.hook == "compaction":
        return on_compaction()
    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main())