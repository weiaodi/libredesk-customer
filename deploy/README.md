# libredesk 部署说明

## 服务器信息
- 公网 IP: `47.85.194.46`
- 私网 IP: `172.18.37.55`
- 部署目录: `/opt/libredesk`

## 快速部署

### 方法一：上传脚本执行
```bash
# 本地上传脚本到服务器
scp deploy/deploy.sh admin@47.85.194.46:/tmp/

# 登录服务器后执行
bash /tmp/deploy.sh
```

### 方法二：登录服务器后直接复制脚本内容执行

## 部署完成后

### 设置管理员密码
```bash
sudo docker exec -it libredesk_app ./libredesk --set-system-user-password
```

### 访问系统
- 地址：http://47.85.194.46:9000
- 用户名：`System`
- 密码：上一步设置的密码

## 常用运维命令

```bash
cd /opt/libredesk

# 查看运行状态
sudo docker compose ps

# 查看应用日志
sudo docker compose logs -f app

# 重启服务
sudo docker compose restart

# 停止服务
sudo docker compose down

# 更新到最新版本
sudo docker compose pull && sudo docker compose up -d
```

## 阿里云安全组

已开放端口：
- 22 (SSH)
- 80 (HTTP)
- 443 (HTTPS)
- 9000 (libredesk)

## 配置文件

| 文件 | 说明 |
|------|------|
| `deploy/deploy.sh` | 一键部署脚本 |
| `config.toml` | 应用配置文件（已生成） |
| `docker-compose.yml` | Docker 编排文件 |
