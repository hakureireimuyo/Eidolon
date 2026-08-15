#!/usr/bin/env bash
# ============================================================
# propagate-rev.sh — 子仓库 rev 传播链自动更新
#
# 解决痛点:底层库(如 cartridge)修复后,rev 需逐级穿透:
#   commit+push → 各消费仓改 pin + uv lock + commit + push
#   → 顶层子模块指针更新(手工约 15 步)
#
# 依赖图(拓扑序,provider 在前;新增/调整依赖关系时改 REPOS 数组):
#   cartridge
#     → eidolon-character ──────────┐
#   cartridge ──────────────────────┼→ eidolon-character-service
#   eidolon-character ──────────────┘        └→ eidolon-runtime(dev 组也直 pin character)
#   cartridge + eidolon-character → eidolon-studio
#   eidolon-graph → eidolon-graph-editor(编辑器;git 源 pin,headless 预览/运行会话)
#   eidolon-graph → eidolon-runtime(内核;pyproject 尚未 pin 时传播自动跳过并提示)
#
# 用法:
#   bash scripts/propagate-rev.sh             # 完整传播 + venv 同步
#   bash scripts/propagate-rev.sh --dry-run   # 只打印将执行的动作,不改任何东西
#   bash scripts/propagate-rev.sh --no-sync   # 跳过 runtime/studio 的 uv sync
#
# 行为约定:
#   - rev 一律取各子模块【本地检出 HEAD】,与顶层子模块指针同源
#     (见 agent-conventions/uv-dependency-management.md §2.4)
#   - 子仓库本地有未推送提交 → 自动 push;落后/分叉于 origin/master → 中止并提示
#   - provider 仓(cartridge/character/character-service)工作区有未提交改动
#     → 中止(HEAD 代表不了实际代码);
#     叶子仓(runtime/studio)有未提交改动 → 跳过该仓的 pin 提交并警告,不碰改动
#   - 幂等性: 可重复执行;pin 已对齐的仓自动跳过,不产生空提交
#   - 传播完成后需重启正在运行的服务(uvicorn 无 --reload)
# ============================================================
set -euo pipefail

# 主仓根:以脚本自身位置推导(子模块内 git rev-parse 会解析到子仓,不可用)
TOP="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "$TOP/.gitmodules" ] || { echo "✗ 脚本必须位于 Eidolon 主仓的 scripts/ 目录"; exit 1; }
# 固定工作目录为主仓根(主仓段的 git add/commit/push 依赖 cwd)
cd "$TOP"

DRY_RUN=0
DO_SYNC=1
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --no-sync) DO_SYNC=0 ;;
    -h|--help)
      echo "用法: bash scripts/propagate-rev.sh [--dry-run] [--no-sync]"
      exit 0 ;;
    *) echo "✗ 未知参数: $arg"; exit 1 ;;
  esac
done

# 依赖图: "路径|包名|providers(包名,空格分隔)" —— 必须严格拓扑序
REPOS=(
  "format/Cartridge|cartridge|"
  "asset-types/eidolon-character|eidolon-character|cartridge"
  "runtime/eidolon-character-service|eidolon-character-service|cartridge eidolon-character"
  "runtime/eidolon-graph|eidolon-graph|"
  "editor/eidolon-graph-editor|eidolon-graph-editor|eidolon-graph"
  "runtime/eidolon-runtime|eidolon-runtime|eidolon-character eidolon-character-service eidolon-graph"
  "editor/eidolon-studio|eidolon-studio|cartridge eidolon-character"
)
# 持有 venv 的应用/服务仓(传播完成后 uv sync)
VENV_REPOS=(runtime/eidolon-runtime editor/eidolon-studio editor/eidolon-graph-editor)
# provider 仓(工作区脏 → 中止);叶子仓(脏 → 仅跳过)
# eidolon-graph 自 eidolon-graph-editor pin 接入后即属 provider 仓
PROVIDER_PATHS=(format/Cartridge asset-types/eidolon-character runtime/eidolon-character-service runtime/eidolon-graph)

run() {  # 统一执行口(支持 dry-run)
  if [ "$DRY_RUN" = 1 ]; then
    echo "    [dry-run] $*"
  else
    "$@"
  fi
}

sha() { git -C "$TOP/$1" rev-parse HEAD; }

sync_master_ref() {  # 仅 detached 检出时同步本地 master 引用;检出在 master 分支时 HEAD 即 master,强制更新会失败
  if ! git -C "$TOP/$1" symbolic-ref -q HEAD >/dev/null 2>&1; then
    run git -C "$TOP/$1" branch -f master HEAD
  fi
}

# 预检:各子模块路径存在
echo "==> 传播链检查(rev 取各子模块本地 HEAD)"
for entry in "${REPOS[@]}"; do
  path="${entry%%|*}"
  { [ -d "$TOP/$path/.git" ] || [ -f "$TOP/$path/.git" ]; } || { echo "✗ 子模块不存在: $path"; exit 1; }
done

for entry in "${REPOS[@]}"; do
  path="${entry%%|*}"
  rest="${entry#*|}"
  pkg="${rest%%|*}"
  providers="${rest#*|}"
  echo ""
  echo "==> [$pkg] $path"

  git -C "$TOP/$path" fetch origin >/dev/null 2>&1

  # ---------- 工作区检查 ----------
  if [ -n "$(git -C "$TOP/$path" status --porcelain)" ]; then
    if printf '%s\n' "${PROVIDER_PATHS[@]}" | grep -qx "$path"; then
      echo "✗ 工作区有未提交改动,无法传播(HEAD 不代表实际代码)。请先提交:"
      git -C "$TOP/$path" status --short | head -5
      exit 1
    fi
    echo "⚠  工作区有未提交改动,跳过本仓的 pin 提交(你的改动不受影响)"
    continue
  fi

  # ---------- 与 origin/master 的关系 ----------
  head=$(sha "$path")
  origin=$(git -C "$TOP/$path" rev-parse origin/master)
  if [ "$head" = "$origin" ]; then
    echo "  - 与 origin/master 一致,无需 push"
  elif git -C "$TOP/$path" merge-base --is-ancestor "$origin" "$head" 2>/dev/null; then
    echo "  - 本地领先(${head:0:7}),推送 origin master"
    run git -C "$TOP/$path" push origin HEAD:master
    sync_master_ref "$path"
  elif git -C "$TOP/$path" merge-base --is-ancestor "$head" "$origin" 2>/dev/null; then
    echo "✗ 本地落后于 origin/master,请先在该仓拉取更新,再重新传播"
    exit 1
  else
    echo "✗ 与 origin/master 分叉,请人工合并/rebase 后再传播"
    exit 1
  fi

  # ---------- pin 更新(消费仓) ----------
  if [ -n "$providers" ]; then
    changed=0
    updates=""
    for prov in $providers; do
      # 由包名找回 provider 的路径
      prov_path=""
      for e2 in "${REPOS[@]}"; do
        e2_rest="${e2#*|}"
        if [ "${e2_rest%%|*}" = "$prov" ]; then prov_path="${e2%%|*}"; break; fi
      done
      [ -n "$prov_path" ] || { echo "⚠  依赖图中找不到 provider: $prov(检查 REPOS 数组)"; exit 1; }

      new_rev=$(sha "$prov_path")
      old_rev=$(sed -nE "s#.*hakureireimuyo/${prov}\\.git\", rev = \"([0-9a-f]{40})\".*#\\1#p" "$TOP/$path/pyproject.toml")
      if [ -z "$old_rev" ]; then
        echo "⚠  $path 未 pin $prov,跳过"
        continue
      fi
      if [ "$old_rev" != "$new_rev" ]; then
        if [ "$DRY_RUN" = 1 ]; then
          echo "    [dry-run] sed 更新 $prov pin: ${old_rev:0:7} → ${new_rev:0:7}"
        else
          sed -i -E "s#(hakureireimuyo/${prov}\\.git\", rev = \")[0-9a-f]{40}(\")#\\1${new_rev}\\2#" "$TOP/$path/pyproject.toml"
        fi
        updates="${updates}${prov}→${new_rev:0:7} "
        changed=1
      fi
    done

    if [ "$changed" = 1 ]; then
      echo "  - 更新 pin: $updates"
      if [ "$DRY_RUN" = 0 ]; then
        (cd "$TOP/$path" && uv lock) 2>&1 | sed 's/^/    /' | tail -4
      fi
      run git -C "$TOP/$path" add pyproject.toml uv.lock
      run git -C "$TOP/$path" commit -m "chore: ${updates}(rev 自动传播)"
      run git -C "$TOP/$path" push origin HEAD:master
      sync_master_ref "$path"
    else
      echo "  - pin 已对齐,无需更新"
    fi
  fi
done

# ---------- 顶层子模块指针 ----------
echo ""
echo "==> [主仓] 子模块指针"
if [ "$DRY_RUN" = 1 ]; then
  for entry in "${REPOS[@]}"; do echo "    [dry-run] git add ${entry%%|*}"; done
else
  for entry in "${REPOS[@]}"; do git add "${entry%%|*}" 2>/dev/null || true; done
fi
paths_spec="$(for entry in "${REPOS[@]}"; do echo "${entry%%|*}"; done | tr '\n' ' ')"
if git diff --cached --quiet -- $paths_spec; then
  echo "  - 指针无变化,无需提交"
else
  run git commit -m "chore: update submodule pointers(rev 自动传播)"
  run git push origin master
fi

# ---------- venv 同步 ----------
if [ "$DO_SYNC" = 1 ]; then
  for v in "${VENV_REPOS[@]}"; do
    echo ""
    echo "==> [$v] uv sync(安装传播后的 rev)"
    if [ "$DRY_RUN" = 1 ]; then
      echo "    [dry-run] uv sync"
      continue
    fi
    (cd "$TOP/$v" && uv sync) 2>&1 | tail -3
  done
  echo ""
  echo "⚠  若 runtime/studio 服务正在运行,需重启才加载新依赖(uvicorn 无 --reload)"
fi

echo ""
echo "✔ 传播完成。主仓: $(git -C "$TOP" log --oneline -1)"
