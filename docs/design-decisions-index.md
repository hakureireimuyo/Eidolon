# 设计决策总览索引（运行时 / 世界 / 多智能体方向）

> 本目录汇集 2026-08-10 设计对话中**最终确定下来的观点与理念**（已删除被推翻的方案与过渡讨论），按知识域分类，供后续 eidolon-runtime / eidolon-mind / eidolon-world 等未来层参考。
> 前置约定：[独立项目职责与能力边界](./project-responsibilities.md) · [资源管理与跨项目集成](./resource-management.md) · [Agent 设计规范](../agent-conventions/design-document-conventions.md)

## 文档导航

| 文档 | 知识域 | 一句话 |
|------|--------|--------|
| [核心架构哲学与项目定位](./design-philosophy.md) | 全局哲学 | Eidolon 是叙事/模拟运行时，LLM 是表现层不是大脑，从零实现 |
| [数据容器与项目工程层](./data-container-project-layer.md) | 数据层 | 数据容器=世界工程数据层；源数据模型无关；Engine>Project>Assets |
| [运行时核心设计](./runtime-core-design.md) | 运行时 | 内核极小且领域无知；事件驱动+Processor；共享状态非共享 Prompt |
| [状态模型、上下文管理与缓存](./state-and-context.md) | 状态/上下文 | 状态与上下文分离；状态演化；频率分层；Context Compiler；事件溯源 |
| [剧情 / 世界 / 叙事引擎](./narrative-world-engine.md) | 世界/叙事 | 剧情=动态世界；事件/规则驱动；多路线规则生成；剧情包即插件 |
| [多智能体与多模态系统](./multi-agent-multimodal.md) | 多智能体 | 多 Agent 围绕共享状态；生成模型由状态触发；生成物是状态投影 |
| [模型选型与本地验证](./model-selection-validation.md) | 模型/验证 | LLM 可替换；小模型验证架构；本地硬件指导 |

## 被推翻的观点 → 最终决定（本次整理已剔除推翻部分）

| 被推翻（已删除） | 最终决定（保留） |
|------------------|------------------|
| Runtime 做成集中式"大脑"（领域逻辑全塞进内核） | 内核极小且领域无知，领域逻辑由 Processor/扩展提供 |
| "Prompt Builder" 简单拼接 | "Context Compiler" + Context IR 编译过程 |
| 复用 SillyTavern 作为内核 | 从零实现；SillyTavern 至多作外围兼容层 |
| LLM 是状态机、Prompt 是输入 | LLM=概率推理/表达模块；状态由外部运行时维护 |
| 状态变化=从历史重新生成 | 状态=事件驱动的演化（状态转移函数） |
| 把全部历史塞给 LLM | 数据库存全部历史，状态系统压缩后只给必要上下文 |
| PNG 角色卡是核心 | PNG 是资源/分发封装（非核心）；Engine>Project>Assets |
| "Character Runtime" | 提升为 "Simulation Runtime"，角色只是世界一种实体 |
