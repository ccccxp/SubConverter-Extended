#!/usr/bin/env bash
#
# SubConverter-Extended 一键卸载脚本
#

set -euo pipefail

INSTALL_DIR="/opt/SubConverter-Extended"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
    log_error "此脚本需要 root 权限运行"
    exit 1
fi

echo ""
echo "=========================================="
echo "  SubConverter-Extended 卸载程序"
echo "=========================================="
echo ""

if [[ ! -d "$INSTALL_DIR" ]]; then
    log_warn "未找到安装目录: $INSTALL_DIR"
    log_info "服务可能未安装或已被卸载"
    
    # 清理可能残留的命令
    if [[ -f /usr/local/bin/subconverter ]]; then
        rm -f /usr/local/bin/subconverter
        log_info "已清理残留的管理命令"
    fi
    exit 0
fi

read -p "确定要卸载 SubConverter-Extended 吗？(y/N): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    log_info "取消卸载"
    exit 0
fi

echo ""
log_info "开始卸载..."

# 停止并删除容器
cd "$INSTALL_DIR"
if [[ -f docker-compose.yml ]]; then
    log_info "停止并删除容器..."
    docker compose down -v 2>/dev/null || true
fi

# 删除安装目录
log_info "删除安装目录..."
rm -rf "$INSTALL_DIR"

# 删除管理命令
if [[ -f /usr/local/bin/subconverter ]]; then
    log_info "删除管理命令..."
    rm -f /usr/local/bin/subconverter
fi

echo ""
log_info "=========================================="
log_info "  卸载完成！"
log_info "=========================================="
echo ""
log_info "Docker 未被删除，如需删除请手动执行:"
echo "  apt-get remove -y docker-ce docker-ce-cli containerd.io"
echo ""
