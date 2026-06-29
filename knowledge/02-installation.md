# LibreDesk 安装部署指南

> 原文: https://docs.libredesk.io/getting-started/installation
> 关键词: 安装, 部署, Docker, 二进制, 源码编译, Nginx, 环境变量

LibreDesk 是单一二进制应用，需要 PostgreSQL 和 Redis 才能运行。

## Docker 安装（推荐）

最新镜像: `libredesk/libredesk:latest` (DockerHub)

### Docker Compose 快速启动

```bash
# 下载编排文件和配置模板
curl -LO https://github.com/abhinavxd/libredesk/raw/main/docker-compose.yml
curl -LO https://github.com/abhinavxd/libredesk/raw/main/config.sample.toml

# 复制并编辑配置
cp config.sample.toml config.toml
# 编辑 config.toml 中的数据库凭据和偏好设置

# 启动服务
docker compose up -d

# 设置系统用户密码
docker exec -it libredesk_app ./libredesk --set-system-user-password
```

登录 `http://localhost:9000`，邮箱填 `System`，密码为刚设置的密码。

## 二进制安装

**前置条件**: PostgreSQL >= 13, Redis

1. 下载 [最新 Release](https://github.com/abhinavxd/libredesk/releases) 并解压

```bash
# 下载配置模板
curl -LO https://github.com/abhinavxd/libredesk/raw/main/config.sample.toml
cp config.sample.toml config.toml
# 编辑 config.toml

# 创建上传目录（默认 fs 上传方式需要）
mkdir uploads
chmod 755 uploads

# 安装数据库
./libredesk --install
# 安装时设置密码:
# LIBREDESK_SYSTEM_USER_PASSWORD=your_password ./libredesk --install

# 设置系统用户密码
./libredesk --set-system-user-password

# 启动
./libredesk
```

## 源码编译

**前置条件**: PostgreSQL >= 13, Redis, Go (最新版), Node.js >= 18, pnpm

```bash
git clone git@github.com:abhinavxd/libredesk.git
cd libredesk
make                          # 生成 libredesk 二进制
cp config.sample.toml config.toml
# 编辑 config.toml
mkdir uploads && chmod 755 uploads
./libredesk --install
./libredesk --set-system-user-password
./libredesk
```

## 环境变量配置

除了 `config.toml`，可完全通过环境变量配置：

- 所有环境变量使用 `LIBREDESK_` 前缀
- 嵌套键使用双下划线 `__` 分隔
- 仅使用环境变量时传 `--config=""`

| TOML 配置 | 环境变量 |
|-----------|---------|
| `upload.fs.upload_path = "uploads"` | `LIBREDESK_UPLOAD__FS__UPLOAD_PATH=uploads` |
| `db.host = "localhost"` | `LIBREDESK_DB__HOST=localhost` |

## Nginx 反向代理（推荐）

**关键**: 代理必须设置 `X-Client-IP` 为 `$remote_addr`，LibreDesk 用此 header 识别客户端用于限流和审计日志。

```nginx
server {
    listen 80;
    server_name your-domain.com;
    client_max_body_size 30M;

    location / {
        proxy_pass http://localhost:9000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Client-IP $remote_addr;
        # Cloudflare 时用: proxy_set_header X-Client-IP $http_cf_connecting_ip;
        proxy_cache_bypass $http_upgrade;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/libredesk /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```
