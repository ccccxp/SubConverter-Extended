# 🚀 一键部署指南

本指南帮助你在 Linux 服务器上快速部署 SubConverter-Extended。

## 支持的系统

- ✅ Ubuntu 20.04 / 22.04 / 24.04 / 25.04
- ✅ Debian 11 / 12
- ✅ CentOS 7 / 8 / Stream
- ✅ Rocky Linux / AlmaLinux

## 一键安装

SSH 登录你的服务器，执行以下命令：

```bash
curl -fsSL https://raw.githubusercontent.com/ccccxp/SubConverter-Extended/master/scripts/install.sh | sudo bash
```

或者使用 wget：

```bash
wget -qO- https://raw.githubusercontent.com/ccccxp/SubConverter-Extended/master/scripts/install.sh | sudo bash
```

安装脚本会自动完成以下操作：
1. ✅ 检测系统类型
2. ✅ 安装 Docker 和 Docker Compose
3. ✅ 下载配置文件
4. ✅ 自动检测公网 IP 并配置
5. ✅ 启动服务
6. ✅ 配置防火墙
7. ✅ 创建管理命令

## 管理命令

安装完成后，可以使用 `subconverter` 命令管理服务：

```bash
subconverter start      # 启动服务
subconverter stop       # 停止服务
subconverter restart    # 重启服务
subconverter status     # 查看状态
subconverter logs       # 查看日志
subconverter update     # 更新到最新版本
subconverter config     # 查看配置信息
subconverter uninstall  # 卸载服务
```

## 验证安装

```bash
# 检查服务状态
subconverter status

# 测试 API
curl http://localhost:25500/version

# 或使用公网 IP
curl http://<你的服务器IP>:25500/version
```

## 使用方法

### 方法一：配合前端网页使用

1. 打开任意 Subconverter 前端（如 [ACL4SSR](https://acl4ssr-sub.github.io/)）
2. 在"后端地址"中选择"自定义"
3. 填入：`http://<你的服务器IP>:25500/sub?`
4. 输入订阅链接，生成配置

### 方法二：直接调用 API

```
http://<你的服务器IP>:25500/sub?target=clash&url=<订阅链接>
```

### 方法三：配合 OpenClash 使用

1. 打开 OpenClash 设置
2. 启用"自定义转换后端"
3. 填入：`http://<你的服务器IP>:25500/sub?`

## 配置文件

配置文件位置：`/opt/SubConverter-Extended/base/pref.toml`

修改配置后需要重启服务：
```bash
subconverter restart
```

## 更新服务

```bash
subconverter update
```

或者运行更新脚本：
```bash
curl -fsSL https://raw.githubusercontent.com/ccccxp/SubConverter-Extended/master/scripts/update.sh | sudo bash
```

## 卸载服务

```bash
subconverter uninstall
```

或者运行卸载脚本：
```bash
curl -fsSL https://raw.githubusercontent.com/ccccxp/SubConverter-Extended/master/scripts/uninstall.sh | sudo bash
```

## 常见问题

### 无法访问服务

1. 检查防火墙是否开放 25500 端口：
   ```bash
   # Ubuntu/Debian
   sudo ufw allow 25500/tcp
   
   # CentOS/RHEL
   sudo firewall-cmd --permanent --add-port=25500/tcp
   sudo firewall-cmd --reload
   ```

2. 检查云服务器安全组是否开放 25500 端口

### 查看日志排错

```bash
subconverter logs
```

### 修改端口

编辑 `/opt/SubConverter-Extended/docker-compose.yml`，修改端口映射后重启：
```bash
subconverter restart
```

## 文件结构

```
/opt/SubConverter-Extended/
├── docker-compose.yml      # Docker Compose 配置
└── base/
    └── pref.toml           # 服务配置文件
```
