# 新系统快速恢复指南

本指南适用于重装系统或迁移到新服务器后，需要恢复之前配置的场景。

## 📋 前提条件

✅ 确保您有之前的备份文件：`warp-backup-*.tar.gz`

如果没有备份，请参考 [全新安装指南](README.md#快速开始)

## 🚀 快速恢复（5 分钟）

### 步骤 1：上传备份文件

```bash
# 从本地上传备份到服务器
scp warp-backup-*.tar.gz root@your-server-ip:/root/
```

### 步骤 2：登录服务器

```bash
ssh root@your-server-ip
```

### 步骤 3：一键恢复

```bash
# 下载并运行恢复脚本
wget https://raw.githubusercontent.com/tszxy/cloudflare-warp-proxy/main/quick-restore.sh
chmod +x quick-restore.sh
sudo bash quick-restore.sh
```

恢复脚本会自动：
1. ✅ 安装所有必需组件
2. ✅ 解压备份文件
3. ✅ 恢复所有配置
4. ✅ 重启服务
5. ✅ 验证连接

**等待 2-5 分钟，完成！**

---

## 📖 手动恢复步骤

如果您想手动控制每一步：

### 1️⃣ 安装基础环境

```bash
# 下载安装脚本
wget https://raw.githubusercontent.com/tszxy/cloudflare-warp-proxy/main/install.sh
chmod +x install.sh

# 运行安装（约 2-3 分钟）
sudo bash install.sh
```

### 2️⃣ 解压备份

```bash
cd /root
tar -xzf warp-backup-*.tar.gz
cd warp-backup-*/
```

### 3️⃣ 运行恢复

```bash
# 执行恢复脚本
sudo bash restore.sh
```

### 4️⃣ 重启服务

```bash
# 重启 WireGuard
sudo wg-quick down wgcf 2>/dev/null || true
sudo wg-quick up wgcf

# 重启 Xray
sudo systemctl restart xray

# 重启 Docker（如果需要）
sudo systemctl restart docker
```

### 5️⃣ 验证恢复

```bash
# 测试 WireGuard
curl --interface wgcf https://api.ipify.org
# 应该显示 Cloudflare IP（如 104.28.195.185）

# 测试 Xray 代理
curl --socks5 127.0.0.1:10808 https://api.ipify.org
# 应该显示 Cloudflare IP

# 测试 Google 访问
curl -I https://www.google.com
# 应该返回 HTTP/2 200

# 测试 Gemini 访问  
curl -I https://gemini.google.com
# 应该返回 HTTP/2 200
```

---

## 🎯 验证检查清单

恢复完成后，确认以下项目：

- [ ] WireGuard 服务正在运行
  ```bash
  sudo systemctl status wg-quick@wgcf
  ```

- [ ] Xray 服务正在运行
  ```bash
  sudo systemctl status xray
  ```

- [ ] WireGuard 显示 Cloudflare IP
  ```bash
  curl --interface wgcf https://api.ipify.org
  ```

- [ ] Xray 代理工作正常
  ```bash
  curl --socks5 127.0.0.1:10808 https://api.ipify.org
  ```

- [ ] 系统代理已配置
  ```bash
  grep PROXY /etc/environment
  ```

- [ ] Google/Gemini 访问正常
  ```bash
  curl -I https://www.google.com
  curl -I https://gemini.google.com
  ```

- [ ] 服务开机自启动
  ```bash
  sudo systemctl is-enabled wg-quick@wgcf
  sudo systemctl is-enabled xray
  ```

---

## 🔧 故障排查

### 问题 1：服务启动失败

```bash
# 查看 WireGuard 日志
sudo journalctl -u wg-quick@wgcf -n 50

# 查看 Xray 日志
sudo journalctl -u xray -n 50

# 重新安装
sudo bash install.sh
```

### 问题 2：IP 地址不正确

```bash
# 检查 WireGuard 连接
sudo wg show

# 重启 WireGuard
sudo wg-quick down wgcf
sudo wg-quick up wgcf

# 测试连接
curl --interface wgcf https://api.ipify.org
```

### 问题 3：代理端口无响应

```bash
# 检查端口监听
sudo ss -tlnp | grep -E '10808|10809'

# 重启 Xray
sudo systemctl restart xray

# 检查 Xray 状态
sudo systemctl status xray
```

### 问题 4：Docker 容器不走代理

```bash
# 检查 Docker 代理配置
sudo systemctl show --property=Environment docker | grep PROXY

# 重新配置
sudo systemctl daemon-reload
sudo systemctl restart docker

# 测试
docker run --rm alpine/curl https://api.ipify.org
```

---

## 💡 服务器迁移场景

### 从旧服务器迁移到新服务器

**在旧服务器：**
```bash
# 1. 创建备份
sudo bash backup.sh

# 2. 下载备份到本地
scp root@old-server:/root/warp-backup-*.tar.gz ./
```

**在新服务器：**
```bash
# 1. 上传备份
scp warp-backup-*.tar.gz root@new-server:/root/

# 2. SSH 登录新服务器
ssh root@new-server

# 3. 运行快速恢复
wget https://raw.githubusercontent.com/tszxy/cloudflare-warp-proxy/main/quick-restore.sh
chmod +x quick-restore.sh
sudo bash quick-restore.sh
```

**验证迁移：**
```bash
# 新旧服务器的出口 IP 应该一致
curl https://api.ipify.org
```

---

## 📚 相关文档

- [完整安装指南](README.md)
- [备份详细说明](BACKUP.md)
- [中文文档](README_CN.md)
- [故障排查](README.md#故障排查)

---

## ❓ 常见问题

**Q: 恢复需要多长时间？**
A: 使用快速恢复脚本约 2-5 分钟，手动恢复约 5-10 分钟。

**Q: 恢复后 IP 会变吗？**
A: 不会，恢复使用您备份的 WARP 账号，IP 保持不变。

**Q: 可以恢复到不同的服务器吗？**
A: 可以，配置完全可移植。

**Q: 没有备份怎么办？**
A: 只能重新安装，会注册新的 WARP 账号，IP 会不同。

**Q: 备份文件安全吗？**
A: 备份包含私钥，请妥善保管，建议加密存储。

---

## 🆘 需要帮助？

- [提交 Issue](https://github.com/tszxy/cloudflare-warp-proxy/issues)
- [查看文档](README.md)
- [备份指南](BACKUP.md)

---

**快速链接：**
- [一键安装](README.md#快速开始)
- [备份配置](BACKUP.md)
- [故障排查](README.md#故障排查)
