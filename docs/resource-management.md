# 资源管理与跨项目集成模型

> 本文档定义 Eidolon 生态中**资源文件如何存储、各独立项目如何交互**，并给出"如何新增一种数据类型 / 模块"的明确步骤。是后续扩展的实操指南。
> 相关文档：[项目职责与能力边界](./project-responsibilities.md) · [Git 仓库管理](./git-repository-management.md)

## 1. 资源文件的存储位置

所有资源都装在**同一个 PersonaSeed 包**内（`.seed` = 纯 ZIP；`.png` = 封面图内嵌 cPKG 的分发镜像）。包内只有两个桶：

### 1.1 data/ —— 结构化数据块
- 每个块在 `manifest.entries` 登记一条：`{id, type, version, path, required, data}`。
- 角色 `character.json`、未来的 `personality.json` / `memory.json` 放这里。
- `type` 是 MIME 风格标签（如 `application/x-eidolon-character`），说明"谁拥有这段数据"。
- 进入 `data/` 的条件：它是某个扩展模块的**结构化数据**。

### 1.2 resources/ —— 不透明字节 blob
- 图片（png/jpg）、音频、模型权重、任意二进制，全部按原始字节存储，用包内路径做键，在 `manifest.resources` 登记。
- PersonaSeed 对它们**毫无语义认知**，只负责落盘、寻址、完整性（integrity）校验。

### 1.3 判断规则
| 资源 | 落点 | 说明 |
|------|------|------|
| 模块的**结构化数据**（character.json 等） | `data/`，带 type 的 entry | 有类型，谁拥有它一目了然 |
| 一坨要原样读写的配置 / 二进制 | `resources/`，当 blob | 无语义 |
| 图片 / 音频 / 权重 / 任意媒体 | **永远** `resources/`，当 blob | 字节交给容器，语义交给模块 |

## 2. 语义链接：含义靠"引用"而非"存放"

`resources/portrait.png` 在 PersonaSeed 眼中只是一堆字节。含义由模块的 `assets[]` 给出：

```
character.json
  assets: [{ id: "portrait", type: "image/png", purpose: "...", caption: "..." }]
            │  id 是逻辑名
            ▼  builder 组装时映射到真实路径
resources/portrait.png   (字节，PersonaSeed 不解释)
```

- **写入**：`builder.build_package(character, images)` 把逻辑 id 映射到 `resources/<name>.<ext>`，写字节、登记 manifest。
- **读取**：`resolve_asset_bytes(pkg, "portrait")` 走 `assets → 路径 → 字节`。
- `assets[]` 故意**不枚举** `purpose` 等字段，保持可扩展性（未来加语音、3D、权重都不用改 schema）。

## 3. 跨项目交互（三个极小接触点）

### 3.1 生产侧（写）—— 仅在 builder 跨一次界
eidolon-character 独占"组装"，`builder.build_package()` 是**唯一**构造 `personaseed.Package` 的地方，产出标准包后由 `seed.write_seed()/write()` 序列化。**跨出这一处后，文件是纯包，再读它不需要 eidolon-character 在场。**

### 3.2 消费侧（读）—— 靠 type 标签路由
PersonaSeed 交还通用 `Package`（无含义）。运行时遍历 `manifest.entries`，按 `type` 派发：
- `application/x-eidolon-character` → eidolon-character 的 `from_dict`
- `application/x-eidolon-personality`（未来）→ eidolon-mind
- ……

**完全解耦**：PersonaSeed 不 import 扩展模块；运行时持有 type→解析器 登记表；每个模块只暴露 `from_dict(data)`（+ 可选 `from_package`）。

### 3.3 共享容器，项目间不直接耦合
各模块不通过代码互调，只共享"包"。一个角色模块与未来记忆模块可共存于同一 `.seed`，各自占一条 entry，各自引用 `resources/` 中的共享 / 独立 blob；仅通过包结构 + 约定的 type 标签 + entry id 约定协作。

## 4. 如何新增一种数据类型 / 模块（实操步骤）

**无需改动 PersonaSeed**。新模块满足最小契约：

1. 新建独立仓库（沿用 `eidolon-*` 命名与 git 约定）
2. 编写 canonical 规范（`docs/` + JSON Schema）
3. 注册 namespaced `type` 标签（`application/x-eidolon-<x>`）
4. 提供 `from_dict(data)`（可选 `from_package`）
5. 可选提供 `builder` 做组装（生产侧）
6. 运行时加入**一条路由规则**

`type` 标签是整个解耦的铰链：协议层永远不关心内容，扩展层能精确认领数据。

## 5. 未来：可视化统一操作（Eidolon Studio）

当前开发阶段**刻意将各项目分开**（协议层 / 扩展层 / 运行时各自独立仓库），以便独立演进、独立版本。

但远期目标是：把"数据生成 / 编辑"相关的底层能力**统一收口到一个具备可视化操作的项目（暂定名 Eidolon Studio）**，作为面向使用者的统一入口，提供：

- 可视化角色创建 / 修改 / 导出
- 统一的资源（图片、音频、未来数据）上传与管理
- 一站式打包、预览、分发（`.seed` / `.png`）

在该架构下：

- **PersonaSeed + 各扩展模块（eidolon-character 等）是底层支持层** —— 负责格式定义与读写。
- **Eidolon Studio 是上层可视化壳** —— 消费底层能力，不重新定义数据格式，也不重复实现容器逻辑。
- 底层协议 / 模块保持独立、可单独复用；Studio 只是它们的"图形化合集"。

> 这与本生态"协议层 / 扩展层 / 运行时 / 使用者界面层"的分层一致：Studio 属于**使用者界面层**，建立在已定义的各层之上。开发阶段的分项目，正是为了让这层未来能"即插即用地"复用每一块底层能力。
