# 数据容器与项目工程层

> 本文档记录"数据容器"在叙事 / 模拟方向上的**最终定位决策**(已剔除过渡讨论)。它扩展而非推翻 [资源管理与跨项目集成](./resource-management.md) 中协议层作为底层哑容器的定位。
> 相关文档:[核心架构哲学与项目定位](./design-philosophy.md) · 运行时核心设计 · [剧情 / 世界 / 叙事引擎](./narrative-world-engine.md)

## 1. 数据容器的重新定位

数据容器不只是"角色卡解析结果的存储",而应成为**游戏项目工程的数据层(Project Data Layer)**。

- 类比 Unity / Unreal 的 `Project Asset + Runtime State`；运行核心不是图形渲染,而是叙事 / 人格 / 世界模拟。
- 因此它应能承载:世界(geography / history / factions / rules)、角色(personality / relationship / memory / goals)、事件(triggers / conditions / consequences / scripts)、资源(items / currency / information / reputation)、运行时状态(time / active_events / world_changes / player_history)。

> 关键认知:这已不是"数据库",而更像一种**世界工程文件格式**。

## 2. 三层数据模型(Project / Runtime / Engine)

| 层 | 职责 | 类比 | 可派生性 |
|----|------|------|---------|
| Project Layer(静态) | 描述"世界是什么" | Unity 的 Scene / Prefab / ScriptableObject / Asset | 可分享、导入、版本控制 |
| Runtime Layer(状态) | 描述"世界现在是什么状态" | 游戏存档 | 同一工程派生无数世界实例(存档) |
| Engine Layer(核心) | 状态管理 / 事件系统 / 条件判断 / Context Compiler | 引擎运行时 | 真正要开发的核心 |

同一"末日世界工程"可产生不同存档:帮政府→复兴、帮反抗军→革命、独自生存→毁灭。

## 3. 源数据保持模型无关(Semantic State)

角色卡 / 世界包保存的是**语义状态**,不保存任何具体模型的 Prompt 或参数:

```
Semantic State = { personality_traits, memories, relationships, appearance, history, ... }
```

不同 Agent 自行解释同一状态 → 产生不同表现(语言 Agent 生成语气、视觉 Agent 生成表情、动画 Agent 生成动作)。模型替换不影响数据层。

## 4. 优先级:Engine > Project > Assets

```
Engine(核心)  ↑  Project(工程)  ↑  Assets(资源,含 PNG 角色卡)
```

- **PNG 角色卡思路降级为非核心**:它只是"导入资源文件"(类似 Unity 的 Texture / Model / Script),不是引擎本身。
- 真正核心是 Engine↑Project↑Assets,与 Unity Engine↑Unity Project↑Textures / Models / Scripts 同构。
- 重申 [资源管理与跨项目集成](./resource-management.md) 的裁定:标准包是标准格式,分发镜像(封面图内嵌包数据)是分发封装,不应将分发封装提升为核心。

## 5. 与协议层的关系

- 本层是协议层之上的"**世界工程数据**"视角；协议层仍是底层哑容器(协议无知)。
- "世界工程文件格式"由各扩展层(角色、世界、人格等)各自定义,包格式沿用协议层的标准容器。
- 协议层不预知"世界 / 剧情"等概念。

## 6. 剧情 / 世界包即"插件"

Story Package 是 Project Layer 的一种实例:

```
Story Package/
├── world.json
├── characters/{alice,bob}.json
├── events/{intro,crisis,ending}.yaml
├── rules/relationship.py
└── resources.json
```

加载一个剧情包 = 进入另一个世界(详见 [剧情 / 世界 / 叙事引擎](./narrative-world-engine.md))。
