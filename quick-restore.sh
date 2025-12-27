#!/bin/bash

##############################################
# Cloudflare WARP 快速恢复脚本
# 用途：新系统一键恢复配置
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

echo ""
echo "================================"
echo "新系统快速恢复"
echo "Cloudflare WARP Proxy"
echo "================================"
echo ""

# 检查备份文件
log_info "检查备份文件..."
cd /root

if ! ls warp-backup-*.tar.gz 1> /dev/null 2>&1; then
    log_error "未找到备份文件！"
    echo ""
    echo "请先上传备份文件到 /root/ 目录："
    echo "  scp warp-backup-*.tar.gz root@server:/root/"
    echo ""
    exit 1
fi

BACKUP_FILE=$(ls warp-backup-*.tar.gz | head -1)
log_success "找到备份文件: $BACKUP_FILE"
echo ""

# 步骤 1：安装基础环境
log_info "步骤 1/4: 安装基础环境..."
echo "------------------------------------------------"

if ! command -v wg &> /dev/null || ! command -v xray &> /dev/null; then
    log_info "下载安装脚本..."
    wget -q https://raw.githubusercontent.com/tszxy/cloudflare-warp-proxy/main/install.sh -O /tmp/install.sh
    chmod +x /tmp/install.sh
    
    log_info "运行安装（这可能需要 2-5 分钟）..."
    bash /tmp/install.sh
    
    log_success "✓ 基础环境安装完成"
else
    log_warning "检测到已安装的组件，跳过安装步骤"
fi

echo ""

# 步骤 2：解压备份
log_info "步骤 2/4: 解压备份..."
echo "------------------------------------------------"

log_info "解压 $BACKUP_FILE ..."
tar -xzf "$BACKUP_FILE"

BACKUP_DIR=$(tar -tzf "$BACKUP_FILE" | head -1 | cut -f1 -d"/")
if [ -z "$BACKUP_DIR" ]; then
    log_error "无法确定备份目录"
    exit 1
fi

log_success "✓ 备份已解压到: /root/$BACKUP_DIR"
echo ""

# 步骤 3：恢复配置
log_info "步骤 3/4: 恢复配置..."
echo "------------------------------------------------"

cd "/root/$BACKUP_DIR"

if [ ! -f restore.sh ]; then
    log_error "备份中未找到恢复脚本"
    exit 1
fi

log_info "运行恢复脚本..."
bash restore.sh

log_success "✓ 配置恢复完成"
echo ""

# 步骤 4：重启服务
log_info "步骤 4/4: 重启服务..."
echo "------------------------------------------------"

log_info "重启 WireGuard..."
wg-quick down wgcf 2>/dev/null || true
sleep 2
wg-quick up wgcf

log_info "重启 Xray..."
systemctl restart xray

if command -v docker &> /dev/null; then
    log_info "重启 Docker..."
    systemctl restart docker
fi

log_success "✓ 所有服务已重启"
echo ""

# 等待服务启动
log_info "等待服务启动..."
sleep 5

# 验证恢复
echo ""
echo "================================"
echo "验证恢复"
echo "================================"
echo ""

# 检查服务状态
log_info "检查服务状态..."

if systemctl is-active --quiet wg-quick@wgcf; then
    echo -e "${GREEN}✓${NC} WireGuard: 运行中"
else
    echo -e "${RED}✗${NC} WireGuard: 未运行"
fi

if systemctl is-active --quiet xray; then
    echo -e "${GREEN}✓${NC} Xray: 运行中"
else
    echo -e "${RED}✗${NC} Xray: 未运行"
fi

echo ""

# 测试连接
log_info "测试连接..."
echo ""

echo -n "WireGuard 接口 IP: "
WGCF_IP=$(curl --interface wgcf -s --max-time 10 https://api.ipify.org 2>/dev/null || echo "失败")
if [[ "$WGCF_IP" != "失败" ]]; then
    echo -e "${GREEN}$WGCF_IP${NC}"
else
    echo -e "${RED}$WGCF_IP${NC}"
fi

echo -n "Xray SOCKS5 代理: "
SOCKS_IP=$(curl --socks5 127.0.0.1:10808 -s --max-time 10 https://api.ipify.org 2>/dev/null || echo "失败")
if [[ "$SOCKS_IP" != "失败" ]]; then
    echo -e "${GREEN}$SOCKS_IP${NC}"
else
    echo -e "${RED}$SOCKS_IP${NC}"
fi

echo -n "Xray HTTP 代理:   "
HTTP_IP=$(curl --proxy http://127.0.0.1:10809 -s --max-time 10 https://api.ipify.org 2>/dev/null || echo "失败")
if [[ "$HTTP_IP" != "失败" ]]; then
    echo -e "${GREEN}$HTTP_IP${NC}"
else
    echo -e "${RED}$HTTP_IP${NC}"
fi

echo -n "系统默认 IP:      "
DEFAULT_IP=$(curl -s --max-time 10 https://api.ipify.org 2>/dev/null || echo "失败")
if [[ "$DEFAULT_IP" != "失败" ]]; then
    echo -e "${GREEN}$DEFAULT_IP${NC}"
else
    echo -e "${RED}$DEFAULT_IP${NC}"
fi

echo -n "直连 IP:          "
DIRECT_IP=$(curl --noproxy '*' -s --max-time 10 https://api.ipify.org 2>/dev/null || echo "失败")
if [[ "$DIRECT_IP" != "失败" ]]; then
    echo -e "${BLUE}$DIRECT_IP${NC}"
else
    echo -e "${RED}$DIRECT_IP${NC}"
fi

echo ""

# 测试 Google 访问
echo -n "Google 访问:      "
GOOGLE_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 https://www.google.com 2>/dev/null || echo "000")
if [[ "$GOOGLE_CODE" == "200" ]] || [[ "$GOOGLE_CODE" == "301" ]] || [[ "$GOOGLE_CODE" == "302" ]]; then
    echo -e "${GREEN}HTTP $GOOGLE_CODE ✓${NC}"
else
    echo -e "${RED}HTTP $GOOGLE_CODE ✗${NC}"
fi

echo -n "Gemini 访问:      "
GEMINI_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 https://gemini.google.com 2>/dev/null || echo "000")
if [[ "$GEMINI_CODE" == "200" ]] || [[ "$GEMINI_CODE" == "301" ]] || [[ "$GEMINI_CODE" == "302" ]]; then
    echo -e "${GREEN}HTTP $GEMINI_CODE ✓${NC}"
else
    echo -e "${RED}HTTP $GEMINI_CODE ✗${NC}"
fi

echo ""

# 总结
echo "================================"
echo "恢复完成！"
echo "================================"
echo ""
echo "配置信息："
echo "  SOCKS5 代理: 127.0.0.1:10808"
echo "  HTTP 代理:   127.0.0.1:10809"
echo ""
echo "使用方法："
echo "  curl --socks5 127.0.0.1:10808 https://api.ipify.org"
echo "  curl --proxy http://127.0.0.1:10809 https://api.ipify.org"
echo ""
echo "服务管理："
echo "  查看状态: systemctl status wg-quick@wgcf xray"
echo "  重启服务: systemctl restart wg-quick@wgcf xray"
echo "  查看日志: journalctl -u wg-quick@wgcf -f"
echo ""

# 清理提示
echo "清理建议："
echo "  备份文件可以删除: rm /root/$BACKUP_FILE"
echo "  备份目录可以删除: rm -rf /root/$BACKUP_DIR"
echo ""

# 检查是否有失败的测试
if [[ "$WGCF_IP" == "失败" ]] || [[ "$SOCKS_IP" == "失败" ]] || [[ "$HTTP_IP" == "失败" ]]; then
    log_warning "部分测试失败，请检查日志："
    echo "  sudo journalctl -u wg-quick@wgcf -n 50"
    echo "  sudo journalctl -u xray -n 50"
    echo ""
    exit 1
fi

log_success "所有测试通过！系统恢复成功！"
echo ""
