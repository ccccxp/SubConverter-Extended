#!/usr/bin/env bash
#
# SubConverter-Extended 一键安装脚本
# 支持: Ubuntu 20.04/22.04/24.04/25.04, Debian 11/12
#
# 使用方法:
#   curl -fsSL https://raw.githubusercontent.com/ccccxp/SubConverter-Extended/master/scripts/install.sh | sudo bash
#
# 或者:
#   wget -qO- https://raw.githubusercontent.com/ccccxp/SubConverter-Extended/master/scripts/install.sh | sudo bash
#

set -euo pipefail

# ==================== 配置变量 ====================
REPO_RAW_BASE="https://raw.githubusercontent.com/ccccxp/SubConverter-Extended/master"
INSTALL_DIR="/opt/SubConverter-Extended"
SERVICE_NAME="subconverter-extended"
DEFAULT_PORT="25500"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ==================== 辅助函数 ====================
print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║         SubConverter-Extended 一键安装脚本                    ║"
    echo "║         https://github.com/ccccxp/SubConverter-Extended       ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        log_info "请使用: sudo bash $0"
        exit 1
    fi
}

check_system() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "无法检测操作系统类型"
        exit 1
    fi
    
    source /etc/os-release
    
    case "$ID" in
        ubuntu|debian)
            log_info "检测到系统: $PRETTY_NAME"
            PKG_MANAGER="apt-get"
            ;;
        centos|rhel|fedora|rocky|almalinux)
            log_info "检测到系统: $PRETTY_NAME"
            PKG_MANAGER="yum"
            if command -v dnf &> /dev/null; then
                PKG_MANAGER="dnf"
            fi
            ;;
        *)
            log_warn "未经测试的系统: $PRETTY_NAME，将尝试继续安装..."
            PKG_MANAGER="apt-get"
            ;;
    esac
}

get_public_ip() {
    local ip=""
    # 尝试多个服务获取公网 IP
    ip=$(curl -4 -s --connect-timeout 5 https://api.ipify.org 2>/dev/null) || \
    ip=$(curl -4 -s --connect-timeout 5 https://ifconfig.me 2>/dev/null) || \
    ip=$(curl -4 -s --connect-timeout 5 https://icanhazip.com 2>/dev/null) || \
    ip=$(curl -4 -s --connect-timeout 5 https://ipecho.net/plain 2>/dev/null) || \
    ip=""
    
    echo "$ip"
}

# ==================== Docker 安装 ====================
install_docker_ubuntu_debian() {
    log_step "安装 Docker 依赖包..."
    $PKG_MANAGER update -y
    $PKG_MANAGER install -y ca-certificates curl gnupg lsb-release apt-transport-https software-properties-common
    
    log_step "添加 Docker 官方 GPG 密钥..."
    install -m 0755 -d /etc/apt/keyrings
    
    if [[ "$ID" == "ubuntu" ]]; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null || true
        chmod a+r /etc/apt/keyrings/docker.gpg
        
        # 获取版本代号，如果不存在则使用 jammy 作为后备
        local codename="${VERSION_CODENAME:-jammy}"
        # Ubuntu 25.04 可能尚未被 Docker 官方支持，使用 noble 作为后备
        if ! curl -s "https://download.docker.com/linux/ubuntu/dists/${codename}/Release" &>/dev/null; then
            log_warn "Docker 尚未支持 ${codename}，尝试使用 noble..."
            codename="noble"
        fi
        
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${codename} stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    else
        curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null || true
        chmod a+r /etc/apt/keyrings/docker.gpg
        
        local codename="${VERSION_CODENAME:-bookworm}"
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${codename} stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    fi
    
    log_step "安装 Docker Engine..."
    $PKG_MANAGER update -y
    $PKG_MANAGER install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_docker_rhel() {
    log_step "安装 Docker 依赖包..."
    $PKG_MANAGER install -y yum-utils device-mapper-persistent-data lvm2
    
    log_step "添加 Docker 仓库..."
    $PKG_MANAGER config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || \
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    
    log_step "安装 Docker Engine..."
    $PKG_MANAGER install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_docker() {
    if command -v docker &> /dev/null; then
        log_info "Docker 已安装，版本: $(docker --version)"
        
        # 检查 docker compose 插件
        if docker compose version &> /dev/null; then
            log_info "Docker Compose 插件已安装"
        else
            log_warn "Docker Compose 插件未安装，尝试安装..."
            $PKG_MANAGER update -y
            $PKG_MANAGER install -y docker-compose-plugin || true
        fi
        return 0
    fi
    
    log_step "开始安装 Docker..."
    
    case "$PKG_MANAGER" in
        apt-get)
            install_docker_ubuntu_debian
            ;;
        yum|dnf)
            install_docker_rhel
            ;;
        *)
            log_error "不支持的包管理器: $PKG_MANAGER"
            exit 1
            ;;
    esac
    
    # 启动 Docker 服务
    log_step "启动 Docker 服务..."
    systemctl enable docker
    systemctl start docker
    
    # 验证安装
    if docker --version &> /dev/null; then
        log_info "Docker 安装成功: $(docker --version)"
    else
        log_error "Docker 安装失败"
        exit 1
    fi
}

# ==================== 部署服务 ====================
deploy_service() {
    log_step "创建安装目录: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/base"
    cd "$INSTALL_DIR"
    
    log_step "下载 docker-compose.yml..."
    curl -fsSL "$REPO_RAW_BASE/docker-compose.yml" -o docker-compose.yml
    
    log_step "下载配置文件 pref.toml..."
    curl -fsSL "$REPO_RAW_BASE/base/pref.example.toml" -o base/pref.toml
    
    # 获取公网 IP 并更新配置
    log_step "检测服务器公网 IP..."
    PUBLIC_IP=$(get_public_ip)
    
    if [[ -n "$PUBLIC_IP" ]]; then
        log_info "检测到公网 IP: $PUBLIC_IP"
        log_step "更新配置文件中的 managed_config_prefix..."
        sed -i "s|managed_config_prefix = \"http://127.0.0.1:25500\"|managed_config_prefix = \"http://${PUBLIC_IP}:${DEFAULT_PORT}\"|g" base/pref.toml
    else
        log_warn "无法检测公网 IP，请手动修改 $INSTALL_DIR/base/pref.toml 中的 managed_config_prefix"
    fi
    
    log_step "拉取 Docker 镜像..."
    docker compose pull
    
    log_step "启动服务..."
    docker compose up -d
    
    # 等待服务启动
    sleep 3
}

# ==================== 创建管理脚本 ====================
create_management_scripts() {
    log_step "创建管理脚本..."
    
    # 创建 subconverter 命令
    cat > /usr/local/bin/subconverter << 'SCRIPT_EOF'
#!/usr/bin/env bash
set -e

INSTALL_DIR="/opt/SubConverter-Extended"
cd "$INSTALL_DIR"

case "${1:-}" in
    start)
        echo "启动 SubConverter-Extended..."
        docker compose up -d
        ;;
    stop)
        echo "停止 SubConverter-Extended..."
        docker compose down
        ;;
    restart)
        echo "重启 SubConverter-Extended..."
        docker compose restart
        ;;
    status)
        docker compose ps
        ;;
    logs)
        docker compose logs -f --tail=100
        ;;
    update)
        echo "更新 SubConverter-Extended..."
        docker compose pull
        docker compose up -d
        echo "更新完成！"
        ;;
    config)
        echo "配置文件位置: $INSTALL_DIR/base/pref.toml"
        echo ""
        echo "使用以下命令编辑配置:"
        echo "  nano $INSTALL_DIR/base/pref.toml"
        echo ""
        echo "编辑后请运行: subconverter restart"
        ;;
    uninstall)
        echo "卸载 SubConverter-Extended..."
        read -p "确定要卸载吗？(y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            docker compose down -v
            rm -rf "$INSTALL_DIR"
            rm -f /usr/local/bin/subconverter
            echo "卸载完成！"
        else
            echo "取消卸载"
        fi
        ;;
    *)
        echo "SubConverter-Extended 管理命令"
        echo ""
        echo "用法: subconverter <命令>"
        echo ""
        echo "可用命令:"
        echo "  start      启动服务"
        echo "  stop       停止服务"
        echo "  restart    重启服务"
        echo "  status     查看状态"
        echo "  logs       查看日志"
        echo "  update     更新到最新版本"
        echo "  config     查看配置信息"
        echo "  uninstall  卸载服务"
        ;;
esac
SCRIPT_EOF

    chmod +x /usr/local/bin/subconverter
    log_info "管理命令已创建: subconverter"
}

# ==================== 配置防火墙 ====================
configure_firewall() {
    log_step "配置防火墙..."
    
    # UFW (Ubuntu/Debian)
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            log_info "检测到 UFW 防火墙，开放端口 $DEFAULT_PORT..."
            ufw allow "$DEFAULT_PORT/tcp" || true
        fi
    fi
    
    # firewalld (CentOS/RHEL)
    if command -v firewall-cmd &> /dev/null; then
        if systemctl is-active --quiet firewalld; then
            log_info "检测到 firewalld，开放端口 $DEFAULT_PORT..."
            firewall-cmd --permanent --add-port="$DEFAULT_PORT/tcp" || true
            firewall-cmd --reload || true
        fi
    fi
}

# ==================== 验证安装 ====================
verify_installation() {
    log_step "验证安装..."
    
    # 检查容器状态
    if docker compose ps 2>/dev/null | grep -q "Up"; then
        log_info "容器运行正常"
    else
        log_error "容器未正常运行"
        docker compose logs --tail=50
        exit 1
    fi
    
    # 检查服务响应
    sleep 2
    if curl -s "http://localhost:$DEFAULT_PORT/version" &>/dev/null; then
        VERSION_INFO=$(curl -s "http://localhost:$DEFAULT_PORT/version")
        log_info "服务响应正常: $VERSION_INFO"
    else
        log_warn "服务暂时无法响应，请稍后检查"
    fi
}

# ==================== 打印安装信息 ====================
print_success_info() {
    PUBLIC_IP=$(get_public_ip)
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              安装成功！                                        ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}服务信息:${NC}"
    echo -e "  本地访问: http://localhost:$DEFAULT_PORT"
    if [[ -n "$PUBLIC_IP" ]]; then
        echo -e "  公网访问: http://$PUBLIC_IP:$DEFAULT_PORT"
        echo -e "  版本检查: http://$PUBLIC_IP:$DEFAULT_PORT/version"
    fi
    echo ""
    echo -e "${CYAN}API 使用示例:${NC}"
    if [[ -n "$PUBLIC_IP" ]]; then
        echo -e "  转换接口: http://$PUBLIC_IP:$DEFAULT_PORT/sub?target=clash&url=<订阅链接>"
    else
        echo -e "  转换接口: http://<服务器IP>:$DEFAULT_PORT/sub?target=clash&url=<订阅链接>"
    fi
    echo ""
    echo -e "${CYAN}管理命令:${NC}"
    echo -e "  subconverter start     # 启动服务"
    echo -e "  subconverter stop      # 停止服务"
    echo -e "  subconverter restart   # 重启服务"
    echo -e "  subconverter status    # 查看状态"
    echo -e "  subconverter logs      # 查看日志"
    echo -e "  subconverter update    # 更新版本"
    echo -e "  subconverter uninstall # 卸载服务"
    echo ""
    echo -e "${CYAN}配置文件:${NC}"
    echo -e "  $INSTALL_DIR/base/pref.toml"
    echo ""
    echo -e "${YELLOW}提示: 如需使用前端界面，请访问 https://acl4ssr-sub.github.io/${NC}"
    echo -e "${YELLOW}      并将后端地址设置为: http://$PUBLIC_IP:$DEFAULT_PORT/sub?${NC}"
    echo ""
}

# ==================== 主流程 ====================
main() {
    print_banner
    check_root
    check_system
    install_docker
    deploy_service
    create_management_scripts
    configure_firewall
    verify_installation
    print_success_info
}

# 执行主流程
main "$@"
