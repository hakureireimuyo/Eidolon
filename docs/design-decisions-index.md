# 设计决策总览索引(运行时 / 世界 / 多智能体方向)

> 本索引包含根目录 `docs/` 下的文档；运行时相关设计文档位于 `runtime/eidolon-runtime/docs/`:运行时核心设计、状态模型/上下文管理、多智能体与多模态、模型选型与验证。

## 文档导航

| 文档 | 知识域 | 一句话 |
|------|--------|--------|
| [核心架构哲学与项目定位](./design-philosophy.md) | 全局哲学 | Eidolon 是叙事/模拟运行时,LLM 是表现层不是大脑,从零实现 |
| [数据容器与项目工程层](./data-container-project-layer.md) | 数据层 | 数据容器=世界工程数据层；源数据模型无关；Engine>Project>Assets |
| [剧情 / 世界 / 叙事引擎](./narrative-world-engine.md) | 世界/叙事 | 剧情=动态世界；事件/规则驱动；多路线规则生成；剧情包即插件 |
| [叙事游戏引擎架构与 AI 职责分离](./narrative-game-engine.md) | 引擎架构 | ECS世界模型；三大编辑器；Action Intent→World Event循环；AI职责分离；双维度上下文管理 |
| [项目职责与能力边界](./project-responsibilities.md) | 分层职责 | 四层职责边界；稳定进核心,不稳定成扩展；运行时解释器(X-service)与格式层(X)成对 |

## 被推翻的观点 → 最终决定(本次整理已剔除推翻部分)

| 被推翻(已删除) | 最终决定(保留) |
|------------------|------------------|
| Runtime 做成集中式"大脑"(领域逻辑全塞进内核) | 内核极小且领域无知,领域逻辑由 Processor/扩展提供 |
| "Prompt Builder" 简单拼接 | "Context Compiler" + Context IR 编译过程 |
| 复用 SillyTavern 作为内核 | 从零实现；SillyTavern 至多作外围兼容层 |
| LLM 是状态机、Prompt 是输入 | LLM 是概率推理/表达模块；状态由外部运行时维护 |
| 状态变化=从历史重新生成 | 状态=事件驱动的演化(状态转移函数) |
| 把全部历史塞给 LLM | 数据库存全部历史,状态系统压缩后只给必要上下文 |
| PNG 角色卡是核心 | PNG 是资源/分发封装(非核心)；Engine > Project > Assets |
| "Character Runtime" | 提升为 "Simulation Runtime",角色只是世界一种实体 |
| eidolon-runtime 是唯一的运行时内核,容纳所有领域能力 | 运行时层 = 组合入口(eidolon-runtime)+ 多个能力子项目独立发版 |
| eidolon-character-service 是"服务层/消费层"(定位模糊,未获架构文档承认) | eidolon-character-service 是资产类型 X 的"运行时解释器":与格式层 X 成对、按需存在;组合入口只消费解释器,不直接 import 格式层 |
| "对话AI/动作AI/环境AI"各为独立AI | 表现层职责可由同一角色AI通过结构化输出完成；真正需分离的是角色认知vs世界运行 |
| 提示词按更新频率分层(单一维度) | 增加数据所有权维度:双维度模型(生命周期+所有权) |
| 上下文=压缩后的文本 | 上下文=Runtime根据Agent身份投影的数据视图 |
| AI负责创造剧情 | 程序负责真实性(决定发生什么),AI负责表现力(如何表达) |
| 剧情是固定分支树 | 剧情是事件图(Event Graph),条件触发,非阻塞 |
