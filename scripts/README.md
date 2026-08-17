# scripts 使用手册

> 常用命令速查;详细逻辑看脚本头注释或 `--dry-run` 预览。

## 1. propagate-rev.sh — rev 传播链自动更新

**作用**:把子模块的本地 HEAD 沿依赖链逐级穿透:

```
提交子仓库 → 自动 push 各仓 origin/master → 更新消费仓 pyproject.toml pin
+ uv lock + commit + push → 更新主仓子模块指针 → 3 个 venv 仓 uv sync
```

**用法**:

```bash
bash scripts/propagate-rev.sh             # 完整传播
bash scripts/propagate-rev.sh --dry-run   # 只预览将执行的动作,不改任何东西
bash scripts/propagate-rev.sh --no-sync   # 跳过 runtime/studio 的 uv sync
```

**日常流程(如改完内核后)**:

```bash
cd kernel/eidolon-graph && git add -A && git commit -m "..."   # 1. 提交内核改动
cd ../.. && bash scripts/propagate-rev.sh                        # 2. 一键传播
```

**前置条件**:

| 条件 | 不满足时的行为 |
|------|---------------|
| provider 仓工作区干净(含 `kernel/eidolon-graph`、`format/Cartridge` 等) | 中止,提示先提交 |
| 叶子仓(`runtime`/`studio`/`editor`)工作区干净 | 跳过该仓 pin 提交,警告(不碰你的改动) |
| 各仓本地不落后/不分叉于 origin/master | 中止,提示先拉取/合并 |
| 子模块路径存在 | 中止 |

**注意**:

- rev 一律取**各子模块本地检出 HEAD**——先提交子仓库,再跑脚本;
- 脚本会 **push 各仓 origin master**(provider 仓、消费仓、主仓),不可撤销;
- 幂等:pin 已对齐的仓自动跳过,不产生空提交;
- 传播完成后**重启正在运行的服务**才加载新依赖(uvicorn 无 `--reload`);
- 依赖图:`kernel/eidolon-graph → editor/eidolon-graph-editor`(git 源 pin);`runtime/eidolon-runtime` 目前未 pin 内核,脚本自动跳过并提示。

## 2. add-subproject.sh — 接入新子项目

**作用**:新子项目接入(独立仓库 + Submodule)的一键流程。

**用法**:

```bash
scripts/add-subproject.sh <子项目相对路径> [GitHub 仓库名]   # 仓库名默认取目录名
# 示例
scripts/add-subproject.sh runtime/eidolon-mind eidolon-mind
```

**前置条件**:先在 GitHub 创建同名**空仓库**(不要勾选 README/.gitignore/LICENSE),SSH key 已配置。

**流程**:git init → 首次提交(自动生成默认 .gitignore)→ push → 注册 submodule → 顶层提交 + push。幂等,可重复执行。
