# uv Workspace 管理规范

Eidolon 引擎采用 **[uv workspace](https://docs.astral.sh/uv/concepts/projects/workspaces/)** 管理多包子项目依赖。本文档说明选型理由、目录映射、以及日常操作规范。

## 1. 为什么用 uv workspace

Eidolon 是按引擎层级模型组织多独立子项目的生态——`format/` / `asset-types/` / `runtime/` / `editor/` 四个层级，各子项目独立包名（`personaseed` / `eidolon-character` / `eidolon-runtime` / `eidolon-studio`），彼此有依赖关系。

uv workspace 天然匹配这个结构：

| 问题 | pip + requirements-local.txt | uv workspace |
|------|------------------------------|-------------|
| 兄弟库依赖声明 | 外挂 `requirements-local.txt`（需手动在子目录执行） | `dependencies = ["personaseed"]` 直接写在 `pyproject.toml`，uv 自动在工作区内解析 |
| 版本锁定 | 无（各子项目各自为政） | `uv.lock` 在根目录统一锁定所有包的版本 |
| venv | 手动创建，策略靠文档约定 | `uv sync` 一步创建根 venv，所有子包 editable 安装在一起 |
| 安装步骤 | 3 步（`pip install -r requirements-local.txt` → `pip install -e .` → `pip install -r requirements.txt`） | 1 步（`uv sync`） |

## 2. 目录映射

```
Eidolon/                           ← 根 pyproject.toml（workspace root）
│
├── format/PersonaSeed/            ← member：包 personaseed（零依赖）
├── asset-types/eidolon-character/ ← member：包 eidolon-character（依赖 personaseed）
├── runtime/eidolon-runtime/       ← member：包 eidolon-runtime（依赖 personaseed + eidolon-character）
├── editor/eidolon-studio/         ← member：包 eidolon-studio（依赖 personaseed + eidolon-character）
│
├── pyproject.toml                 ← [tool.uv.workspace] members 列表
└── uv.lock                        ← 跨所有成员的统一锁定文件
```

依赖方向：`personaseed ← eidolon-character ← {eidolon-runtime, eidolon-studio}`

## 3. 日常操作

### 3.1 首次设置

```bash
cd Eidolon
uv sync --all-packages            # 创建 .venv、安装全部子项目（editable）+ PyPI 依赖
```

### 3.2 运行测试

```bash
uv run python -m unittest discover -s format/PersonaSeed/tests -t format/PersonaSeed
uv run python -m unittest discover -s asset-types/eidolon-character/tests -t asset-types/eidolon-character
uv run python -m unittest discover -s runtime/eidolon-runtime/tests -t runtime/eidolon-runtime
```

### 3.3 运行示例 / 服务

```bash
uv run python asset-types/eidolon-character/examples/make_and_read.py
uv run uvicorn runtime/eidolon-runtime/backend/main:app --reload --port 8000
uv run uvicorn editor/eidolon-studio/backend/main:app --reload --port 8000
```

### 3.4 新增 PyPI 依赖

在对应子项目的 `pyproject.toml` 中加到 `dependencies` 列表，然后：

```bash
uv sync --all-packages             # 自动更新 uv.lock
```

### 3.5 新增开发期工具

在仓库根目录 `pyproject.toml` 的 `[tool.uv].dev-dependencies` 中添加（如 `pytest`、`httpx`）：

```bash
uv sync --dev                     # 安装包含 dev-dependencies
```

## 4. 新增子项目（资产类型 / 引擎组件）

### 4.1 步骤

1. 在对应层级目录下创建新项目（如 `asset-types/eidolon-dialogue/`）
2. 编写 `pyproject.toml`，声明 `name`、`dependencies`
3. 如需依赖兄弟库，直接用包名声明（如 `dependencies = ["personaseed"]`），uv 自动在工作区内解析
4. 在根 `pyproject.toml` 的 `[tool.uv.workspace].members` 中添加一行
5. `uv sync --all-packages`

### 4.2 pyproject.toml 模板（新增资产类型）

```toml
[build-system]
requires = ["setuptools>=61.0"]
build-backend = "setuptools.build_meta"

[project]
name = "eidolon-dialogue"
version = "0.1.0"
description = "Eidolon 对话/剧情资产类型"
requires-python = ">=3.11"
dependencies = ["personaseed"]                    # 兄弟库直接写包名即可

[tool.setuptools.packages.find]
include = ["eidolon_dialogue*"]
```

### 4.3 pyproject.toml 模板（新增引擎组件 / 应用）

```toml
[project]
name = "eidolon-mind"
version = "0.1.0"
description = "Eidolon 人格系统：人格资产 + 训练 + 推理"
requires-python = ">=3.11"
dependencies = [
    "personaseed",
    "eidolon-character",
    "torch>=2.0",                                  # 重依赖只出现在应用层
]

[tool.setuptools]
packages = ["mind"]
```

## 5. venv 策略（uv 下的简化版）

原有 `docs/environment-isolation.md` 的层级规则依然有效（库项目零/轻依赖、应用层持有重依赖），
但在 uv workspace 下一个关键变化：**不再需要为每个应用单独创建 venv**。

uv 在仓库根目录统一创建 `.venv`，所有子包以 editable 方式安装于其中。
依赖解析器保证版本一致性，不会出现项目 A 要 `numpy<2`、项目 B 要 `numpy>=2` 的冲突。

如果某个子项目需要完全隔离的依赖环境（如上线部署），可在 CI / Docker 中只 `uv sync --package eidolon-runtime`，仅安装该包及其依赖链。

## 6. 与旧方案的对照

| 概念 | 旧方案 | uv workspace |
|------|--------|-------------|
| 兄弟库安装方式 | `requirements-local.txt` + `pip install -e` | `dependencies = ["包名"]` → `uv sync` |
| 导入方式 | 直接 `import personaseed`（通过 editable 安装） | 同，不变 |
| 不允许 | `sys.path.insert` 跨项目注入 | 同，更严格禁止 |
| 版本锁定 | 无 | `uv.lock` |
| 安装命令 | 3 步 | 1 步 |
