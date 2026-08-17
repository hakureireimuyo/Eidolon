# 内核、编辑器与运行时:三层定位与 I/O 边界

> 本文档记录"Runtime 与编辑器分层"设计对话的**最终决策**(已剔除过渡讨论)。
> 相关文档:[核心架构哲学与项目定位](./design-philosophy.md) · [项目职责与能力边界](./project-responsibilities.md) · 图运行时总纲(内核仓库 `docs/graph-runtime-overview.md`) · 内核演化阶段(内核仓库 `docs/graph-runtime-overview.md` §8)

## 1. 核心命题:三层定位

> **内核是游戏的引擎,编辑器是游戏设计工具,Runtime 是运行游戏的框架。**

Eidolon 是一种"可编程游戏引擎",三个层次彻底分开:

| Eidolon | 传统游戏开发 | 回答的问题 |
|---------|-------------|-----------|
| Kernel | 游戏引擎 | 游戏世界如何存在、如何变化、如何执行 |
| Editor | 游戏开发 / 设计工具 | 这个游戏是什么 |
| Game Project | 一个具体游戏 | —— |
| Runtime | 游戏运行环境 | 如何把这个游戏运行起来 |
| Simulation Graph | 游戏逻辑与世界模型 | 世界如何运行 |
| Presentation Graph | UI / 表现层 | 世界如何被呈现 |
| Asset | 游戏资源 | —— |
| LLM Node | 一种游戏逻辑组件 | —— |

```
Kernel ──提供"游戏可以怎样运行"的能力──→ Editor ──定义"这个游戏是什么"──→ Game Project
                                                                              │
                                                              Runtime ──把这个游戏运行起来──→ Running Game
```

**Runtime 不等于 Kernel。**Kernel 说"我能够执行这个 Graph";Runtime 说"我要加载这个项目、
启动它、让玩家与它交互、让它持续运行"。Runtime 是 **Kernel 的宿主层,不是 Kernel 的替代品**。

## 2. Kernel:游戏引擎本体

Kernel 不关心"这是一个什么游戏",它提供的是游戏能够运行所依赖的基础机制:

```
Kernel
├── Graph / Node / 连线
├── 数据包 / 控制信号
├── Event / 脏节点传播
├── 状态 / 快照 / 持久化
├── 调度 / 异步完成注入
└── 资产
```

核心模型是 **Graph + Node + State + Event**,而不是传统引擎的 Scene + GameObject + Component。
事件传播、异步 LLM、worklist、多节点独立推进等都是这一层的游戏运行机制,
不是某个具体游戏的设计。演化方向:从执行内核(Execution Kernel)向世界内核(World Kernel)
演化(见内核仓库 `docs/graph-runtime-overview.md` §8)。

## 3. Editor:Project Authoring Environment

Editor 不只是"Graph 编辑器",而是**项目创作环境**——让设计者定义整个游戏 / 模拟项目。
至少包含几个编辑域:

```
Graph Editor          定义世界运行逻辑
Node / Asset Editor   定义节点和资源
Input Editor          定义用户如何向世界输入
Presentation Editor   定义世界如何呈现
Project Editor        把上述东西组合成一个完整项目
```

- 特殊输入输出节点是 **Editor 可创建、可配置、可连接的正式节点类型**,不是 Runtime 临时增加的特殊功能;
- Editor 不需要知道游戏最终是什么——它只需要知道如何编辑内核所定义的项目模型;
- 设计者产出的 Game Project = 图资产 + 节点配置 + 世界数据 + 剧情数据 + UI 定义 + 输入映射 + 资源。

## 4. Runtime:游戏运行的框架(宿主层)

Runtime 不是"运行一个 RPG 的程序",甚至不是"运行一个 AI 剧情游戏的程序",而是:

> **解释并执行一个图项目,同时向外部系统提供结构化输入输出接口的通用运行时。**

Runtime 负责:

```
启动项目 / 加载资源 / 初始化内核 / 建立输入输出通道
/ 驱动运行循环 / 管理生命周期 / 连接前端 / 处理存档
/ 恢复快照 / 提供调试接口
```

但它不应该知道"这个项目是 RPG 还是视觉小说"。Web 服务只是 Runtime 当前的宿主形态之一。

## 5. I/O 边界:Runtime 提供 I/O 能力,不规定语义与表现

> **Runtime 提供 I/O 能力,但不规定 I/O 的语义和表现形式。**语义来自 Game Project,表现来自 Editor 中设计出来的 Presentation。

```
外部输入 → Input Adapter → Graph Input → 节点网络 → Graph Output → Output Adapter → 外部世界
```

- **输入统一为 External Event**:`input.button_pressed` / `input.text_submitted` / `input.pointer_clicked` /
  `input.dragged` / `input.timer_elapsed` / `input.system_event`——攻击防御按钮、文字输入、选项、鼠标键盘、
  外部传感器都是同一种东西,由 Editor 设计的输入节点映射到图;
- **输出是结构化输出事件**:如 `scene.update` / `character.dialogue`——Runtime 只负责产生它们,
  不关心浏览器看到什么。Runtime 不规定"输入 = 一个 HTML input、输出 = 一个 React ChatBox";
- **同一个 Runtime,多套前端**:

```
             Eidolon Runtime
                    │
        ┌───────────┼───────────┐
        ↓           ↓           ↓
      Web UI      Tauri UI     CLI / Debug Console
```

开发期可以没有完整 UI,直接观察各节点输入输出(Debug Console);Simulation Graph 稳定后再制作 Presentation。

## 6. Simulation Graph 与 Presentation Graph

项目的运行逻辑存在两种结构,通过数据和控制信号连接:

| 图 | 回答的问题 | 示例 |
|----|-----------|------|
| **Simulation Graph** | 世界如何运行 | 用户行为 → 角色状态 → 剧情状态 → 环境状态 → 事件 → 下一阶段 |
| **Presentation Graph** | 世界如何被呈现 | 角色状态→立绘、角色对话→对话框、环境状态→背景、事件→音效、剧情状态→UI 按钮 |

- 表现(UI)是**项目设计的一部分**,是图的一种外部表现——`DialogueOutputNode` / `CharacterPortraitNode` /
  `BackgroundNode` / `SoundEffectNode` / `ChoiceNode` 等都是普通节点,可进一步抽象为
  Text / Image / Audio / Video / Control / Scene / Composite 输出节点;
- 两图分离后,表现层可整体替换或开关,模拟层不受影响(与"表现层与模拟层解耦"原则一致,见
  [叙事游戏引擎架构与 AI 职责分离](./narrative-game-engine.md) §8);
- 开发顺序:先让 Simulation Graph 稳定,再制作 Presentation Graph。

## 7. 被推翻 / 修正的观点

| 被推翻(已删除) | 最终决定(保留) |
|------------------|------------------|
| Runtime = 图执行器,把"图执行器"逐渐扩展成"游戏运行环境" | 三层分工:Kernel 提供运行能力、Editor 定义游戏、Runtime 装载项目并驱动运行;Runtime 是宿主层 |
| Runtime 缺"用户可见页面"→ Runtime 自己补 UI | 页面属于编辑器范畴;Runtime 不定义输入输出形式,只提供 I/O 协议边界 |
| 急着把 Runtime 做成"游戏应用" | Runtime 所缺的能力等内核世界模型成熟后再向上提供;先让 Graph Runtime 演化成真正的 Game Kernel,再让 Editor 用它设计游戏、让 Runtime 用它运行游戏 |
