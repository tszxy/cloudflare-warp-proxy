#!/bin/bash

##############################################
# Cloudflare WARP 配置备份脚本
# 用途：备份所有配置文件和密钥
# 作者：Claude
# 日期：2025-12-26
##############################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
    log_error "此脚本需要 root 权限运行"
    log_info "请使用: sudo bash $0"
    exit 1
fi

# 创建备份目录
BACKUP_DIR="/root/warp-backup-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

log_info "开始备份配置..."
log_info "备份目录: $BACKUP_DIR"
echo ""

# 备份 WireGuard 配置
if [ -f /etc/wireguard/wgcf.conf ]; then
    log_info "备份 WireGuard 配置..."
    cp /etc/wireguard/wgcf.conf "$BACKUP_DIR/"
    log_success "✓ WireGuard 配置已备份"
else
    log_warning "WireGuard 配置文件不存在"
fi

# 备份 WARP 账号信息
if [ -f /root/wgcf-account.toml ]; then
    log_info "备份 WARP 账号信息..."
    cp /root/wgcf-account.toml "$BACKUP_DIR/"
    log_success "✓ WARP 账号信息已备份"
else
    log_warning "WARP 账号文件不存在"
fi

# 备份 Xray 配置
if [ -f /usr/local/etc/xray/config.json ]; then
    log_info "备份 Xray 配置..."
    mkdir -p "$BACKUP_DIR/xray"
    cp /usr/local/etc/xray/config.json "$BACKUP_DIR/xray/"
    log_success "✓ Xray 配置已备份"
else
    log_warning "Xray 配置文件不存在"
fi

# 备份系统代理配置
if grep -q "HTTP_PROXY=" /etc/environment 2>/dev/null; then
    log_info "备份系统代理配置..."
    grep "PROXY=" /etc/environment > "$BACKUP_DIR/environment_proxy.txt"
    log_success "✓ 系统代理配置已备份"
fi

# 备份 Docker 代理配置
if [ -f /etc/systemd/system/docker.service.d/http-proxy.conf ]; then
    log_info "备份 Docker 代理配置..."
    mkdir -p "$BACKUP_DIR/docker"
    cp /etc/systemd/system/docker.service.d/http-proxy.conf "$BACKUP_DIR/docker/"
    log_success "✓ Docker 代理配置已备份"
fi

# 保存服务状态
log_info "保存服务状态..."
cat > "$BACKUP_DIR/service_status.txt" << EOF
# 服务状态信息
备份时间: $(date)
系统信息: $(uname -a)

# WireGuard 状态
$(systemctl is-enabled wg-quick@wgcf 2>/dev/null || echo "未安装")
$(systemctl is-active wg-quick@wgcf 2>/dev/null || echo "未运行")

# Xray 状态
$(systemctl is-enabled xray 2>/dev/null || echo "未安装")
$(systemctl is-active xray 2>/dev/null || echo "未运行")
EOF

# 保存网络信息
log_info "保存网络信息..."
if command -v wg &> /dev/null; then
    wg show > "$BACKUP_DIR/wireguard_status.txt" 2>/dev/null || true
fi

# 保存当前出口 IP
if command -v curl &> /dev/null; then
    log_info "保存当前出口 IP..."
    cat > "$BACKUP_DIR/current_ip.txt" << EOF
# 当前 IP 信息
直连 IP: $(curl --noproxy '*' -s --max-time 5 https://api.ipify.org || echo "无法获取")
代理 IP: $(curl --socks5 127.0.0.1:10808 -s --max-time 5 https://api.ipify.org || echo "无法获取")
WireGuard IP: $(curl --interface wgcf -s --max-time 5 https://api.ipify.org || echo "无法获取")
EOF
fi

# 创建恢复脚本
log_info "创建恢复脚本..."
cat > "$BACKUP_DIR/restore.sh" << 'RESTORE_SCRIPT'
#!/bin/bash

# 恢复脚本
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR]${NC} 需要 root 权限"
    exit 1
fi

BACKUP_DIR="$(cd "$(dirname "$0")" && pwd)"

echo -e "${BLUE}[INFO]${NC} 从备份恢复配置..."
echo -e "${BLUE}[INFO]${NC} 备份目录: $BACKUP_DIR"
echo ""

# 恢复 WireGuard
if [ -f "$BACKUP_DIR/wgcf.conf" ]; then
    echo -e "${BLUE}[INFO]${NC} 恢复 WireGuard 配置..."
    cp "$BACKUP_DIR/wgcf.conf" /etc/wireguard/
    echo -e "${GREEN}[SUCCESS]${NC} ✓ WireGuard 配置已恢复"
fi

# 恢复 WARP 账号
if [ -f "$BACKUP_DIR/wgcf-account.toml" ]; then
    echo -e "${BLUE}[INFO]${NC} 恢复 WARP 账号..."
    cp "$BACKUP_DIR/wgcf-account.toml" /root/
    echo -e "${GREEN}[SUCCESS]${NC} ✓ WARP 账号已恢复"
fi

# 恢复 Xray
if [ -f "$BACKUP_DIR/xray/config.json" ]; then
    echo -e "${BLUE}[INFO]${NC} 恢复 Xray 配置..."
    mkdir -p /usr/local/etc/xray
    cp "$BACKUP_DIR/xray/config.json" /usr/local/etc/xray/
    echo -e "${GREEN}[SUCCESS]${NC} ✓ Xray 配置已恢复"
fi

# 恢复系统代理
if [ -f "$BACKUP_DIR/environment_proxy.txt" ]; then
    echo -e "${BLUE}[INFO]${NC} 恢复系统代理..."
    # 先删除旧的代理配置
    sed -i '/HTTP_PROXY=/d' /etc/environment
    sed -i '/HTTPS_PROXY=/d' /etc/environment
    sed -i '/NO_PROXY=/d' /etc/environment
    # 添加新配置
    cat "$BACKUP_DIR/environment_proxy.txt" >> /etc/environment
    echo -e "${GREEN}[SUCCESS]${NC} ✓ 系统代理已恢复"
fi

# 恢复 Docker 代理
if [ -f "$BACKUP_DIR/docker/http-proxy.conf" ]; then
    echo -e "${BLUE}[INFO]${NC} 恢复 Docker 代理..."
    mkdir -p /etc/systemd/system/docker.service.d
    cp "$BACKUP_DIR/docker/http-proxy.conf" /etc/systemd/system/docker.service.d/
    systemctl daemon-reload
    echo -e "${GREEN}[SUCCESS]${NC} ✓ Docker 代理已恢复"
fi

echo ""
echo -e "${GREEN}[SUCCESS]${NC} 配置恢复完成！"
echo ""
echo "需要重启服务："
echo "  sudo wg-quick down wgcf 2>/dev/null || true"
echo "  sudo wg-quick up wgcf"
echo "  sudo systemctl restart xray"
echo "  sudo systemctl restart docker"
echo ""
RESTORE_SCRIPT

chmod +x "$BACKUP_DIR/restore.sh"

# 创建压缩包
log_info "创建压缩包..."
ARCHIVE_NAME="warp-backup-$(date +%Y%m%d_%H%M%S).tar.gz"
tar -czf "/root/$ARCHIVE_NAME" -C "$(dirname $BACKUP_DIR)" "$(basename $BACKUP_DIR)"

log_success "✓ 压缩包已创建: /root/$ARCHIVE_NAME"

# 创建 README
cat > "$BACKUP_DIR/README.txt" << EOF
Cloudflare WARP 配置备份
========================

备份时间: $(date)
备份目录: $BACKUP_DIR

文件说明:
---------
wgcf.conf               - WireGuard 配置文件
wgcf-account.toml       - WARP 账号信息（包含密钥）
xray/config.json        - Xray 代理配置
environment_proxy.txt   - 系统代理配置
docker/http-proxy.conf  - Docker 代理配置
service_status.txt      - 服务状态信息
wireguard_status.txt    - WireGuard 连接状态
current_ip.txt          - 当前出口 IP
restore.sh              - 一键恢复脚本

使用方法:
---------
1. 恢复配置:
   sudo bash restore.sh

2. 手动恢复某个文件:
   sudo cp wgcf.conf /etc/wireguard/
   sudo cp xray/config.json /usr/local/etc/xray/

3. 重启服务:
   sudo wg-quick down wgcf && sudo wg-quick up wgcf
   sudo systemctl restart xray

注意事项:
---------
- 备份文件包含敏感信息（密钥），请妥善保管
- 建议加密存储或上传到安全的云存储
- 恢复前请确保已安装相关服务
- 恢复后需要重启服务才能生效

压缩包位置:
---------
/root/$ARCHIVE_NAME

可以下载此压缩包到本地保存。
EOF

echo ""
echo "================================"
echo "备份完成！"
echo "================================"
echo ""
echo "备份信息："
echo "  目录: $BACKUP_DIR"
echo "  压缩包: /root/$ARCHIVE_NAME"
echo ""
echo "备份文件："
ls -lh "$BACKUP_DIR/" | grep -v "^total" | awk '{print "  "$9" ("$5")"}'
echo ""
echo "恢复方法："
echo "  1. 解压缩包: tar -xzf /root/$ARCHIVE_NAME"
echo "  2. 运行恢复: cd $(basename $BACKUP_DIR) && sudo bash restore.sh"
echo ""
echo "下载到本地："
echo "  scp root@your-server:/root/$ARCHIVE_NAME ."
echo ""
log_warning "⚠️  备份文件包含敏感信息（密钥），请妥善保管！"
echo "================================"
echo ""
