---
name: godot-change-impact
description: 分析变更影响半径：直接/间接依赖、数据流、场景依赖。任意修改前评估风险。KEYWORDS: impact, dependency, blast, radius, risk, analysis, 影响, 依赖, 波及, 风险, 分析
compatibility: opencode
metadata:
  category: analysis
  triggers_en: ["impact", "dependency", "blast", "radius", "risk", "analysis", "change"]
  triggers_zh: ["影响", "依赖", "波及", "风险", "分析", "变更"]
  zh_name: "Godot 变更影响分析"
  zh_desc: "分析变更影响半径：直接/间接依赖、数据流、场景依赖。任意修改前评估风险。"
---

# godot-change-impact

## What I do
- 直接依赖：import/preload/信号连接/节点引用
- 间接依赖：通过 Autoload/单例/全局状态传递
- 数据流依赖：共享 WorldState/WorldManager/玩家状态
- 场景依赖：场景实例化关系、子场景引用

## Output
- impact_graph: GraphViz DOT / Mermaid 格式
- risk_level: LOW / MEDIUM / HIGH / CRITICAL
- affected_tests: 建议优先运行的测试
- human_review_required: CRITICAL 级必须人工确认

## When to use me
Use before any modification to assess risk.