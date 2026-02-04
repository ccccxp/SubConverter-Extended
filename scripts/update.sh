#!/usr/bin/env bash
#
# SubConverter-Extended 更新脚本
#

set -euo pipefail

INSTALL_DIR="/opt/SubConverter-Extended"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
    log_error "此脚本需要 root 权限运行"
    exit 1
fi

if [[ ! -d "$INSTALL_DIR" ]]; then
    log_error "未找到安装目录: $INSTALL_DIR"
    log_info "请先运行安装脚本"
    exit 1
fi

echo ""
echo -e "${CYAN}=========================================="
echo "  SubConverter-Extended 更新程序"
echo -e "==========================================${NC}"
echo ""

cd "$INSTALL_DIR"

# 获取当前版本
log_info "获取当前版本..."
CURRENT_VERSION=$(curl -s "http://localhost:25500/version" 2>/dev/null || echo "未知")
log_info "当前版本: $CURRENT_VERSION"

# 拉取新镜像
log_info "拉取最新镜像..."
docker compose pull

# 重新创建容器
log_info "重启服务..."
docker compose up -d

# 等待服务启动
sleep 3

# 获取新版本
NEW_VERSION=$(curl -s "http://localhost:25500/version" 2>/dev/null || echo "未知")
log_info "更新后版本: $NEW_VERSION"

echo ""
log_info "=========================================="
log_info "  更新完成！"
log_info "=========================================="
echo ""

# 清理旧镜像
read -p "是否清理旧的 Docker 镜像以释放空间？(y/N): " cleanup
if [[ "$cleanup" =~ ^[Yy]$ ]]; then
    docker image prune -f
    log_info "已清理旧镜像"
fi
