# Cloudflare WARP Proxy Installer

🚀 一键安装脚本，让您的服务器通过 Cloudflare WARP 网络访问互联网，避免 IP 限制和异常流量检测。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-Linux-blue.svg)](https://www.linux.org/)

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

### 安装

```bash
# 下载脚本
wget https://raw.githubusercontent.com/tszxy/cloudflare-warp-proxy/main/install.sh

# 或使用 curl
curl -O https://raw.githubusercontent.com/tszxy/cloudflare-warp-proxy/main/install.sh

# 赋予执行权限
chmod +x install.sh

# 运行安装
sudo bash install.sh
```

### 一行命令安装

```bash
bash <(wget -qO- https://raw.githubusercontent.com/tszxy/cloudflare-warp-proxy/main/install.sh)
```

## 📖 详细说明

### 安装过程

脚本会自动完成以下步骤：

1. ✅ 检查系统环境
2. ✅ 安装依赖包（WireGuard、wgcf、Xray）
3. ✅ 注册 Cloudflare WARP 账号
4. ✅ 生成 WireGuard 配置
5. ✅ 配置 Xray 代理服务
6. ✅ 设置系统代理
7. ✅ 配置 Docker 代理（如果已安装）
8. ✅ 运行连接测试
9. ✅ 显示使用说明

整个过程大约需要 **2-5 分钟**。

### 代理端口

安装完成后，以下代理端口将可用：

- **SOCKS5**：`127.0.0.1:10808`
- **HTTP/HTTPS**：`127.0.0.1:10809`

### 测试连接

```bash
# 测试 SOCKS5 代理
curl --socks5 127.0.0.1:10808 https://api.ipify.org

# 测试 HTTP 代理
curl --proxy http://127.0.0.1:10809 https://api.ipify.org

# 查看出口 IP
curl https://api.ipify.org
```

## 🐳 Docker / Coolify 使用

### 在 Coolify 中配置

在应用的环境变量中添加：

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

### Docker Compose

```yaml
services:
  app:
    image: your-image
    environment:
      - HTTP_PROXY=http://172.17.0.1:10809
      - HTTPS_PROXY=http://172.17.0.1:10809
      - NO_PROXY=localhost,127.0.0.1
```

## 🔧 管理命令

### 查看服务状态

```bash
# WireGuard 状态
sudo systemctl status wg-quick@wgcf
sudo wg show

# Xray 状态
sudo systemctl status xray
```

### 重启服务

```bash
# 重启 WireGuard
sudo wg-quick down wgcf
sudo wg-quick up wgcf

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

### 开机自启

服务已自动配置为开机自启，无需手动设置。

```bash
# 检查自启状态
sudo systemctl is-enabled wg-quick@wgcf
sudo systemctl is-enabled xray
```

## 🗑️ 卸载

```bash
sudo bash install.sh uninstall
```

卸载会删除：
- WireGuard 配置和账号
- Xray 配置
- 系统代理设置
- Docker 代理设置
- 所有相关服务

## 📂 配置文件位置

| 组件 | 配置文件路径 |
|------|------------|
| WireGuard | `/etc/wireguard/wgcf.conf` |
| Xray | `/usr/local/etc/xray/config.json` |
| 系统代理 | `/etc/environment` |
| Docker 代理 | `/etc/systemd/system/docker.service.d/http-proxy.conf` |
| WARP 账号 | `/root/wgcf-account.toml` |

## 🔍 故障排查

### 安装失败

```bash
# 查看详细日志
sudo journalctl -xe

# 检查网络连接
ping engage.cloudflareclient.com
ping github.com

# 手动检查服务
sudo systemctl status wg-quick@wgcf
sudo systemctl status xray
```

### 代理无法使用

```bash
# 检查端口监听
sudo ss -tlnp | grep -E '10808|10809'

# 测试 WireGuard 连接
curl --interface wgcf https://api.ipify.org

# 重启服务
sudo systemctl restart wg-quick@wgcf
sudo systemctl restart xray
```

### SSH 连接问题

如果遇到 SSH 断开，通过服务商控制台执行：

```bash
# 停止 WireGuard
sudo wg-quick down wgcf

# 检查配置
cat /etc/wireguard/wgcf.conf

# 确认配置中有 "Table = off"
```

## 📊 架构说明

```
┌─────────────────────────────────────────┐
│         服务器 (Your Server)             │
│                                         │
│  应用程序 / Docker 容器                  │
│           ↓                             │
│  Xray 代理 (10808/10809)                │
│           ↓                             │
│  WireGuard (wgcf)                       │
│           ↓                             │
└───────────┼─────────────────────────────┘
            ↓
    ☁️ Cloudflare WARP 网络
            ↓
        🌐 互联网
   (显示 Cloudflare IP)
```

## 🎓 工作原理

1. **WireGuard**：建立到 Cloudflare WARP 的加密隧道
2. **wgcf**：自动注册 WARP 账号并生成配置
3. **Xray**：提供本地 SOCKS5/HTTP 代理端口
4. **路由隔离**：使用独立路由表，不影响 SSH 连接

## 🙏 致谢

- [WireGuard](https://www.wireguard.com/) - 现代 VPN 协议
- [Cloudflare WARP](https://1.1.1.1/) - 免费 VPN 服务
- [wgcf](https://github.com/ViRb3/wgcf) - WARP 配置工具
- [Xray](https://github.com/XTLS/Xray-core) - 强大的代理工具

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## ⚠️ 免责声明

本项目仅供学习和研究使用，请遵守当地法律法规。使用本工具产生的任何后果由使用者自行承担。

## 📮 联系方式

- GitHub Issues: [提交问题](https://github.com/tszxy/cloudflare-warp-proxy/issues)
- 作者: [@tszxy](https://github.com/tszxy)

## 🌟 Star History

如果这个项目对您有帮助，请给个 Star ⭐️

---

**Made with ❤️ by Claude & Community**
