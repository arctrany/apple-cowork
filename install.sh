#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
# Apple Cowork — 一键安装
# 将 skills 符号链接到目标项目
# ─────────────────────────────────────────────

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS=("apple-notes" "apple-productivity")

# ── 颜色 ──
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ── 参数解析 ──
PROJECT=""
DRY_RUN=false

usage() {
    echo "用法: $0 --project <项目路径> [--dry-run]"
    echo ""
    echo "选项:"
    echo "  --project <路径>   目标项目的根目录"
    echo "  --dry-run          仅预览操作，不实际执行"
    echo "  -h, --help         显示帮助"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --project)  PROJECT="$2"; shift 2 ;;
        --dry-run)  DRY_RUN=true; shift ;;
        -h|--help)  usage ;;
        *)          echo -e "${RED}未知参数: $1${NC}"; usage ;;
    esac
done

if [[ -z "$PROJECT" ]]; then
    echo -e "${RED}错误: 必须指定 --project <路径>${NC}"
    usage
fi

# 展开 ~ 和相对路径
PROJECT="$(cd "$PROJECT" 2>/dev/null && pwd || echo "$PROJECT")"

if [[ ! -d "$PROJECT" ]]; then
    echo -e "${RED}错误: 项目目录不存在: $PROJECT${NC}"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Apple Cowork 安装"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo " 源:   $REPO_DIR/skills/"
echo " 目标: $PROJECT/skills/"
echo ""

if $DRY_RUN; then
    echo -e "${YELLOW}[预览模式] 不会实际执行${NC}"
    echo ""
fi

# ── 1. 授权脚本 ──
echo "→ 授权脚本执行..."
if ! $DRY_RUN; then
    for skill in "${SKILLS[@]}"; do
        chmod +x "$REPO_DIR/skills/$skill/scripts/"*.sh 2>/dev/null || true
    done
fi
echo -e "  ${GREEN}✓${NC} 脚本已授权"

# ── 2. 创建 symlink ──
for skill in "${SKILLS[@]}"; do
    target="$PROJECT/skills/$skill"

    if [[ -L "$target" ]]; then
        echo -e "  ${YELLOW}⇢${NC} $skill — 已存在（跳过）"
        continue
    fi

    if [[ -d "$target" ]]; then
        echo -e "  ${RED}✗${NC} $skill — 目标已存在且非 symlink，跳过（请手动处理）"
        continue
    fi

    echo -e "  → 链接 skills/$skill"
    if ! $DRY_RUN; then
        mkdir -p "$PROJECT/skills"
        ln -s "$REPO_DIR/skills/$skill" "$target"
    fi
    echo -e "  ${GREEN}✓${NC} $skill"
done

# ── 3. 初始化 .local.md ──
echo ""
echo "→ 检查配置文件..."
for skill in "${SKILLS[@]}"; do
    local_file="$REPO_DIR/skills/$skill/.local.md"
    example_file="$REPO_DIR/skills/$skill/.local.example.md"

    if [[ -f "$local_file" ]] 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} skills/$skill/.local.md 已存在"
    elif [[ -f "$example_file" ]]; then
        echo -e "  → 创建 skills/$skill/.local.md"
        if ! $DRY_RUN; then
            if cp "$example_file" "$local_file" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} 已从模板创建，请编辑填入你的账户信息"
            else
                echo -e "  ${YELLOW}⇢${NC} 跳过（无权限），请手动复制: cp $example_file $local_file"
            fi
        else
            echo -e "  ${GREEN}✓${NC} 已从模板创建，请编辑填入你的账户信息"
        fi
    fi
done

# ── 完成 ──
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e " ${GREEN}安装完成！${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "下一步:"
echo "  1. 编辑 skills/*/​.local.md 配置你的 Apple 账户"
echo "  2. 首次运行时授权 macOS 权限（备忘录 / 提醒事项 / 日历）"
echo "  3. 在你的 AI Code Agent 中直接说自然语言即可"
echo ""
