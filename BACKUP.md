# 备份和恢复指南

详细说明如何备份和恢复 Cloudflare WARP 代理配置。

## 📋 目录

- [快速备份](#快速备份)
- [备份内容](#备份内容)
- [下载备份](#下载备份)
- [恢复配置](#恢复配置)
- [服务器迁移](#服务器迁移)
- [安全建议](#安全建议)
- [故障排查](#故障排查)

## 🚀 快速备份

### 一键备份

```bash
# 下载备份脚本
wget https://raw.githubusercontent.com/tszxy/cloudflare-warp-proxy/main/backup.sh
chmod +x backup.sh

# 运行备份
sudo bash backup.sh
```

### 备份输出

脚本会创建：
- 备份目录：`/root/warp-backup-YYYYMMDD_HHMMSS/`
- 压缩包：`/root/warp-backup-YYYYMMDD_HHMMSS.tar.gz`

## 📦 备份内容

| 文件 | 路径 | 说明 |
|------|------|------|
| `wgcf.conf` | `/etc/wireguard/` | WireGuard 配置（包含私钥） |
| `wgcf-account.toml` | `/root/` | WARP 账号信息 |
| `config.json` | `/usr/local/etc/xray/` | Xray 代理配置 |
| `environment_proxy.txt` | - | 系统代理配置 |
| `http-proxy.conf` | `/etc/systemd/system/docker.service.d/` | Docker 代理配置 |
| `service_status.txt` | - | 服务状态信息 |
| `wireguard_status.txt` | - | WireGuard 连接状态 |
| `current_ip.txt` | - | 当前出口 IP |
| `restore.sh` | - | 一键恢复脚本 |
| `README.txt` | - | 备份说明 |

## 📥 下载备份

### 使用 SCP

```bash
# 下载到本地当前目录
scp root@your-server:/root/warp-backup-*.tar.gz ./

# 指定本地路径
scp root@your-server:/root/warp-backup-*.tar.gz ~/backups/
```

### 使用 SFTP

```bash
sftp root@your-server
get /root/warp-backup-*.tar.gz
exit
```

### 使用 rsync

```bash
rsync -avz root@your-server:/root/warp-backup-*.tar.gz ./
```

## 🔄 恢复配置

### 在同一服务器恢复

```bash
# 1. 解压备份
cd /root
tar -xzf warp-backup-20251226_123456.tar.gz

# 2. 进入备份目录
cd warp-backup-20251226_123456

# 3. 查看备份内容
cat README.txt

# 4. 运行恢复脚本
sudo bash restore.sh

# 5. 重启服务
sudo wg-quick down wgcf 2>/dev/null || true
sudo wg-quick up wgcf
sudo systemctl restart xray
sudo systemctl restart docker  # 如果修改了 Docker 配置
```

### 在新服务器恢复

```bash
# 1. 在新服务器上安装基础组件
bash <(wget -qO- https://raw.githubusercontent.com/tszxy/cloudflare-warp-proxy/main/install.sh)

# 2. 上传备份文件
scp warp-backup-*.tar.gz root@new-server:/root/

# 3. SSH 到新服务器
ssh root@new-server

# 4. 解压并恢复
cd /root
tar -xzf warp-backup-*.tar.gz
cd warp-backup-*
sudo bash restore.sh

# 5. 重启服务
sudo systemctl restart wg-quick@wgcf xray
```

### 手动恢复单个文件

```bash
# 只恢复 WireGuard 配置
sudo cp wgcf.conf /etc/wireguard/
sudo wg-quick down wgcf && sudo wg-quick up wgcf

# 只恢复 Xray 配置
sudo cp xray/config.json /usr/local/etc/xray/
sudo systemctl restart xray

# 只恢复 WARP 账号
sudo cp wgcf-account.toml /root/
```

## 🚚 服务器迁移

### 完整迁移步骤

**在旧服务器：**

```bash
# 1. 备份配置
sudo bash backup.sh

# 2. 下载备份
scp root@old-server:/root/warp-backup-*.tar.gz ./

# 3. 记录当前 IP（用于验证）
curl https://api.ipify.org
```

**在新服务器：**

```bash
# 1. 上传备份
scp warp-backup-*.tar.gz root@new-server:/root/

# 2. 安装基础环境
ssh root@new-server
bash <(wget -qO- https://raw.githubusercontent.com/tszxy/cloudflare-warp-proxy/main/install.sh)

# 3. 恢复配置（会覆盖新安装的配置）
cd /root
tar -xzf warp-backup-*.tar.gz
cd warp-backup-*
sudo bash restore.sh

# 4. 重启服务
sudo systemctl restart wg-quick@wgcf xray

# 5. 验证迁移
curl https://api.ipify.org  # 应该和旧服务器一样
curl --socks5 127.0.0.1:10808 https://api.ipify.org
```

## 🔐 安全建议

### ⚠️ 重要提醒

备份文件包含以下敏感信息：
- WireGuard 私钥
- WARP 账号凭证
- 代理配置

### 安全存储

**1. 加密备份文件**

```bash
# 使用 GPG 加密
gpg -c warp-backup-*.tar.gz
# 输入密码，生成 .tar.gz.gpg 文件

# 解密
gpg warp-backup-*.tar.gz.gpg
```

**2. 使用密码保护的压缩**

```bash
# 使用 7z 加密
7z a -p -mhe=on warp-backup-encrypted.7z warp-backup-*.tar.gz

# 解压
7z x warp-backup-encrypted.7z
```

**3. 安全存储位置**

- ✅ 本地加密硬盘
- ✅ 密码管理器（如 1Password、Bitwarden）
- ✅ 私有云存储（加密后上传）
- ❌ 公共云盘（未加密）
- ❌ Git 仓库

**4. 定期清理**

```bash
# 删除服务器上的备份（下载到本地后）
sudo rm -rf /root/warp-backup-*

# 只保留最新的 3 个备份
ls -t /root/warp-backup-*.tar.gz | tail -n +4 | xargs rm -f
```

## 🔄 定期自动备份

### 使用 Cron

```bash
# 编辑 cron 任务
sudo crontab -e

# 添加定时任务（每天凌晨 3 点）
0 3 * * * /root/backup.sh > /var/log/warp-backup.log 2>&1

# 每周日凌晨 2 点
0 2 * * 0 /root/backup.sh

# 每月 1 号
0 2 1 * * /root/backup.sh
```

### 自动清理旧备份

```bash
# 保留最近 7 天的备份
0 4 * * * find /root/warp-backup-* -mtime +7 -delete
```

## 🛠️ 故障排查

### 备份失败

**问题：权限不足**
```bash
sudo bash backup.sh  # 确保使用 sudo
```

**问题：磁盘空间不足**
```bash
df -h  # 检查磁盘空间
du -sh /root/warp-backup-*  # 查看备份大小
```

### 恢复失败

**问题：服务未安装**
```bash
# 先安装基础环境
bash install.sh
# 然后再恢复
```

**问题：配置冲突**
```bash
# 停止现有服务
sudo wg-quick down wgcf
sudo systemctl stop xray

# 清理旧配置
sudo rm /etc/wireguard/wgcf.conf
sudo rm /usr/local/etc/xray/config.json

# 重新恢复
sudo bash restore.sh
```

**问题：服务无法启动**
```bash
# 查看详细错误
sudo journalctl -u wg-quick@wgcf -n 50
sudo journalctl -u xray -n 50

# 验证配置文件
sudo wg-quick up wgcf  # 查看错误信息
xray -test -c /usr/local/etc/xray/config.json
```

### 验证恢复

```bash
# 检查文件是否存在
ls -la /etc/wireguard/wgcf.conf
ls -la /usr/local/etc/xray/config.json
ls -la /root/wgcf-account.toml

# 检查服务状态
sudo systemctl status wg-quick@wgcf
sudo systemctl status xray

# 测试连接
curl --interface wgcf https://api.ipify.org
curl --socks5 127.0.0.1:10808 https://api.ipify.org
```

## 📝 快速参考

### 常用命令

```bash
# 备份
sudo bash backup.sh

# 查看备份列表
ls -lht /root/warp-backup-*

# 解压备份
tar -xzf warp-backup-*.tar.gz

# 恢复
cd warp-backup-* && sudo bash restore.sh

# 下载备份
scp root@server:/root/warp-backup-*.tar.gz ./

# 上传备份
scp warp-backup-*.tar.gz root@server:/root/

# 删除旧备份
rm /root/warp-backup-older.tar.gz
```

## 🔗 相关链接

- [安装指南](README.md#快速开始)
- [使用说明](README.md#使用方法)
- [故障排查](README.md#故障排查)
- [GitHub Issues](https://github.com/tszxy/cloudflare-warp-proxy/issues)

---

如有问题，请提交 [Issue](https://github.com/tszxy/cloudflare-warp-proxy/issues)
