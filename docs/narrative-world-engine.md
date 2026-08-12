# 剧情 / 世界 / 叙事引擎

> 本文档记录"叙事 / 世界模拟"方向的**最终决策**（已剔除过渡讨论）。它描述 eidolon-world（未来层）与叙事能力的设计理念，建立在 [数据容器与项目工程层](./data-container-project-layer.md) 与运行时核心设计之上。
> 引擎架构与可实现的编辑器 / 事件图 / AI 职责分离等设计见 [叙事游戏引擎架构与 AI 职责分离](./narrative-game-engine.md)。
> 相关文档：状态模型、上下文管理与缓存 · 多智能体与多模态系统

## 1. 叙事运行时的形态

剧情不再是一棵固定树，而是一个**动态运行的世界**：

```
World State → Event Resolver → Narrative Rules → Context Builder → LLM 生成表现层文本
```

真正决定剧情走向的是**系统**，不是模型。

## 2. 三层次（与数据容器三层同构）

| 层 | 职责 | 类比 |
|----|------|------|
| Project Layer（静态） | 定义世界是什么 | Scene / Prefab |
| Runtime Layer（状态） | 世界当前状态（类存档） | 游戏存档 |
| Engine Layer（核心） | 状态管理 + 事件系统 + 条件判断 + Context Compiler | 引擎运行时 |

同一工程可派生无数世界实例（存档 A 帮政府→复兴；B 帮反抗军→革命；C 独活→毁灭）。

## 3. 事件与条件系统

- **Event Resolver** 根据状态触发事件：`food<5 → food_crisis`；`trust>80 → unlock secret`。
- **条件判断**：`if player.has_item(key) and relationship(alice)>50 → unlock(secret_route)`。
- 规则驱动，而非把路线写死。

## 4. 多路线是"规则生成"而非"预写死"

剧情变量空间（政治关系 / 人物关系 / 资源 / 时间线 / 玩家选择）动态生成可能路线。例：敌人存活 → 几十小时后可能成为盟友 / 背叛 / 最终 Boss / 被其他势力杀。这是"**模拟世界**"而非"播放剧情"。

## 5. 世界子系统

- **角色关系系统**：信任 / 好感 / 恐惧 / 欠债 / 怀疑等作为状态变量；同一句话在不同关系下产生不同剧情。
- **世界资源系统**：金钱 / 食物 / 时间 / 道具，以及信息 / 人情 / 声望 / 心理状态 / 世界稳定度等"软资源"；世界可自然演化（稳定度下降 → 暴乱概率上升）。

## 6. 剧情包作为插件 / 作者模式

- Story Package（`world.json` + `characters/` + `events/` + `rules/` + `resources.json`）加载即进入另一个世界。
- 作者定义角色 / 事件 / 条件 / 资源 / 隐藏变量 / 结局，系统自动运行（接近 RPG Maker / Ren'Py / Dwarf Fortress / Crusader Kings / AI Dungeon 的融合）。
- 普通用户"进入故事"，作者"创建世界"。

## 7. 与 Simulation Runtime 的关系

叙事 / 世界只是 Runtime 之上的一种应用；角色也只是世界中一种实体。引擎核心**不绑定"剧情"概念**（见 [核心架构哲学](./design-philosophy.md) §5）。
