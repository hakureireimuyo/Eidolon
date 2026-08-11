# 运行时核心设计

> 本文档记录 eidolon-runtime（未来层）**最终确定的核心设计原则**（已剔除"集中式大脑""Prompt Builder"等被推翻方案）。
> 相关文档：[核心架构哲学与项目定位](./design-philosophy.md) · [状态模型、上下文管理与缓存](./state-and-context.md) · [多智能体与多模态系统](./multi-agent-multimodal.md) · [独立项目职责与能力边界](./project-responsibilities.md)

## 1. 核心原则：极小且领域无知

运行时核心应像操作系统内核——负责**事件调度 / 状态管理 / Agent 生命周期 / 消息通信 / 上下文编译**，但**不知道"人格 / 世界 / 经济 / 记忆"等概念**。

```
Runtime Kernel
├── Event Loop
├── Scheduler
├── State Store
├── Message Bus
└── Context Compiler
```

（领域知识由 Processor / Agent 提供，见下文。）

## 2. 被推翻的架构（不再采用）

- ❌ 把 Runtime 设计成集中式"大脑"：`Runtime { Character Logic, Personality Logic, Memory Logic, World Logic, … }`。这会导致"新增能力 → 改 Runtime → 重测全系统"，正是数据容器想避免的问题。
- ❌ "Prompt Builder" 简单拼接上下文。改为 [Context Compiler + IR](./state-and-context.md)。

## 3. 最小抽象：State / Event / Processor

| 概念 | 含义 | 例 |
|------|------|----|
| **State** | 系统当前状态（container / session / variables / events） | "现在世界是什么样" |
| **Event** | 系统发生的事——状态变化的原因 | `user_message` / `time_passed` / `weather_change` |
| **Processor** | 监听事件并修改状态的**状态转换器**（由早期 Extension 演化而来） | Emotion Processor：读 Event+State → 写 Emotion State Change → 影响多系统 |

- Processor 不是被 Runtime 调用某个固定函数，而是**参与系统生命周期**；Runtime 不知道它做什么。
- 整体循环：事件 → Runtime 分发 → Processors 修改状态 → Runtime 收集 → 生成输出。

## 4. 共享状态，而非共享 Prompt

- ❌ 流水线式：Agent A 生成文本 → Agent B 读文本 → Agent C 续处理。
- ✅ 状态图式：每个 Processor 读取自己需要的部分、写入自己负责的区域（Character / Emotion / Relationship / World / Memory）。

```
State Graph
Character ─┐
Emotion ──┼─ Relationship
World ───┘   └─ Memory
```

每个模型都是状态转换器，而非文本接力者。

## 5. 与 ECS 同构

| ECS | 本运行时 |
|-----|---------|
| 实体 Entity | Character |
| 组件 Component | Personality / Memory / Emotion / Relationship / Inventory / Location |
| 系统 System | EmotionSystem / MemorySystem / WorldSystem / RenderSystem |

实体不知道系统如何工作——与 `State + Processor + Event` 同构。

## 6. 渐进验证策略

1. 先验证最小闭环：**事件 → Processor 改 State → Compiler 生成稳定 Context → LLM 响应**，并观察状态变化时 Prompt 前缀是否稳定。
2. 再逐步加 Personality / World 等 Processor。
3. 新增能力 = 新增 `extensions/<x>/` 目录，而非修改 `runtime/core`。

## 7. 与协议层的关系

- 运行时是消费方，按 `type` 标签路由（见 [独立项目职责](./project-responsibilities.md) §6）。
- 内核"领域无知"与 PersonaSeed"协议无知"同构：稳定的部分进入核心，不稳定的部分成为扩展。
