# Cloudflare WARP 代理安装器

🚀 一键安装脚本，让您的服务器通过 Cloudflare WARP 网络访问互联网，避免 IP 限制和异常流量检测。

[English](README.md) | 简体中文

## ✨ 特性

- 🔒 **安全稳定**：基于 WireGuard + Cloudflare WARP
- 🚄 **高性能**：内核级 VPN，低延迟高吞吐
- 🎯 **精准控制**：支持 SOCKS5 和 HTTP 代理
- 🐳 **Docker 友好**：自动配置 Docker 代理
- 🔄 **开机自启**：服务自动启动，无需手动干预
- 📦 **一键安装/卸载**：简单易用

## 🎯 使用场景

- ✅ 绕过 Google/Gemini 的异常流量检测
- ✅ 避免 IP 限制和封禁
- ✅ Coolify/Docker 应用代理
- ✅ 服务器出口 IP 变更
- ✅ 提高访问速度和稳定性

## 📋 系统要求

- **操作系统**：Ubuntu 20.04+ / Debian 11+
- **架构**：x86_64 (amd64)
- **权限**：Root 或 sudo
- **网络**：能访问 GitHub 和 Cloudflare

## 🚀 快速开始

### 一键安装

```bash
wget https://raw.githubusercontent.com/tszxy/cloudflare-warp-proxy/main/install.sh
chmod +x install.sh
sudo bash install.sh
```

或使用一行命令：

```bash
bash <(wget -qO- https://raw.githubusercontent.com/tszxy/cloudflare-warp-proxy/main/install.sh)
```

## 📖 安装过程

脚本会自动完成：

1. ✅ 检查系统环境
2. ✅ 安装依赖（WireGuard、wgcf、Xray）
3. ✅ 注册 Cloudflare WARP 账号
4. ✅ 生成 WireGuard 配置
5. ✅ 配置 Xray 代理
6. ✅ 设置系统和 Docker 代理
7. ✅ 运行连接测试

**安装时间**：约 2-5 分钟

## 🔧 使用方法

### 测试代理

```bash
# SOCKS5 代理
curl --socks5 127.0.0.1:10808 https://api.ipify.org

# HTTP 代理
curl --proxy http://127.0.0.1:10809 https://api.ipify.org

# 查看出口 IP
curl https://api.ipify.org
```

### 在 Coolify 中使用

在应用环境变量中添加：

```env
HTTP_PROXY=http://172.17.0.1:10809
HTTPS_PROXY=http://172.17.0.1:10809
NO_PROXY=localhost,127.0.0.1
```

### 在 Docker 中使用

```bash
docker run -d \
  -e HTTP_PROXY=http://172.17.0.1:10809 \
  -e HTTPS_PROXY=http://172.17.0.1:10809 \
  your-image
```

## 🛠️ 管理命令

### 查看状态

```bash
# WireGuard 状态
sudo systemctl status wg-quick@wgcf

# Xray 状态
sudo systemctl status xray

# 查看连接信息
sudo wg show
```

### 重启服务

```bash
# 重启 WireGuard
sudo wg-quick down wgcf && sudo wg-quick up wgcf

# 重启 Xray
sudo systemctl restart xray
```

### 查看日志

```bash
# WireGuard 日志
sudo journalctl -u wg-quick@wgcf -f

# Xray 日志
sudo journalctl -u xray -f
```

## 🗑️ 卸载

```bash
sudo bash install.sh uninstall
```

## 📂 配置文件

| 组件 | 路径 |
|------|------|
| WireGuard | `/etc/wireguard/wgcf.conf` |
| Xray | `/usr/local/etc/xray/config.json` |
| 系统代理 | `/etc/environment` |
| Docker 代理 | `/etc/systemd/system/docker.service.d/http-proxy.conf` |

## 🔍 故障排查

### 常见问题

**1. 安装失败**

```bash
# 查看日志
sudo journalctl -xe

# 检查网络
ping github.com
ping engage.cloudflareclient.com
```

**2. 代理无法使用**

```bash
# 检查端口
sudo ss -tlnp | grep -E '10808|10809'

# 测试 WireGuard
curl --interface wgcf https://api.ipify.org

# 重启服务
sudo systemctl restart wg-quick@wgcf xray
```

**3. SSH 断开**

通过服务商控制台执行：

```bash
sudo wg-quick down wgcf
```

## 📊 工作原理

```
应用 → Xray (10808/10809) → WireGuard → Cloudflare WARP → 互联网
```

1. 应用请求通过 Xray 代理
2. Xray 将流量转发到 WireGuard
3. WireGuard 建立到 Cloudflare 的加密隧道
4. 流量显示为 Cloudflare IP

## 🙏 致谢

- [WireGuard](https://www.wireguard.com/)
- [Cloudflare WARP](https://1.1.1.1/)
- [wgcf](https://github.com/ViRb3/wgcf)
- [Xray](https://github.com/XTLS/Xray-core)

## 📄 许可证

MIT License

## ⚠️ 免责声明

本项目仅供学习研究使用，请遵守当地法律法规。

## 🌟 支持项目

如果这个项目对您有帮助，请给个 Star ⭐️

---

**Made with ❤️ by Claude & Community**
