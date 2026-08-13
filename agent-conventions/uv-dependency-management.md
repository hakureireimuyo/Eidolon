# uv 依赖管理规范

Eidolon 生态的依赖管理:**每个仓库是独立 uv 项目**,兄弟库以 **git 源(pin rev)** 作为第三方依赖安装。本文档说明选型理由与日常操作。

## 1. 为什么用「独立项目 + git 源 pin rev」

多独立仓库(6 个)各自 remote、各自发布周期,依赖管理随之独立:

| 问题 | uv workspace(已弃用) | 独立项目 + git 源 |
|------|---------------------|-------------------|
| 单独 clone 服务仓库 | 无法安装(`workspace = true` 无父 workspace 报错) | `uv sync` 一步装齐 |
| 兄弟库依赖声明 | `workspace = true`(editable 路径) | `dependencies = ["cartridge"]` + `[tool.uv.sources]` git + rev |
| 版本锁定 | 根目录单 `uv.lock` | 各仓 `uv.lock`(git rev 已锁死) |
| 跨仓本地改动即时生效 | 是(editable) | 否——需 commit + push + 更新 rev |

> **代价**:跨仓改动必须 commit + push + 更新消费方 rev 才能被看到(流程见
> [docs/multi-machine-development.md](../docs/multi-machine-development.md) §5)。
> uv 层面 workspace 成员与 git 源互斥,二者不可混用。

## 2. 日常操作

### 2.1 安装 / 更新依赖

```bash
cd <仓库目录>          # 如 runtime/eidolon-runtime
uv sync               # 创建 .venv 并安装依赖(含 dev extra)
```

### 2.2 运行测试 / 服务

```bash
uv run python -m unittest discover -s tests -t .    # unittest 风格仓
uv run pytest tests/                                # pytest 风格仓
bash scripts/start.sh                               # 应用 / 服务仓(runtime / studio)
```

### 2.3 新增 PyPI 依赖

在对应仓库 `pyproject.toml` 的 `dependencies`(或 dev extra)中添加,然后 `uv sync`(自动更新该仓 `uv.lock`)。

### 2.4 新增兄弟库依赖

```toml
[project]
dependencies = ["cartridge"]

[tool.uv.sources]
cartridge = { git = "ssh://git@github.com:hakureireimuyo/cartridge.git", rev = "<40位commit SHA>" }
```

rev 取库仓的完整 commit SHA(`git -C <库仓> rev-parse HEAD`),与顶层子模块指针同源更新。

## 3. 新子项目接入

流程见 [docs/git-repository-management.md](../docs/git-repository-management.md) §8;
消费方声明依赖按 §2.4 模板;库仓自身依赖兄弟库时同样写 git 源。

## 4. venv 策略

各仓库独立 `.venv`(应用 / 服务仓持有,已 gitignore);库项目零 / 轻依赖,不持有 venv。
详见 [docs/environment-isolation.md](../docs/environment-isolation.md)。
