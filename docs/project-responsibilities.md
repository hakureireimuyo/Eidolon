# 独立项目职责与能力边界

> 本文档说明 Eidolon 引擎生态下每个独立 Git 仓库（子项目）**负责什么、不负责什么**，以及它们之间的协作边界。
> 仓库管理策略见 [`git-repository-management.md`](./git-repository-management.md)；资源存储与跨项目集成机制见 [`resource-management.md`](./resource-management.md)。

## 1. 总览

Eidolon 是一个**数字实体引擎**生态，采用**多独立仓库**架构：每个子项目从第一天起就拥有自己的仓库，独立演进、独立版本、独立发布。拆分的根本原则与任何成熟游戏引擎一致：

- **序列化格式层与资产类型系统分离**——序列化层只记录"有一个资产，类型标签是 X"，不解释内容
- **纯数据层与引擎运行时分离**——PersonaSeed 只序列化/访问，绝不运行/推理
- **规范与实现分离**——每个项目内 `docs/` 与代码分离，为多语言 SDK 留空间
- **能力边界靠"不做什么"来界定**——边界清晰比功能多更重要

### 游戏引擎类比

如果你熟悉 Unity 或 Unreal，这里有一个自然的对照：

```
Unity 引擎生态                    Eidolon 引擎生态
──────────────                   ──────────────
.unity / .prefab 文件            .seed 资产包
MonoBehaviour / Script           character / personality / ... 资产类型
Unity Runtime                     eidolon-runtime（引擎运行时）
Unity Editor                      eidolon-studio（引擎编辑器）
Asset Store                      （未来的资产市场）
```

## 2. 层级模型

各项目按"从序列化到执行"分成四层：

```
┌─────────────────────────────────────────────────────────────┐
│ 编辑器层（未来）                                               │
│   eidolon-studio  可视化统一资产操作：角色创建 / 修改 / 导出     │
├─────────────────────────────────────────────────────────────┤
│ 引擎运行时                                                    │
│   eidolon-runtime   加载资产包，按 type 标签路由，驱动角色行为    │
│   eidolon-mind     人格资产类型的设计 / 训练 / 推理              │
│   eidolon-world    世界资产类型、多角色生态模拟                  │
├─────────────────────────────────────────────────────────────┤
│ 资产类型系统（具体资产种类）                                     │
│   eidolon-character  定义 character 资产格式 + 解析器实现         │
│   （未来：personality / memory / ... 资产，各自独立项目）        │
├─────────────────────────────────────────────────────────────┤
│ 资产序列化格式（引擎项目文件格式）                                │
│   PersonaSeed  存储 / 索引 / 校验 / 迁移 —— 不关心资产内容       │
└─────────────────────────────────────────────────────────────┘

       Eidolon（顶层仓库）：仅做聚合 + 共享文档，不含子项目代码
```

**关键认知**：`PersonaSeed` 之所以是合格的底层格式，恰恰是因为它"不关心任何资产语义"——它只认识"包里有若干数据块，每块有 ID、类型标签、路径、字节"。所有"这块是角色 / 那块是立绘"的含义判断，都发生在资产类型系统与引擎运行时中。这与 Unity 的文件格式不关心你的 C# 脚本写了什么是同一个原则。

## 3. 各项目详解

### 3.1 PersonaSeed（资产序列化格式 / 引擎项目文件格式）

| 项 | 内容 |
|----|------|
| 定位 | Eidolon 引擎的**项目文件格式**——定义资产的序列化、索引、校验和传输 |
| 仓库 | `Eidolon/PersonaSeed/`（独立仓库） |

**引擎类比**：PersonaSeed 之于 Eidolon，如同 `.unity` / `.prefab` 格式之于 Unity——它是引擎可以加载、保存、校验、迁移的项目文件。

**负责（✅）**
- 容器格式：标准包 `.seed`（纯 ZIP）+ 分发镜像 `.png`（封面图内嵌 cPKG）
- 清单 `manifest.json`：声明包内资产数据块（entries）与资源（resources）
- 资产注册系统：通用的数据块注册 / 发现机制（无资产语义的 `{id, type, path, data}`）
- 数据访问接口：`open() → Package` 统一封装所有解析细节
- 资源管理：资源字节的索引、提取、完整性（integrity 哈希）
- 版本迁移基础设施

**不负责（❌）**
- 不知道什么是"角色""人格""记忆"——`type: "character"` 与 `type: "pokemon-system"` 对它毫无区别
- 不封装任何具体资产类型的数据格式（character.json 等由资产类型系统定义）
- 不做任何运行、推理、执行（纯序列化层）

**核心 API（V1 参考实现，零外部依赖）**
`open()` · `write_seed()` · `write()` · `validate()` · `is_persona_seed()` · `inspect()` · `extract_resources()` · `build_integrity()`

---

### 3.2 eidolon-character（资产类型系统 / 角色资产）

| 项 | 内容 |
|----|------|
| 定位 | Eidolon 引擎的**角色资产类型**——Schema + 零依赖参考解析器实现 |
| 仓库 | `Eidolon/eidolon-character/`（独立仓库，与 PersonaSeed 并列） |

**引擎类比**：就像 Unity 的 `Transform`、`MeshRenderer` 是引擎内置的组件类型，`character` 是 Eidolon 引擎的一种资产类型——它定义了自己字段的 Schema，并提供了从序列化数据还原出运行时对象的解析器。

**负责（✅）**
- 定义角色资产数据格式 `character.json`（canonical 规范在 `docs/character-schema.md` + `character.schema.json`）
- 解析器实现：解析 + 严格校验 `character` 资产数据块（`from_dict` / `from_package`）
- **资源语义声明**：通过可扩展的 `assets[]` 字段声明"哪张图是立绘 / 头像"（只存含义，不存字节）
- **友好组装入口** `builder`：`build_package(character, images) → personaseed.Package`，把角色对象 + 图片源粘成 PersonaSeed 资产包（生产侧，唯一耦合 personaseed 之处）
- **资源解析器** `reader`：`resolve_asset_bytes(pkg, id)` 等，按资源 id 取回字节（消费侧）

**不负责（❌）**
- 不封装 / 传输字节（那是 PersonaSeed 的职责——图像落到 `resources/`，由 manifest 登记）
- 不做任何运行、推理、执行（那是引擎运行时的职责）
- 不含运行时状态（信任度、情绪、对话历史等属于引擎运行时 / Mind）
- 不预先定义 personality / memory 等其他资产类型（它们应各自独立成项目）

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
- 作为引擎生态的统一入口 / README

**不负责（❌）**
- 不实现任何序列化、资产类型或引擎逻辑
- 不把子项目代码直接纳入跟踪（仅记录 gitlink）

---

### 3.4 eidolon-runtime（引擎运行时 · 已启动）

| 项 | 内容 |
|----|------|
| 定位 | Eidolon 引擎的**运行时核心**——加载资产包、按 type 标签路由、驱动角色行为 |
| 仓库 | `Eidolon/eidolon-runtime/`（独立仓库） |

**引擎类比**：这是 Unity Runtime——它知道如何打开 `.unity` 文件，遍历所有 GameObject 和 Component，调用它们的 `Update()`。对 Eidolon 来说，它知道如何打开 `.seed`，遍历所有资产数据块，按 type 标签路由到对应解析器，驱动对话/行为。

**负责（✅）**
- 加载 `.seed` / `.png` 资产包，用 `eidolon-character` 等资产类型解析出类型化对象
- 维护运行时状态（对话历史、情绪、信任度等模板之外的可变状态）
- 按 `type` 标签路由数据块到对应的资产解析器
- 驱动角色的对话 / 行为（当前 V1：基础一问一答）

**不负责（❌）**
- 不重新定义资产数据格式（那是资产类型系统的职责）
- 不负责资产序列化 / 传输（那是 PersonaSeed 的职责）

---

### 3.5 eidolon-mind（人格系统 · 未来）

| 项 | 内容 |
|----|------|
| 定位 | **人格资产类型** + 人格网络的训练 / 推理 |
| 仓库 | `Eidolon/eidolon-mind/`（未来，独立仓库） |

**负责（规划中）**
- `personality` 资产类型的格式规范与实现
- 人格网络的结构、训练、演化、推理

**不负责（规划）**
- 不关心资产数据怎么序列化（PersonaSeed）
- 不关心角色的身份静态字段（eidolon-character）

---

### 3.6 eidolon-world（世界系统 · 未来）

| 项 | 内容 |
|----|------|
| 定位 | **世界资产类型** + 多角色生态模拟 |
| 仓库 | `Eidolon/eidolon-world/`（未来，独立仓库） |

**负责（规划中）**
- 世界资产的数据格式
- 多角色生态、环境状态模拟

**不负责（规划）**
- 不定义单角色身份（eidolon-character）
- 不定义资产序列化格式（PersonaSeed）

---

### 3.7 eidolon-studio（引擎编辑器 · 未来）

| 项 | 内容 |
|----|------|
| 定位 | Eidolon 引擎的**可视化编辑器**——面向使用者的统一资产编辑入口 |
| 仓库 | `Eidolon/eidolon-studio/`（未来，独立仓库） |

**引擎类比**：这是 Unity Editor——可视化的资产创建、编辑、预览、打包和分发。它消费所有底层能力，但自己不重新发明它们。

**负责（规划中）**
- 可视化角色创建 / 修改 / 导出
- 统一的资源（图片、音频、未来数据）上传与管理
- 一站式打包、预览、分发（`.seed` / `.png`）

**不负责（规划）**
- 不重新定义资产数据格式（那是资产类型系统的职责）
- 不重复实现容器逻辑（那是 PersonaSeed 的职责）
- 不做运行 / 推理（那是引擎运行时 / 人格系统的职责）

> 开发阶段刻意将各项目分开，正是为了让编辑器层未来能"即插即用地"复用每一块底层能力。底层格式与资产类型保持独立、可单独复用，编辑器只是它们的图形化合集。详见 [`resource-management.md` §5](./resource-management.md)。

## 4. 能力边界矩阵

| 能力 \ 项目 | PersonaSeed | eidolon-character | eidolon-runtime | eidolon-mind* | eidolon-world* | eidolon-studio* |
|------------|:-----------:|:-----------------:|:---------------:|:-------------:|:--------------:|:---------------:|
| 资产序列化 / 传输 | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| 校验数据完整性 | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| 定义 character 资产 | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| 资源**语义**声明 (assets[]) | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| 资源**字节**存储 | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| 解析 / 校验资产数据 | ✅(通用) | ✅(角色) | ✅(消费) | ✅(人格) | ✅(世界) | ❌(委托底层) |
| 运行时状态 / 推理 | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ |
| 可视化资产编辑 UI | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| 多语言 SDK 支撑 | ✅(规范分离) | ✅(规范分离) | — | — | — | — |

\* 规划中。

## 5. 资源所有权分层（重要裁决）

图像等资源数据存在"两副面孔"——**存储机制**与**语义**，二者归属不同项目：

| 维度 | 归属 | 说明 |
|------|------|------|
| 资源**字节**的存储机制（落盘位置、`resources/` 寻址、manifest 登记、完整性） | **PersonaSeed** | 无资产语义的哑容器，存 PNG/JPEG/任意 blob 都一个样 |
| 资源**语义**（哪张是立绘、哪张是头像） | **eidolon-character** | 通过 `assets[]`（`id` 引用 PersonaSeed 资源，`type`/`purpose`/`caption` 可选可扩展）声明 |

因此引擎上层消费方**只跟 eidolon-character 打交道**：
- 生产者用 `eidolon_character.builder.build_package(character, images)` 组装——字节交给 PersonaSeed，语义留在 character.json
- 消费者用 `from_package_with_assets(pkg)` + `resolve_asset_bytes(pkg, id)` 取回字节

PersonaSeed 始终"不关心任何资产语义"，同时又是唯一的底层序列化格式——二者并不矛盾。

## 6. 跨项目交互原则

1. **资产路由靠 MIME 标签**。PersonaSeed 用 `type` 字段（MIME 风格，如 `application/x-eidolon-character`）标识资产类型；各资产类型用该标签声明自己在 manifest 中的注册方式。这是引擎的类型路由基础设施。
2. **消费侧鸭子类型，不硬依赖**。eidolon-character 的 `from_package(pkg)` 只要求 `pkg.entries` 为 `{id: Entry}`、Entry 含 `.data: bytes` 与 `.type: str`，不直接 `import personaseed`。
3. **生产侧可显式耦合**。`builder` 主动 `import personaseed` 调用 `Package/Entry`——这是故意的单一耦合点，便于上层完全避免感知 PersonaSeed 存储细节。
4. **资源 id 命名约定**（`res:<name>` 形式）由资产类型决定，PersonaSeed 仅按字符串透传。
5. **版本独立**。各子项目自有版本号；跨项目兼容通过 submodule pin + PersonaSeed 的迁移层保障（见 git 文档 §7）。

## 7. 当前状态

| 仓库 | 状态 | 位置 | 已实现核心 |
|------|------|------|-----------|
| Eidolon（顶层） | 已初始化 | `Eidolon/` | 聚合 + 共享文档 |
| PersonaSeed | 独立仓库（已提交） | `Eidolon/PersonaSeed/` | 引擎项目文件格式规范 + V1 零依赖工具集（10 测试全绿） |
| eidolon-character | 独立仓库（已提交） | `Eidolon/eidolon-character/` | char 资产 Schema + V1 零依赖解析器（13 测试全绿） |
| eidolon-runtime | 已启动 | `Eidolon/eidolon-runtime/` | 引擎运行时 V1：加载角色卡 + AI 对话 |
| eidolon-mind | 未来 | `Eidolon/eidolon-mind/` | — |
| eidolon-world | 未来 | `Eidolon/eidolon-world/` | — |
| eidolon-studio | 未来 | `Eidolon/eidolon-studio/` | — |

> 本地开发阶段，子项目在顶层 `.gitignore` 中被忽略；待远程仓库就绪后，按 `git-repository-management.md` 改为正式 submodule 关联。
