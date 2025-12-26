#!/bin/bash

##############################################
# Cloudflare WARP + Xray 代理一键安装脚本
# 用途：让服务器通过 Cloudflare 网络访问互联网
# 作者：Claude
# 日期：2025-12-26
##############################################

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为 root 用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        log_info "请使用: sudo bash $0"
        exit 1
    fi
}

# 检查系统
check_system() {
    log_info "检查系统环境..."
    
    if [[ ! -f /etc/os-release ]]; then
        log_error "无法检测系统版本"
        exit 1
    fi
    
    . /etc/os-release
    
    if [[ "$ID" != "ubuntu" ]] && [[ "$ID" != "debian" ]]; then
        log_warning "此脚本主要为 Ubuntu/Debian 设计，其他系统可能需要手动调整"
    fi
    
    log_success "系统检查完成: $PRETTY_NAME"
}

# 安装依赖
install_dependencies() {
    log_info "安装系统依赖..."
    
    apt update
    apt install -y curl wget unzip iptables
    
    log_success "依赖安装完成"
}

# 安装 WireGuard
install_wireguard() {
    log_info "安装 WireGuard..."
    
    if command -v wg &> /dev/null; then
        log_warning "WireGuard 已安装，跳过"
        return
    fi
    
    apt install -y wireguard-tools
    
    log_success "WireGuard 安装完成"
}

# 安装 wgcf
install_wgcf() {
    log_info "安装 wgcf 工具..."
    
    if command -v wgcf &> /dev/null; then
        log_warning "wgcf 已安装，跳过"
        return
    fi
    
    cd /tmp
    wget -q https://github.com/ViRb3/wgcf/releases/download/v2.2.22/wgcf_2.2.22_linux_amd64
    chmod +x wgcf_2.2.22_linux_amd64
    mv wgcf_2.2.22_linux_amd64 /usr/local/bin/wgcf
    
    log_success "wgcf 安装完成"
}

# 注册 WARP
register_warp() {
    log_info "注册 Cloudflare WARP 账号..."
    
    cd /root
    
    if [[ -f wgcf-account.toml ]]; then
        log_warning "WARP 账号已存在，跳过注册"
        return
    fi
    
    # 自动接受 ToS
    echo "y" | wgcf register
    
    if [[ ! -f wgcf-account.toml ]]; then
        log_error "WARP 注册失败"
        exit 1
    fi
    
    log_success "WARP 注册完成"
}

# 生成 WireGuard 配置
generate_wg_config() {
    log_info "生成 WireGuard 配置..."
    
    cd /root
    
    if [[ -f wgcf-profile.conf ]]; then
        log_warning "配置文件已存在，将覆盖"
    fi
    
    wgcf generate
    
    if [[ ! -f wgcf-profile.conf ]]; then
        log_error "配置生成失败"
        exit 1
    fi
    
    # 提取密钥和地址
    PRIVATE_KEY=$(grep '^PrivateKey' wgcf-profile.conf | cut -d' ' -f3)
    IPV4_ADDR=$(grep '^Address' wgcf-profile.conf | head -1 | cut -d' ' -f3)
    IPV6_ADDR=$(grep '^Address' wgcf-profile.conf | tail -1 | cut -d' ' -f3)
    PUBLIC_KEY=$(grep '^PublicKey' wgcf-profile.conf | cut -d' ' -f3)
    ENDPOINT=$(grep '^Endpoint' wgcf-profile.conf | cut -d' ' -f3)
    
    # 创建优化的配置
    cat > /etc/wireguard/wgcf.conf << EOF
[Interface]
PrivateKey = ${PRIVATE_KEY}
Address = ${IPV4_ADDR}
Address = ${IPV6_ADDR}
DNS = 1.1.1.1
MTU = 1280
Table = off
PostUp = ip rule add from ${IPV4_ADDR%%/*} table 100; ip route add default dev wgcf table 100
PostDown = ip rule del from ${IPV4_ADDR%%/*} table 100

[Peer]
PublicKey = ${PUBLIC_KEY}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = ${ENDPOINT}
PersistentKeepalive = 25
EOF
    
    log_success "WireGuard 配置生成完成"
}

# 启动 WireGuard
start_wireguard() {
    log_info "启动 WireGuard..."
    
    # 停止现有连接（如果有）
    wg-quick down wgcf 2>/dev/null || true
    
    # 启动
    wg-quick up wgcf
    
    # 设置开机自启
    systemctl enable wg-quick@wgcf
    
    # 测试连接
    sleep 3
    local TEST_IP=$(curl --interface wgcf -s --max-time 10 https://api.ipify.org || echo "")
    
    if [[ -z "$TEST_IP" ]]; then
        log_error "WireGuard 连接失败"
        exit 1
    fi
    
    log_success "WireGuard 启动成功，出口 IP: ${TEST_IP}"
}

# 安装 Xray
install_xray() {
    log_info "安装 Xray..."
    
    if command -v xray &> /dev/null; then
        log_warning "Xray 已安装，跳过"
        return
    fi
    
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    
    log_success "Xray 安装完成"
}

# 配置 Xray
configure_xray() {
    log_info "配置 Xray..."
    
    mkdir -p /usr/local/etc/xray
    
    cat > /usr/local/etc/xray/config.json << 'EOF'
{
  "log": {
    "loglevel": "info"
  },
  "inbounds": [
    {
      "port": 10808,
      "listen": "127.0.0.1",
      "protocol": "socks",
      "settings": {
        "auth": "noauth",
        "udp": true
      },
      "tag": "socks-in"
    },
    {
      "port": 10809,
      "listen": "127.0.0.1",
      "protocol": "http",
      "tag": "http-in"
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "UseIP"
      },
      "streamSettings": {
        "sockopt": {
          "interface": "wgcf"
        }
      },
      "tag": "warp"
    },
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "direct"
      }
    ]
  }
}
EOF
    
    # 验证配置
    xray -test -c /usr/local/etc/xray/config.json
    
    log_success "Xray 配置完成"
}

# 启动 Xray
start_xray() {
    log_info "启动 Xray..."
    
    systemctl restart xray
    systemctl enable xray
    
    sleep 2
    
    if ! systemctl is-active --quiet xray; then
        log_error "Xray 启动失败"
        systemctl status xray
        exit 1
    fi
    
    # 测试代理
    local TEST_IP=$(curl --socks5 127.0.0.1:10808 -s --max-time 10 https://api.ipify.org || echo "")
    
    if [[ -z "$TEST_IP" ]]; then
        log_error "Xray 代理测试失败"
        exit 1
    fi
    
    log_success "Xray 启动成功，代理 IP: ${TEST_IP}"
}

# 配置系统代理
configure_system_proxy() {
    log_info "配置系统代理..."
    
    # 检查是否已配置
    if grep -q "HTTP_PROXY=" /etc/environment 2>/dev/null; then
        log_warning "系统代理已配置，跳过"
        return
    fi
    
    cat >> /etc/environment << 'EOF'
HTTP_PROXY="http://127.0.0.1:10809"
HTTPS_PROXY="http://127.0.0.1:10809"
NO_PROXY="localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
EOF
    
    log_success "系统代理配置完成"
}

# 配置 Docker 代理
configure_docker_proxy() {
    log_info "配置 Docker 代理..."
    
    if ! command -v docker &> /dev/null; then
        log_warning "Docker 未安装，跳过 Docker 代理配置"
        return
    fi
    
    mkdir -p /etc/systemd/system/docker.service.d
    
    cat > /etc/systemd/system/docker.service.d/http-proxy.conf << 'EOF'
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:10809"
Environment="HTTPS_PROXY=http://127.0.0.1:10809"
Environment="NO_PROXY=localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
EOF
    
    systemctl daemon-reload
    systemctl restart docker
    
    log_success "Docker 代理配置完成"
}

# 运行测试
run_tests() {
    log_info "运行连接测试..."
    
    echo ""
    echo "================================"
    echo "连接测试结果"
    echo "================================"
    
    echo -n "1. WireGuard 接口: "
    curl --interface wgcf -s --max-time 10 https://api.ipify.org || echo "失败"
    
    echo -n "2. Xray SOCKS5: "
    curl --socks5 127.0.0.1:10808 -s --max-time 10 https://api.ipify.org || echo "失败"
    
    echo -n "3. Xray HTTP: "
    curl --proxy http://127.0.0.1:10809 -s --max-time 10 https://api.ipify.org || echo "失败"
    
    echo -n "4. 直连 (本机 IP): "
    curl --noproxy '*' -s --max-time 10 https://api.ipify.org || echo "失败"
    
    echo ""
    echo -n "5. Google 访问测试: "
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 https://www.google.com)
    echo "HTTP ${HTTP_CODE}"
    
    echo -n "6. Gemini 访问测试: "
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 https://gemini.google.com)
    echo "HTTP ${HTTP_CODE}"
    
    echo "================================"
    echo ""
}

# 显示使用说明
show_usage() {
    echo ""
    echo "================================"
    echo "安装完成！"
    echo "================================"
    echo ""
    echo "代理端口："
    echo "  SOCKS5: 127.0.0.1:10808"
    echo "  HTTP:   127.0.0.1:10809"
    echo ""
    echo "测试命令："
    echo "  curl --socks5 127.0.0.1:10808 https://api.ipify.org"
    echo "  curl --proxy http://127.0.0.1:10809 https://api.ipify.org"
    echo ""
    echo "服务管理："
    echo "  WireGuard: systemctl status wg-quick@wgcf"
    echo "  Xray:      systemctl status xray"
    echo ""
    echo "重启服务："
    echo "  sudo wg-quick down wgcf && sudo wg-quick up wgcf"
    echo "  sudo systemctl restart xray"
    echo ""
    echo "查看日志："
    echo "  sudo journalctl -u wg-quick@wgcf -f"
    echo "  sudo journalctl -u xray -f"
    echo ""
    echo "在 Coolify 应用中使用代理："
    echo "  添加环境变量："
    echo "    HTTP_PROXY=http://172.17.0.1:10809"
    echo "    HTTPS_PROXY=http://172.17.0.1:10809"
    echo "    NO_PROXY=localhost,127.0.0.1"
    echo ""
    echo "配置文件位置："
    echo "  WireGuard: /etc/wireguard/wgcf.conf"
    echo "  Xray:      /usr/local/etc/xray/config.json"
    echo ""
    echo "================================"
}

# 清理函数
cleanup() {
    log_info "清理临时文件..."
    cd /root
    rm -f wgcf_*.tar.gz xray-*.zip
}

# 卸载函数
uninstall() {
    log_warning "开始卸载..."
    
    # 停止服务
    systemctl stop xray 2>/dev/null || true
    systemctl disable xray 2>/dev/null || true
    wg-quick down wgcf 2>/dev/null || true
    systemctl disable wg-quick@wgcf 2>/dev/null || true
    
    # 删除文件
    rm -f /usr/local/bin/wgcf
    rm -f /etc/wireguard/wgcf.conf
    rm -rf /usr/local/etc/xray
    rm -rf /root/wgcf-*
    rm -f /etc/systemd/system/docker.service.d/http-proxy.conf
    
    # 清理环境变量
    sed -i '/HTTP_PROXY=/d' /etc/environment
    sed -i '/HTTPS_PROXY=/d' /etc/environment
    sed -i '/NO_PROXY=/d' /etc/environment
    
    log_success "卸载完成"
}

# 主函数
main() {
    echo ""
    echo "================================"
    echo "Cloudflare WARP + Xray 代理"
    echo "一键安装脚本"
    echo "================================"
    echo ""
    
    # 检查参数
    if [[ "$1" == "uninstall" ]]; then
        check_root
        uninstall
        exit 0
    fi
    
    check_root
    check_system
    
    log_info "开始安装..."
    echo ""
    
    install_dependencies
    install_wireguard
    install_wgcf
    register_warp
    generate_wg_config
    start_wireguard
    
    install_xray
    configure_xray
    start_xray
    
    configure_system_proxy
    configure_docker_proxy
    
    cleanup
    
    echo ""
    log_success "所有组件安装完成！"
    echo ""
    
    run_tests
    show_usage
}

# 捕获错误
trap 'log_error "安装过程中出现错误，请检查日志"; exit 1' ERR

# 运行主函数
main "$@"
