# 独立项目职责与能力边界

> 本文档说明 Eidolon 生态下每个独立 Git 仓库（子项目）**负责什么、不负责什么**，以及它们之间的协作边界。
> 仓库管理策略见 [`git-repository-management.md`](./git-repository-management.md)。

## 1. 总览

Eidolon 采用**多独立仓库**架构：每个子项目从第一天起就拥有自己的仓库，独立演进、独立版本、独立发布。这种拆分的根本原则是：

- **协议层与扩展层分离**（设计约定规范 13/15）
- **纯数据层与运行时分离**（PersonaSeed 只封装/访问，绝不运行/推理）
- **规范与实现分离**（每个项目内 `docs/` 与代码分离，为多语言 SDK 留空间）
- **能力边界靠"不做什么"来界定**——边界清晰比功能多更重要

## 2. 层级模型

各项目按"从哑到聪"分成三层，越往下越贴近字节、越往上越贴近智能：

```
┌─────────────────────────────────────────────────────────────┐
│ 运行时层（未来）                                              │
│   eidolon-runtime   消费 Package，解释各模块，驱动角色行为       │
│   eidolon-mind     人格网络的设计 / 训练 / 推理                │
│   eidolon-world    世界状态、多角色生态模拟                    │
├─────────────────────────────────────────────────────────────┤
│ 扩展层（具体数据模块）                                         │
│   eidolon-character  定义 character.json 格式 + 消费方参考实现   │
│   （未来：personality / memory / ... 模块，各自独立项目）        │
├─────────────────────────────────────────────────────────────┤
│ 协议层（数据容器）                                             │
│   PersonaSeed  封装 / 索引 / 校验 / 迁移 —— 不关心数据内容      │
└─────────────────────────────────────────────────────────────┘

       Eidolon（顶层仓库）：仅做聚合 + 共享文档，不含子项目代码
```

**关键认知**：`PersonaSeed` 之所以是合格的底层容器，恰恰是因为它"不关心任何数据语义"——它只认识"包里有若干数据块，每块有 ID、类型标签、路径、字节"。所有"这块是角色 / 那块是立绘"的含义判断，都发生在扩展层与运行时层。

## 3. 各项目详解

### 3.1 PersonaSeed（协议层 / 数据容器）

| 项 | 内容 |
|----|------|
| 定位 | Eidolon 生态的**底层数据容器协议** |
| 仓库 | `Eidolon/PersonaSeed/`（独立仓库） |
| 职责 | 定义**如何封装、描述、校验、传输**数据包 |

**负责（✅）**
- 容器格式：标准包 `.seed`（纯 ZIP）+ 分发镜像 `.png`（封面图内嵌 cPKG）
- 清单规范 `manifest.json`：声明包内数据块（entries）与资源（resources）
- 模块系统：通用的数据块注册 / 发现机制（协议无知的 `{id, type, path, data}`）
- 数据访问接口：`open() → Package` 统一封装所有解析细节
- 资源管理：资源字节的索引、提取、完整性（integrity 哈希）
- 版本迁移基础设施

**不负责（❌）**
- 不知道什么是"角色""人格""记忆"——`type: "character"` 与 `type: "pokemon-system"` 对它毫无区别
- 不封装任何具体业务数据格式（character.json 等由扩展层定义）
- 不做任何运行、推理、执行（纯数据层）

**核心 API（V1 参考实现，零外部依赖）**
`open()` · `write_seed()` · `write()` · `validate()` · `is_persona_seed()` · `inspect()` · `extract_resources()` · `build_integrity()`

---

### 3.2 eidolon-character（扩展层 / 角色身份模块）

| 项 | 内容 |
|----|------|
| 定位 | Eidolon 的**角色身份模块**——扩展规范 + 零依赖参考消费实现 |
| 仓库 | `Eidolon/eidolon-character/`（独立仓库，与 PersonaSeed 并列） |
| 职责 | 定义角色身份数据格式，并把 PersonaSeed 交付的数据块解析为类型化角色对象 |

**负责（✅）**
- 定义角色身份数据格式 `character.json`（canonical 规范在 `docs/character-schema.md` + `character.schema.json`）
- 消费方参考实现：解析 + 严格校验 `character` 数据块（`from_dict` / `from_package`）
- **资源语义声明**：通过可扩展的 `assets[]` 字段声明"哪张图是立绘 / 头像"（只存含义，不存字节）
- **友好组装入口** `builder`：`build_package(character, images) → personaseed.Package`，把角色对象 + 图片源粘成 PersonaSeed 包（生产侧，唯一耦合 personaseed 之处）
- **资源解析器** `reader`：`resolve_asset_bytes(pkg, id)` 等，按资源 id 取回字节（消费侧）

**不负责（❌）**
- 不封装 / 传输字节（那是 PersonaSeed 的职责——图像落到 `resources/`，由 manifest 登记）
- 不做任何运行、推理、执行（那是 Runtime 的职责）
- 不含运行时状态（信任度、情绪、对话历史等属于 Runtime / Mind）
- 不预先定义 personality / memory 等其他模块（它们应各自独立成项目）

**核心 API（V1 参考实现，零外部依赖）**
`from_dict()` · `from_package()` · `from_package_with_assets()` · `to_dict()` · `Character` / `CharacterAsset` ·
`builder.build_package()` / `build_seed()` / `build_png()` · `reader.resolve_asset_bytes()` / `resolve_assets()`

> 核心消费 API（`from_package` 等）通过**鸭子类型**契约接入 PersonaSeed `Package`，不硬性 import personaseed；只有生产侧的 `builder` 才直接依赖。`assets[]` 故意不枚举 `purpose`，保持可扩展性。

---

### 3.3 Eidolon 顶层仓库（聚合与文档）

| 项 | 内容 |
|----|------|
| 定位 | 顶层仓库，**不包含任何子项目代码** |
| 仓库 | `Eidolon/`（独立仓库） |

**负责（✅）**
- 以 submodule 形式聚合各子项目、固定其版本（gitlink）
- 存放**跨项目的共享文档**（`docs/`：本文件、`git-repository-management.md`）
- 作为生态的统一入口 / README

**不负责（❌）**
- 不实现任何协议、模块或运行时逻辑
- 不把子项目代码直接纳入跟踪（仅记录 gitlink）

---

### 3.4 eidolon-runtime（运行时层 · 未来）

| 项 | 内容 |
|----|------|
| 定位 | 消费 PersonaSeed 包、解释各模块、驱动角色行为 |
| 仓库 | `Eidolon/eidolon-runtime/`（未来，独立仓库） |

**预期负责（规划中）**
- 加载 `.seed` / `.png`，用 `eidolon-character` 等扩展解析出类型化对象
- 维护运行时状态（对话历史、情绪、信任度等模板之外的可变状态）
- 驱动角色的对话 / 行为

**不负责（规划）**
- 不重新定义数据格式（那是扩展层的职责）
- 不负责数据封装 / 传输（那是 PersonaSeed 的职责）

---

### 3.5 eidolon-mind（人格层 · 未来）

| 项 | 内容 |
|----|------|
| 定位 | 人格网络的设计 / 训练 / 推理 |
| 仓库 | `Eidolon/eidolon-mind/`（未来，独立仓库） |

**预期负责（规划中）**
- `personality` 模块格式的扩展规范与实现
- 人格网络的结构、训练、演化、推理

**不负责（规划）**
- 不关心数据怎么封装（PersonaSeed）
- 不关心角色的身份静态字段（eidolon-character）

---

### 3.6 eidolon-world（世界层 · 未来）

| 项 | 内容 |
|----|------|
| 定位 | 世界状态与多角色生态模拟 |
| 仓库 | `Eidolon/eidolon-world/`（未来，独立仓库） |

**预期负责（规划中）**
- 世界数据模块格式
- 多角色生态、环境状态模拟

**不负责（规划）**
- 不定义单角色身份（eidolon-character）
- 不定义数据载体（PersonaSeed）

## 4. 能力边界矩阵

| 能力 \ 项目 | PersonaSeed | eidolon-character | eidolon-runtime* | eidolon-mind* | eidolon-world* |
|------------|:-----------:|:-----------------:|:----------------:|:-------------:|:--------------:|
| 封装 / 传输数据 | ✅ | ❌ | ❌ | ❌ | ❌ |
| 校验数据完整性 | ✅ | ❌ | ❌ | ❌ | ❌ |
| 定义 character.json | ❌ | ✅ | ❌ | ❌ | ❌ |
| 资源**语义**声明 (assets[]) | ❌ | ✅ | ❌ | ❌ | ❌ |
| 资源**字节**存储 | ✅ | ❌ | ❌ | ❌ | ❌ |
| 解析 / 校验模块数据 | ✅(通用) | ✅(角色) | ✅(消费) | ✅(人格) | ✅(世界) |
| 运行时状态 / 推理 | ❌ | ❌ | ✅ | ✅ | ✅ |
| 多语言 SDK 支撑 | ✅(规范分离) | ✅(规范分离) | — | — | — |

\* 规划中，尚未创建。

## 5. 资源所有权分层（重要裁决）

图像等资源数据存在"两副面孔"——**存储机制**与**语义**，二者归属不同项目：

| 维度 | 归属 | 说明 |
|------|------|------|
| 资源**字节**的存储机制（落盘位置、`resources/` 寻址、manifest 登记、完整性） | **PersonaSeed** | 协议无知的哑容器，存 PNG/JPEG/任意 blob 都一个样 |
| 资源**语义**（哪张是立绘、哪张是头像） | **eidolon-character** | 通过 `assets[]`（`id` 引用 PersonaSeed 资源，`type`/`purpose`/`caption` 可选可扩展）声明 |

因此上层消费方**只跟 eidolon-character 打交道**：
- 生产者用 `eidolon_character.builder.build_package(character, images)` 组装——字节交给 PersonaSeed，语义留在 character.json
- 消费者用 `from_package_with_assets(pkg)` + `resolve_asset_bytes(pkg, id)` 取回字节

PersonaSeed 始终"不关心任何数据语义"，同时又是唯一的底层容器——二者并不矛盾。

## 6. 跨项目交互原则

1. **类型路由靠 MIME 标签**。PersonaSeed 用 `type` 字段（MIME 风格，如 `application/x-eidolon-character`）标识数据块类型；扩展层用该标签声明自己在 manifest 中的注册方式。
2. **消费侧鸭子类型，不硬依赖**。eidolon-character 的 `from_package(pkg)` 只要求 `pkg.entries` 为 `{id: Entry}`、Entry 含 `.data: bytes` 与 `.type: str`，不直接 `import personaseed`。
3. **生产侧可显式耦合**。`builder` 主动 `import personaseed` 调用 `Package/Entry`——这是故意的单一耦合点，便于上层完全避免感知 PersonaSeed 存储细节。
4. **资源 id 命名约定**（`res:<name>` 形式）由扩展层决定，PersonaSeed 仅按字符串透传。
5. **版本独立**。各子项目自有版本号；跨项目兼容通过 submodule pin + PersonaSeed 的迁移层保障（见 git 文档 §7）。

## 7. 当前状态

| 仓库 | 状态 | 位置 | 已实现核心 |
|------|------|------|-----------|
| Eidolon（顶层） | 已初始化 | `Eidolon/` | 聚合 + 共享文档 |
| PersonaSeed | 独立仓库（已提交） | `Eidolon/PersonaSeed/` | 协议规范 + V1 零依赖工具集（10 测试全绿） |
| eidolon-character | 独立仓库（已提交） | `Eidolon/eidolon-character/` | 角色 schema + V1 零依赖消费方 + builder/解析器（13 测试全绿） |
| eidolon-runtime | 未来 | `Eidolon/eidolon-runtime/` | — |
| eidolon-mind | 未来 | `Eidolon/eidolon-mind/` | — |
| eidolon-world | 未来 | `Eidolon/eidolon-world/` | — |

> 本地开发阶段，子项目在顶层 `.gitignore` 中被忽略；待远程仓库就绪后，按 `git-repository-management.md` 改为正式 submodule 关联。
