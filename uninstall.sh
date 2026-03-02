#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
# Apple Cowork — 卸载
# 移除目标项目中的 skills 符号链接
# ─────────────────────────────────────────────

SKILLS=("apple-notes" "apple-productivity")

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

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

PROJECT="$(cd "$PROJECT" 2>/dev/null && pwd || echo "$PROJECT")"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Apple Cowork 卸载"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if $DRY_RUN; then
    echo -e "${YELLOW}[预览模式]${NC}"
    echo ""
fi

removed=0

for skill in "${SKILLS[@]}"; do
    target="$PROJECT/skills/$skill"

    if [[ -L "$target" ]]; then
        echo -e "  → 移除 skills/$skill"
        if ! $DRY_RUN; then
            rm "$target"
        fi
        echo -e "  ${GREEN}✓${NC} 已移除"
        ((removed++))
    elif [[ -d "$target" ]]; then
        echo -e "  ${YELLOW}⇢${NC} skills/$skill 不是符号链接，跳过"
    else
        echo -e "  ${YELLOW}⇢${NC} skills/$skill 不存在，跳过"
    fi
done

# 清理空的 skills 目录
if [[ -d "$PROJECT/skills" ]] && [[ -z "$(ls -A "$PROJECT/skills" 2>/dev/null)" ]]; then
    echo -e "  → 移除空目录 skills/"
    if ! $DRY_RUN; then
        rmdir "$PROJECT/skills"
    fi
fi

echo ""
echo -e "${GREEN}卸载完成${NC}（移除了 $removed 个 skill）"
echo ""
echo "注意: 你的 .local.md 配置文件保留在源仓库中，未被删除。"
echo ""
