#!/usr/bin/env bash
# ============================================================
# add-subproject.sh — 一键接入新子项目（独立仓库 + Submodule）
#
# 解决痛点：新子项目接入 GitHub 的繁琐手工流程
#   （建仓库 → init → remote → push → submodule → workspace → 提交推送）
#
# 用法:
#   scripts/add-subproject.sh <子项目相对路径> [GitHub 仓库名]
#
# 示例:
#   scripts/add-subproject.sh runtime/eidolon-mind eidolon-mind
#   scripts/add-subproject.sh runtime/eidolon-mind   # 仓库名默认取目录名
#
# 前置条件:
#   - 在 GitHub 上预先创建同名空仓库（脚本检测不到时会打印创建链接）
#   - SSH key 已配置（与其余 submodule 的 git@ URL 一致）
#
# 幂等性: 可重复执行；已接入的步骤自动跳过，不会重复提交。
# ============================================================
set -euo pipefail

TOP=$(git rev-parse --show-toplevel)
REL_PATH="${1:?用法: add-subproject.sh <子项目相对路径> [GitHub 仓库名]}"
REPO_NAME="${2:-$(basename "$REL_PATH")}"

# ---------- 0. 预检 ----------
SUB_DIR="$TOP/$REL_PATH"
[ -d "$SUB_DIR" ] || { echo "✗ 路径不存在: $REL_PATH"; exit 1; }
if git config -f "$TOP/.gitmodules" --get "submodule.$REL_PATH.path" >/dev/null 2>&1; then
  echo "✗ $REL_PATH 已在 .gitmodules 中注册，无需重复接入"; exit 1
fi

OWNER=$(git config --get remote.origin.url | sed -E 's#.*github\.com[:/]([^/]+)/.*#\1#')
REMOTE_URL="git@github.com:$OWNER/$REPO_NAME.git"
echo "==> 目标远程: $REMOTE_URL"

# ---------- 1. 检查远程仓库是否存在 ----------
if ! git ls-remote "$REMOTE_URL" HEAD >/dev/null 2>&1; then
  echo ""
  echo "✗ 远程仓库不存在或不可访问。请在浏览器创建空仓库（不要勾选 README/.gitignore/LICENSE）："
  echo "    https://github.com/new?name=$REPO_NAME&owner=$OWNER"
  echo "  创建完成后重新执行本脚本即可。"
  exit 1
fi
echo "==> 远程仓库已就绪"

# ---------- 2. 子项目本地初始化 ----------
if [ ! -d "$SUB_DIR/.git" ]; then
  echo "==> git init 子项目 ($REL_PATH)"
  git -C "$SUB_DIR" init -b master
fi
if [ ! -f "$SUB_DIR/.gitignore" ]; then
  echo "⚠  $REL_PATH 没有 .gitignore，已生成默认 Python 模板（可按需修改）"
  cat > "$SUB_DIR/.gitignore" <<'IGN'
# Python
__pycache__/
*.py[cod]
*.egg-info/
build/
dist/
.venv/
.pytest_cache/
.coverage
IGN
fi
if [ -z "$(git -C "$SUB_DIR" status --porcelain)" ] && [ "$(git -C "$SUB_DIR" rev-list --count HEAD 2>/dev/null || echo 0)" -eq 0 ]; then
  # 空仓库（无提交且无内容）也允许，但无内容无法 push 首个分支
  echo "⚠  $REL_PATH 为空目录，无内容可提交"
fi
if [ "$(git -C "$SUB_DIR" rev-list --count HEAD 2>/dev/null || echo 0)" -eq 0 ]; then
  git -C "$SUB_DIR" add .
  git -C "$SUB_DIR" commit -m "chore: $REPO_NAME 初始导入" || true
  echo "==> 子项目首次提交完成"
fi

# ---------- 3. remote + push ----------
if ! git -C "$SUB_DIR" remote get-url origin >/dev/null 2>&1; then
  git -C "$SUB_DIR" remote add origin "$REMOTE_URL"
  echo "==> remote origin 已添加"
fi
git -C "$SUB_DIR" push -u origin master 2>&1 | tail -2
echo "==> 子项目已推送"

# ---------- 4. 顶层注册 submodule ----------
git config -f "$TOP/.gitmodules" "submodule.$REL_PATH.path" "$REL_PATH"
git config -f "$TOP/.gitmodules" "submodule.$REL_PATH.url" "$REMOTE_URL"
git add .gitmodules "$REL_PATH" 2>/dev/null || true
git submodule init "$REL_PATH" >/dev/null 2>&1 || true
git submodule absorbgitdirs "$REL_PATH" >/dev/null 2>&1 || true
git submodule update "$REL_PATH" >/dev/null 2>&1 || true
echo "==> submodule 已注册并收编（gitlink 格式）"
git submodule status | grep "$REL_PATH"

# ---------- 5. uv workspace members ----------
if [ -f "$TOP/pyproject.toml" ]; then
  python - "$REL_PATH" <<'PY' || echo "⚠  未能自动更新 workspace members，请手动在 pyproject.toml 添加"
import pathlib, sys
path = sys.argv[1]
p = pathlib.Path("pyproject.toml")
s = p.read_text(encoding="utf-8")
if f'"{path}"' in s:
    sys.exit(0)
marker = '"editor/eidolon-studio",'
if marker in s:
    s = s.replace(marker, marker + f'\n    "{path}",')
    p.write_text(s, encoding="utf-8")
    print("==> 已添加 workspace member:", path)
PY
fi

# ---------- 6. 顶层提交 + 推送 ----------
if ! git diff --cached --quiet; then
  git commit -m "feat: add $REPO_NAME as submodule"
fi
git push origin master 2>&1 | tail -2
echo ""
echo "✔ 完成！$REL_PATH 已作为独立仓库接入并推送到 GitHub。"
echo "  远程: $REMOTE_URL"
echo "  顶层: $(git log --oneline -1)"
