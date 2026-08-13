# 多机开发流程

> 相关文档:[`git-repository-management.md`](./git-repository-management.md) —— 仓库架构、日常操作与已知问题。

在另一台电脑上拉取 Eidolon 生态并继续开发、推送的完整流程。前提:目标机器已安装 Git 与 uv(依赖管理)。

## 1. 一次性准备

### 1.1 SSH 密钥

所有 remote 均为 `git@github.com:` 形式,新机器需要注册 SSH 密钥:

```bash
ssh-keygen -t ed25519 -C "3330456284@qq.com"
# 将 ~/.ssh/id_ed25519.pub 内容添加到 GitHub → Settings → SSH and GPG keys
ssh -T git@github.com   # 验证连通
```

### 1.2 Git 身份

```bash
git config --global user.name "siwei"
git config --global user.email "3330456284@qq.com"
```

子项目继承全局配置,使用各自的 Git 身份(见 git-repository-management.md §7.1)。

## 2. 克隆

```bash
git clone --recurse-submodules git@github.com:hakureireimuyo/Eidolon.git

# 或分两步(见 git-repository-management.md §4.1)
git clone git@github.com:hakureireimuyo/Eidolon.git
cd Eidolon
git submodule update --init --recursive
```

顶层仓库固定了每个子模块的指针,新克隆会恢复全部子项目到指针指定的确切 commit,环境可复现。

## 3. 安装依赖

各仓库是**独立 uv 项目**(自持 `.venv` 与 `uv.lock`),按需在对应仓库内安装:

```bash
cd runtime/eidolon-runtime && uv sync     # 运行时(或 studio / character-service / 各库仓)
```

> 顶层仓库**不是** uv workspace,没有统一 `uv sync`。
> 兄弟库(cartridge / eidolon-character / eidolon-character-service)以
> **git 源(pin rev)** 作为第三方依赖安装(见各消费方 pyproject 的 `[tool.uv.sources]`),
> monorepo 检出与单独 clone 行为一致。
>
> **库升级流程**:库仓 commit + push 后,消费方把其 pyproject 中对应 rev
> 更新为新 commit,再 `uv sync`;最后在顶层更新子模块指针(见 §5)。

## 4. 克隆后验证

在顶层和每个子项目内执行 `git status -sb`,应显示 `## master...origin/master`(见 git-repository-management.md §4.6)。

若显示 `[origin/master: gone]`,按 git-repository-management.md §6.1 修复 —— 这是 PortableGit 在 Windows 上的已知问题,新机器上同样可能出现,克隆后务必验证。

## 5. 日常开发与推送

```bash
# 1. 在子项目中开发并推送(各仓库独立)
cd runtime/eidolon-runtime
# ... 修改代码 ...
git add .
git commit -m "feat: xxx"
git push origin master

# 2. 回到顶层,更新子模块指针并推送
cd ../..
git add runtime/eidolon-runtime
git commit -m "chore: update eidolon-runtime submodule pointer (xxx)"
git push origin master
```

**关键顺序:先推子模块、后推顶层。** 顶层指针必须指向远程上真实存在的 commit;否则其他机器拉取顶层后 `git submodule update` 失败(git-repository-management.md §6.2 为此问题的修复流程)。

**改库时多一步(rev 更新)**:改动落在被其他仓依赖的库(如 cartridge、eidolon-character、
eidolon-character-service)时,库仓 push 后还要更新**消费方 pyproject 里的 rev** 并单独提交消费方,
否则消费方仍安装旧版本:

```bash
# 库仓:开发并推送
cd format/Cartridge && git commit -m "fix: xxx" && git push origin master

# 消费方:更新 rev 并推送
cd ../../runtime/eidolon-runtime
# 编辑 pyproject.toml,把 cartridge 的 rev 改为库仓新 commit
uv sync && git add pyproject.toml uv.lock && git commit -m "chore: bump cartridge rev" && git push origin master

# 最后顶层更新指针(§5 步骤 2)
```

## 6. 双机并行同步

两台机器同时开发时,动工前先拉最新,避免指针互相覆盖:

```bash
# 逐个子项目拉取远程更新(见 git-repository-management.md §4.4)
cd format/Cartridge && git pull origin master && cd ../..
cd runtime/eidolon-runtime && git pull origin master && cd ../..

# 查看哪些子模块与顶层指针不一致
git submodule status

# 指针有变化则更新并提交
git add <变化的子模块路径>
git commit -m "chore: update submodule pointers (pull latest)"
git push origin master
```

## 7. 要点总结

| 事项 | 说明 |
|------|------|
| 分支策略 | 所有仓库默认直接在 `master` 上开发(git-repository-management.md §7.2) |
| 提交边界 | 子项目改动提交到子项目仓库;顶层只提交指针与文档 |
| 推送顺序 | 先子模块、后顶层 |
| 依赖安装 | 各仓库独立 `uv sync`(git 源 pin rev,顶层无 workspace) |
| 库升级 | 库仓 push → 消费方更新 rev → 消费方 push → 顶层更新指针 |
| 新机器克隆 | 一条命令恢复全部 6 个仓库到指针固定版本 |
| Windows 坑 | 克隆后务必验证 `git status -sb`,出现 `[gone]` 按 §6.1 修复 |
