# Git 仓库管理

## 1. 决策：多独立仓库，从项目之初即拆分

Eidolon 生态采用**多独立 Git 仓库**架构，各子项目从一开始就拥有自己独立的仓库，而非在单一 Monorepo 中开发后再拆分。

### 理由

- Eidolon 下的子项目（PersonaSeed、Runtime、Mind 等）职责边界清晰，各自独立演进
- 独立的仓库意味着独立的版本号、独立的发布周期、独立的 Issue/PR 管理
- 从第一天就学习管理嵌套仓库，避免后期拆分的迁移成本
- 外部使用者可以只引用需要的子项目，无需拉取整个生态的代码

## 2. 项目层级

```
Eidolon/                          ← 顶层仓库（聚合与文档）
│
├── PersonaSeed/                  ← 独立 Git 仓库（数据容器协议）
├── eidolon-character/            ← 独立 Git 仓库（角色身份模块：扩展规范 + 参考实现）
├── eidolon-runtime/              ← 独立 Git 仓库（未来）
├── eidolon-mind/                 ← 独立 Git 仓库（未来）
├── eidolon-world/                ← 独立 Git 仓库（未来）
│
├── docs/                         ← 顶层共享文档（本文件所在）
├── examples/                     ← 示例角色（可独立或随 PersonaSeed）
└── README.md
```

## 3. 嵌套 Git 的工作原理

当外层仓库中嵌套内层仓库时，Git 的默认行为是：

```bash
# 外层仓库执行 git status
# 内层仓库目录不会列出其内部文件变化
# 外层只记录一个 gitlink —— 指向内层仓库的某个 commit
```

外层 Git 把内层仓库目录视为一个特殊的条目（gitlink），只记录：
```
PersonaSeed/ → commit a1b2c3d4
```

这意味着：
- 外层不知道内层仓库里有什么文件
- 外层不跟踪内层仓库的文件变更
- 外层只记录"当前使用的是内层仓库的哪个版本"

这正是 Submodule 的底层机制。

## 4. 管理方式：Git Submodule

使用 Git Submodule 正式管理嵌套关系：

```bash
# 在 Eidolon 仓库中添加子项目
cd Eidolon
git submodule add <repo-url> PersonaSeed
git submodule add <repo-url> eidolon-runtime

# 提交
git commit -m "Add PersonaSeed and Runtime as submodules"
```

执行后会生成 `.gitmodules` 文件：

```
[submodule "PersonaSeed"]
    path = PersonaSeed
    url = https://github.com/xxx/persona-seed.git

[submodule "eidolon-runtime"]
    path = eidolon-runtime
    url = https://github.com/xxx/eidolon-runtime.git
```

## 5. 日常操作

### 克隆带 Submodule 的仓库

```bash
# 克隆时一并拉取子模块
git clone --recurse-submodules <eidolon-repo-url>

# 或先克隆再初始化
git clone <eidolon-repo-url>
cd Eidolon
git submodule update --init --recursive
```

### 更新子模块到最新版本

```bash
# 拉取子模块的远程更新
cd PersonaSeed
git pull origin main
cd ..
git add PersonaSeed
git commit -m "Update PersonaSeed to latest"
```

### 在子模块中开发

```bash
cd PersonaSeed
# 正常进行开发、提交、推送
git checkout -b feature/xxx
# ... 修改代码 ...
git add .
git commit -m "Add feature xxx"
git push origin feature/xxx
```

外层仓库不受影响——它仍然指向之前的 commit。当子模块的改动稳定后，再更新外层指向：

```bash
cd Eidolon
git add PersonaSeed
git commit -m "Bump PersonaSeed to v1.1"
```

## 6. 版本固定

外层仓库固定子模块的版本，保证环境可复现：

```
# 外层仓库记录：
PersonaSeed @ commit a1b2c3d4  (v1.0)
eidolon-runtime @ commit e5f6g7h8  (v0.5)

# 一个月后 PersonaSeed 更新到 v1.1 (commit i9j0k1l2)
# 但外层仓库仍然指向 a1b2c3d4
# 除非主动更新 —— 这保证了依赖的稳定性
```

这与 `package.json` 锁定依赖版本、`requirements.txt` 固定包版本的思路一致。

## 7. 跨项目版本兼容

各子项目独立定义自己的版本号（如 PersonaSeed 的 `manifest.version`），消费方通过以下方式保证兼容：

```
Eidolon Runtime v1.0
    ├── 依赖 PersonaSeed @ v1.0  (submodule pin)
    └── 能读取 PersonaSeed format V1 的角色包
```

当 PersonaSeed 格式升级到 V2 时：
- PersonaSeed 工具集提供 V1→V2 迁移
- Eidolon Runtime 可选择更新 submodule 指向新版本
- 旧角色包（V1 格式）仍可通过迁移层读取

## 8. 当前状态

| 仓库 | 状态 | 位置 |
|------|------|------|
| Eidolon (顶层) | 已初始化 | `D:/Dev/Projects/Python/Eidolon/` |
| PersonaSeed | 独立仓库（已提交） | `Eidolon/PersonaSeed/` |
| eidolon-character | 独立仓库（已提交） | `Eidolon/eidolon-character/` |
| Eidolon Runtime | 未来 | `Eidolon/eidolon-runtime/` |
| Eidolon Mind | 未来 | `Eidolon/eidolon-mind/` |

## 9. 初始化步骤

```bash
# 1. 初始化 PersonaSeed 为独立仓库
cd D:/Dev/Projects/Python/Eidolon/PersonaSeed
git init
git add .
git commit -m "Initial commit: PersonaSeed format specification"
# 关联远程仓库后推送

# 2. 初始化 Eidolon 顶层仓库
cd D:/Dev/Projects/Python/Eidolon
# 先将 PersonaSeed/ 移出或确认远程仓库已存在
git init
# 添加 .gitmodules 和 submodule
git submodule add <persona-seed-remote-url> PersonaSeed
git add .
git commit -m "Initial commit: Eidolon project structure"
```

> 注意：初始化 submodule 前，子项目需已有远程仓库 URL。本地开发阶段可先在子目录中独立使用 Git，待远程仓库就绪后再建立 submodule 关系。
