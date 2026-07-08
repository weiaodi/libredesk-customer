# libredesk 部署脚本详解

## 目录

- [整体流程概览](#整体流程概览)
- [deploy.sh 脚本逐行解析](#deploysh-脚本逐行解析)
- [docker-compose.yml 详解](#docker-composeyml-详解)
- [config.toml 配置详解](#configtoml-配置详解)
- [部署后操作说明](#部署后操作说明)
- [常见问题](#常见问题)

---

## 整体流程概览

整个部署由三个文件协同工作：

```
deploy.sh           ← 一键执行脚本，负责创建目录、写配置、启动服务
  ├── 生成 docker-compose.yml   ← 告诉 Docker 启动哪些容器、如何配置
  └── 生成 config.toml          ← libredesk 应用的详细配置参数
```

运行 `bash deploy.sh` 后，服务器上会启动三个 Docker 容器：

```
┌─────────────────────────────────────────────┐
│              Docker 网络: libredesk          │
│                                             │
│  ┌──────────────┐    ┌──────────────────┐   │
│  │  libredesk   │───▶│   PostgreSQL 17  │   │
│  │  app:9000    │    │   db:5432        │   │
│  │              │───▶│                  │   │
│  │              │    └──────────────────┘   │
│  │              │    ┌──────────────────┐   │
│  │              │───▶│   Redis 7        │   │
│  │              │    │   redis:6379     │   │
│  └──────────────┘    └──────────────────┘   │
│         │                                   │
└─────────┼───────────────────────────────────┘
          │ 对外暴露
          ▼
   http://47.85.194.46:9000
```

---

## deploy.sh 脚本逐行解析

### 头部声明

```bash
#!/bin/bash
```
告诉系统这个文件用 `bash` 解释器来执行，而不是 Python 或其他语言。

```bash
set -e
```
**非常重要**：表示"遇到任何错误立即停止执行"。
- 没有这行：某步失败了脚本还会继续跑，可能导致服务启动不完整
- 有这行：出错就停，方便快速发现问题

---

### 第一步：创建目录

```bash
DEPLOY_DIR="/opt/libredesk"
mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"
```

| 内容 | 说明 |
|------|------|
| `DEPLOY_DIR="/opt/libredesk"` | 定义一个变量，存放部署路径，方便后面复用 |
| `mkdir -p` | 创建目录，`-p` 表示"如果目录已存在就不报错，同时自动创建中间层目录" |
| `cd "$DEPLOY_DIR"` | 切换到部署目录，后续文件都会创建在这里 |

> `/opt` 是 Linux 约定俗成存放第三方应用的地方

---

### 第二步：写入 docker-compose.yml

```bash
cat > docker-compose.yml <<'COMPOSE_EOF'
...内容...
COMPOSE_EOF
```

这是一种叫 **Here Document（heredoc）** 的写法：
- `cat >` 表示把内容写入文件（会覆盖原文件）
- `<<'COMPOSE_EOF'` 表示"从这里开始，直到遇到 `COMPOSE_EOF` 结束"
- 单引号 `'COMPOSE_EOF'` 表示内容里的 `$` 变量不会被展开，原样写入文件

---

### 第三步：写入 config.toml

```bash
cat > config.toml <<'CONFIG_EOF'
...内容...
CONFIG_EOF
```

同上，把应用配置文件写入当前目录，方式完全一样。

---

### 第四步：创建 uploads 目录

```bash
mkdir -p uploads
```

libredesk 上传的图片、附件都会存放在这里。在 `docker-compose.yml` 里有一行：

```yaml
volumes:
  - ./uploads:/libredesk/uploads:rw
```

意思是把服务器上的 `./uploads` 目录挂载到容器内的 `/libredesk/uploads`，`:rw` 表示可读写。
**好处**：容器删了重建，上传的文件不会丢失，因为文件存在服务器上而不是容器里。

---

### 第五步：检测 docker compose 版本并启动

```bash
if docker compose version &>/dev/null; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi
```

Docker 有两个版本的 compose 命令：
- 新版（v2）：`docker compose`（空格，内置在 docker 里）
- 旧版（v1）：`docker-compose`（连字符，需要单独安装）

这段代码检测服务器装的是哪个版本，自动选择正确的命令。

```bash
$COMPOSE_CMD pull
```
从 Docker Hub 拉取最新镜像（libredesk、postgres、redis）。

```bash
$COMPOSE_CMD up -d
```
启动所有服务，`-d` 表示后台运行（daemon），不占用终端。

---

## docker-compose.yml 详解

### app 服务（libredesk 主应用）

```yaml
app:
  image: libredesk/libredesk:latest
```
使用 Docker Hub 上官方发布的最新版镜像，不需要本地编译。

```yaml
  container_name: libredesk_app
```
固定容器名字为 `libredesk_app`，方便后续用 `docker exec -it libredesk_app ...` 操作。

```yaml
  restart: unless-stopped
```
容器崩溃或服务器重启后**自动重启**，除非你手动 `docker stop` 它。

```yaml
  ports:
    - "9000:9000"
```
格式是 `宿主机端口:容器内端口`，把容器内的 9000 端口映射到服务器的 9000 端口，外网才能访问。

```yaml
  environment:
    LIBREDESK_SYSTEM_USER_PASSWORD: ${LIBREDESK_SYSTEM_USER_PASSWORD:-}
```
从系统环境变量读取管理员初始密码，`:-` 表示"如果没设置就用空字符串"。
可以在启动时这样设置：`LIBREDESK_SYSTEM_USER_PASSWORD=mypassword docker compose up -d`

```yaml
  depends_on:
    - db
    - redis
```
告诉 Docker：先启动 `db` 和 `redis`，再启动 `app`。保证数据库和缓存已经在运行了。

```yaml
  volumes:
    - ./uploads:/libredesk/uploads:rw
    - ./config.toml:/libredesk/config.toml
```
两个挂载：
1. 上传文件目录：服务器本地目录 ↔ 容器内目录（持久化存储）
2. 配置文件：把我们写好的 `config.toml` 注入到容器内

```yaml
  command: [sh, -c, "
    ./libredesk --install --idempotent-install --yes --config /libredesk/config.toml
    && ./libredesk --upgrade --yes --config /libredesk/config.toml
    && ./libredesk --config /libredesk/config.toml
  "]
```

三条命令用 `&&` 串联，顺序执行：

| 顺序 | 命令 | 作用 |
|------|------|------|
| 1 | `--install --idempotent-install` | 初始化数据库表结构（已初始化则跳过，不报错） |
| 2 | `--upgrade` | 执行数据库版本迁移（升级应用时自动更新表结构） |
| 3 | 不带参数直接运行 | 启动 Web 服务，开始监听 9000 端口 |

`&&` 的含义：只有前一条命令**成功**，才执行下一条。任何一步失败，容器停止并报错。

---

### db 服务（PostgreSQL 数据库）

```yaml
db:
  image: postgres:17-alpine
```
使用 PostgreSQL 17 的 Alpine 版本（体积小，约 80MB）。

```yaml
  ports:
    - "127.0.0.1:5432:5432"
```
绑定到 `127.0.0.1`（本机回环地址），意味着**只有服务器本机能访问**，外网无法直连数据库，更安全。

```yaml
  environment:
    POSTGRES_USER: ${POSTGRES_USER:-libredesk}
    POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-libredesk}
    POSTGRES_DB: ${POSTGRES_DB:-libredesk}
```
`:-libredesk` 表示"如果没有设置环境变量，默认值就是 libredesk"。

```yaml
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U libredesk -d libredesk"]
    interval: 10s
    timeout: 5s
    retries: 6
```
健康检查：每 10 秒检测一次数据库是否就绪，最多重试 6 次。`app` 服务会等数据库健康后再启动。

```yaml
  volumes:
    - postgres-data:/var/lib/postgresql/data
```
数据库文件存储在 Docker 命名卷 `postgres-data` 里，容器删了重建数据不丢失。

---

### redis 服务（缓存）

```yaml
redis:
  image: redis:7-alpine
  ports:
    - "127.0.0.1:6379:6379"
```
同样绑定本机，外网无法访问。Redis 用于：
- 会话缓存（用户登录状态）
- 消息队列（处理发送消息、通知等异步任务）
- 实时数据缓存

---

### 网络与卷

```yaml
networks:
  libredesk:
```
创建一个独立的 Docker 内部网络，三个容器都在这个网络里，可以通过服务名互相访问（如 `db`、`redis`），和其他容器隔离。

```yaml
volumes:
  postgres-data:
  redis-data:
```
声明两个命名卷，由 Docker 统一管理数据持久化。

---

## config.toml 配置详解

### [app] 应用基础配置

```toml
log_level = "info"
```
日志级别，`info` 记录关键信息，`debug` 记录详细调试信息（生产环境用 `info` 避免日志过多）。

```toml
env = "prod"
```
运行环境，`prod` 表示生产模式（关闭调试输出，性能更好）。

```toml
encryption_key = "c63e0f8776d80524c150bc1b1ebc1f1e"
```
32 位加密密钥，用于加密存储敏感数据（如邮件密码、API 密钥等）。
**重要：部署后不要修改这个值，否则已加密的数据将无法解密！**

---

### [app.server] HTTP 服务配置

```toml
address = "0.0.0.0:9000"
```
监听所有网卡的 9000 端口，`0.0.0.0` 表示接受任何 IP 来的请求。

```toml
disable_secure_cookies = true
```
禁用安全 Cookie（因为没有 HTTPS）。
- 有 HTTPS：改为 `false`，Cookie 只通过加密连接传输，更安全
- 没有 HTTPS：必须设为 `true`，否则登录 Cookie 无法正常工作

---

### [db] 数据库配置

```toml
host = "db"
```
连接 Docker 网络里名为 `db` 的服务（即 PostgreSQL 容器），不是 `localhost`。

---

### [redis] 缓存配置

```toml
address = "redis:6379"
```
连接 Docker 网络里名为 `redis` 的服务，格式是 `服务名:端口`。

---

### [message] 消息队列配置

```toml
outgoing_queue_workers = 10   # 处理发出消息的工作线程数
incoming_queue_workers = 10   # 处理接收消息的工作线程数
message_outgoing_scan_interval = "50ms"  # 每 50 毫秒扫描一次待发消息
```

---

## 部署后操作说明

### 设置管理员密码

```bash
sudo docker exec -it libredesk_app ./libredesk --set-system-user-password
```

- `docker exec` 在运行中的容器里执行命令
- `-it` 交互式终端（可以输入密码）
- `libredesk_app` 容器名
- 命令执行后按提示输入密码（输入时不显示字符，正常现象）

### 常用运维命令

```bash
# 查看所有容器状态
sudo docker compose ps

# 实时查看应用日志
sudo docker compose logs -f app

# 重启应用
sudo docker compose restart app

# 停止所有服务
sudo docker compose down

# 更新到最新版本
sudo docker compose pull && sudo docker compose up -d
```

---

## 常见问题

### Q: 容器启动后访问不了？
1. 检查安全组是否开放了 9000 端口
2. 查看日志：`sudo docker compose logs app`
3. 确认容器在运行：`sudo docker compose ps`

### Q: 数据库连接失败？
通常是 `db` 容器还没完全启动，`app` 就去连了。等 30 秒后再检查：
```bash
sudo docker compose logs db   # 查看数据库日志
```

### Q: 忘记管理员密码怎么办？
```bash
sudo docker exec -it libredesk_app ./libredesk --set-system-user-password
```
重新运行设置密码命令即可。

### Q: 如何备份数据？
```bash
# 备份数据库
sudo docker exec libredesk_db pg_dump -U libredesk libredesk > backup_$(date +%Y%m%d).sql

# 备份上传文件
tar -czf uploads_backup_$(date +%Y%m%d).tar.gz /opt/libredesk/uploads
```
