# Git 仓库管理

> 相关文档:[`project-responsibilities.md`](./project-responsibilities.md) —— 各独立项目的职责与能力边界。

## 1. 架构:6 个独立仓库 + Git Submodule

Eidolon 生态采用**多独立 Git 仓库**架构,通过 Git Submodule 在顶层仓库中组织。完整仓库清单与远程地址见 [§2](#2-仓库清单与远程地址),不在此重复维护。

**关键约束**:
- 层目录(`format/` `asset-types/` `runtime/` `editor/`)是根仓库内的普通目录,**不是 Git 仓库**。如果层目录自己也是仓库,其中的子项目版本将被强行绑定、无法独立演化。
- 每个子项目是独立仓库,通过 Submodule 挂载到对应层目录下,拥有独立的 commit 历史、remote、发布周期。

## 2. 仓库清单与远程地址

| 仓库 | 本地路径 | GitHub Remote |
|------|----------|---------------|
| Eidolon(顶层) | `Eidolon/` | `git@github.com:hakureireimuyo/Eidolon.git` |
| Cartridge | `format/Cartridge/` | `git@github.com:hakureireimuyo/cartridge.git` |
| eidolon-character | `asset-types/eidolon-character/` | `git@github.com:hakureireimuyo/eidolon-character.git` |
| eidolon-character-service | `runtime/eidolon-character-service/` | `git@github.com:hakureireimuyo/eidolon-character-service.git` |
| eidolon-runtime | `runtime/eidolon-runtime/` | `git@github.com:hakureireimuyo/eidolon-runtime.git` |
| eidolon-studio | `editor/eidolon-studio/` | `git@github.com:hakureireimuyo/eidolon-studio.git` |

6 个仓库均已推送到 GitHub,全部位于 `hakureireimuyo` 账号下。所有仓库的默认分支为 `master`。

## 3. Submodule 的工作原理

顶层仓库不跟踪子项目内部的文件变更,只记录一个 **gitlink** —— 指向子项目仓库的某个 commit:

```
# 顶层仓库记录:
format/Cartridge          → commit 994decab
runtime/eidolon-runtime   → commit 1c820ab
```

这意味着:
- 子项目内部开发(修改代码、commit、push)完全独立,不影响顶层
- 顶层只在子项目改动稳定后,显式更新指针并 commit
- 拉取顶层仓库时,通过 submodule 指针恢复子项目的确切版本 —— 保证可复现

## 4. 日常操作

### 4.1 克隆(含所有子项目)

```bash
git clone --recurse-submodules git@github.com:hakureireimuyo/Eidolon.git

# 或先克隆再拉子模块
git clone git@github.com:hakureireimuyo/Eidolon.git
cd Eidolon
git submodule update --init --recursive
```

### 4.2 在子项目中开发

```bash
cd runtime/eidolon-runtime

# 正常开发、提交
git checkout -b feature/xxx
# ... 修改代码 ...
git add .
git commit -m "feat: xxx"
git push origin feature/xxx

# 或直接在 master 上开发
git add .
git commit -m "feat: xxx"
```

### 4.3 更新顶层指针

子项目有新 commit 后,顶层需要同步:

```bash
cd Eidolon  # 回到顶层

# 查看哪些子模块有变更
git submodule status

# 更新指针
git add runtime/eidolon-runtime
git commit -m "chore: update eidolon-runtime submodule pointer (xxx)"
```

### 4.4 拉取子项目的远程更新

```bash
cd format/Cartridge
git pull origin master

# 回到顶层更新指针
cd ../..
git add format/Cartridge
git commit -m "chore: update Cartridge submodule (pull latest)"
```

### 4.5 查看整体状态

```bash
cd Eidolon

# 各子模块的当前 commit 与是否有变更
git submodule status

# 逐个检查子项目
cd format/Cartridge && git status --short && cd -
cd runtime/eidolon-runtime && git status --short && cd -
```

### 4.6 检查远程跟踪状态

```bash
# 在每个仓库中
git branch -vv
# 应显示 [origin/master] 而非 [origin/master: gone]
```

出现 `[gone]` 时按 [§6.1](#61-originmaster-gone-误报) 处理;注意验证时 `git status -sb` 显示 `## master...origin/master` 即正常。

## 5. 版本固定与兼容

顶层仓库固定子模块的 commit,保证环境可复现(下例为**历史快照,仅说明机制,与项目当前实际状态无关**;现状见 §2 清单与 `git submodule status`):

```
顶层 commit fc7db4c 记录:
  Cartridge        @ 994decab  (V1 协议层)
  eidolon-character @ 5903fae  (扩展规范)
  eidolon-runtime  @ 1c820ab  (资源路由框架)
  eidolon-studio   @ 4635a92  (编辑器)

新克隆此 commit 的人会得到完全相同的子项目版本。
```

消费方通过以下层次保证兼容:
- 协议层(Cartridge)定义版本号(`manifest.version`)
- 扩展层(eidolon-character)通过 `VersionRange` 声明兼容的协议版本
- 运行时层通过资源路由框架的 `MigrationGraph` 处理版本升级
- 顶层固定子模块指针,杜绝意外的 breaking change

## 6. 已知问题与解决方案

### 6.1 `[origin/master: gone]` 误报

**现象**:`git branch -vv` 显示 `[origin/master: gone]`,但 GitHub 远程仓库实际存在且可达。

**根因**:remote tracking ref(`refs/remotes/origin/master`)未落盘或损坏。可能触发因素:

1. `.git/refs/remotes/origin/` 目录不存在 —— PortableGit(WorkBuddy 内置版本)在 Windows 上不会自动创建该目录,fetch 写入失败
2. 子模块是 gitdir 文件类型(见 §6.3),refs 实际存放在顶层 `.git/modules/<name>/` 下,直接操作子项目内的 `.git` 路径无效
3. 沙箱环境虚拟化 `.git` 写入 —— 命令内"声称成功"、命令结束后写入消失
4. 缩写 SHA(7 位)被手写进 ref 文件,git 视为 broken ref 并忽略

**解决**(在每个有此问题的仓库中执行;**必须非沙箱**,且在同一命令内验证):

```bash
GD=$(git rev-parse --absolute-git-dir)   # gitdir 文件型子模块会解析到顶层 .git/modules/<name>
mkdir -p "$GD/refs/remotes/origin"

# 清理调试残留:stale lock / 内容非法的 broken ref
rm -f "$GD/refs/remotes/origin/"*.lock

# 用完整 40 位 SHA 重建(缩写 SHA 会被 git 当作 broken ref 忽略)
git update-ref refs/remotes/origin/master "$(git rev-parse master)"

# 同一命令内验证落盘
git rev-parse refs/remotes/origin/master
git status -sb                           # 应显示 ## master...origin/master
```

若 `packed-refs` 中残留推送前的旧 SHA,执行 `git pack-refs --all` 重打包(loose ref 优先,旧条目无害但会误导排查)。

**验证注意事项**:git 2.54 起 `git show-ref` 不再做前缀匹配 —— `git show-ref refs/remotes` 返回空(exit 1)**不是 ref 丢失**,模式需写完整 ref 名或从 ref 名末尾匹配完整组件。可靠的验证方式:

```bash
git show-ref                            # 无参数,列出全部 ref
git rev-parse refs/remotes/origin/master
git status -sb                          # ## master...origin/master 即正常
```

**经验规则**:所有写 `.git` 的命令(fetch / update-ref / pack-refs)必须在非沙箱环境执行;沙箱会虚拟化 `.git` 写入,命令内成功、跨命令消失。判断是否真实落盘的唯一可靠方式,是在同一条非沙箱命令内写入后立即读取验证。

此问题可能由 PortableGit(WorkBuddy 内置版本)在 Windows 上的路径处理行为触发。重新克隆后也建议验证 `refs/remotes/origin/` 目录是否存在。

### 6.2 Submodule 指针指向不存在的 commit

**现象**:`git submodule status` 中某子模块显示 `+` 前缀,且记录的 commit 在子模块仓库中不存在。

**根因**:子模块仓库被重建或 force push 后历史变更。

**解决**:

```bash
cd format/Cartridge
git fetch origin
git checkout origin/master    # 或已知的正确 commit

cd ../..
git add format/Cartridge
git commit -m "chore: fix Cartridge submodule pointer"
```

### 6.3 子项目 .git 目录类型

**所有子项目都是独立仓库**(各自拥有 remote、commit 历史、发布周期),区别仅在于 `.git` 自身的存放形态(现状):

- **gitdir 文件**(标准 gitlink):`eidolon-character`、`eidolon-character-service`、`eidolon-runtime`、`eidolon-studio` —— 内容为 `gitdir: ../../.git/modules/<name>`,真实 gitdir 在顶层仓库的 `.git/modules/` 下
- **实体目录 .git**:`Cartridge` —— 与顶层仓库相同的形态,`.git` 是实体目录;最初独立 init 后通过 `git submodule add` 关联,未被 absorb(remote 见 §2 清单)

各仓库最初是独立 init 的,后通过 `git submodule add` 关联,部分子模块此后被 git 自动吸收为标准 gitlink 格式(absorbgitdirs)。两种形态均为合法仓库,只要 `git submodule status` 正常工作即可,不需要统一格式。

对 gitdir 文件型子模块做 §6.1 类修复时,必须先用 `git rev-parse --absolute-git-dir` 解析真实 gitdir;直接操作子项目内的 `.git` 路径(如 `mkdir .git/refs/...`)无效。

## 7. 子项目 Git 配置注意事项

### 7.1 独立提交

子项目内的提交不受顶层影响,使用各自的 Git 身份:

```bash
# 全局身份(子项目继承)
git config --global user.name "siwei"
git config --global user.email "3330456284@qq.com"
```

### 7.2 Branch 策略

- 所有子项目默认在 `master` 上开发
- 重大变更可开 feature 分支,合入后更新顶层指针
- 子项目的分支切换不影响其他子项目

### 7.3 .gitignore

子项目各有自己的 `.gitignore`(如 `__pycache__/`、`.venv/` 等)。顶层 `.gitignore` 不再屏蔽子项目目录(已交由 `.gitmodules` 管理),仅屏蔽顶层私有的 `.workbuddy/` 和 `.serena/`。

## 8. 新子项目接入流程

```bash
# 1. 在 GitHub 创建新仓库(如 eidolon-mind)

# 2. 在顶层添加 submodule
cd Eidolon
git submodule add git@github.com:hakureireimuyo/eidolon-mind.git mind/eidolon-mind

# 3. 加入 uv workspace(如需要)
# 编辑 pyproject.toml,在 [tool.uv.workspace].members 中添加 "mind/eidolon-mind"

# 4. 提交
git add .gitmodules mind/eidolon-mind pyproject.toml
git commit -m "feat: add eidolon-mind as submodule"

# 5. 推送
git push origin master
```
