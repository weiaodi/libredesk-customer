#!/bin/bash
# ===========================================================
# libredesk 一键部署脚本
# 服务器上执行：bash deploy.sh
# 公网 IP: 47.85.194.46
# ===========================================================
set -e

DEPLOY_DIR="/opt/libredesk"
SERVER_IP="47.85.194.46"

echo "=== [1/6] 创建部署目录 ==="
mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"

echo "=== [2/6] 写入 docker-compose.yml ==="
cat > docker-compose.yml <<'COMPOSE_EOF'
services:
  app:
    image: libredesk/libredesk:latest
    container_name: libredesk_app
    restart: unless-stopped
    ports:
      - "9000:9000"
    environment:
      LIBREDESK_SYSTEM_USER_PASSWORD: ${LIBREDESK_SYSTEM_USER_PASSWORD:-}
    networks:
      - libredesk
    depends_on:
      - db
      - redis
    volumes:
      - ./uploads:/libredesk/uploads:rw
      - ./config.toml:/libredesk/config.toml
    command: [sh, -c, "./libredesk --install --idempotent-install --yes --config /libredesk/config.toml && ./libredesk --upgrade --yes --config /libredesk/config.toml && ./libredesk --config /libredesk/config.toml"]

  db:
    image: postgres:17-alpine
    container_name: libredesk_db
    restart: unless-stopped
    networks:
      - libredesk
    ports:
      - "127.0.0.1:5432:5432"
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-libredesk}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-libredesk}
      POSTGRES_DB: ${POSTGRES_DB:-libredesk}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-libredesk} -d ${POSTGRES_DB:-libredesk}"]
      interval: 10s
      timeout: 5s
      retries: 6
    volumes:
      - postgres-data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    container_name: libredesk_redis
    restart: unless-stopped
    ports:
      - "127.0.0.1:6379:6379"
    networks:
      - libredesk
    volumes:
      - redis-data:/data

networks:
  libredesk:

volumes:
  postgres-data:
  redis-data:
COMPOSE_EOF

echo "=== [3/6] 写入 config.toml ==="
cat > config.toml <<'CONFIG_EOF'
[app]
log_level = "info"
env = "prod"
check_updates = false
encryption_key = "c63e0f8776d80524c150bc1b1ebc1f1e"

[app.server]
address = "0.0.0.0:9000"
socket = ""
disable_secure_cookies = true
session_lifetime = "9h"
read_timeout = "5s"
write_timeout = "5s"
max_body_size = 104857600
read_buffer_size = 65536
keepalive_timeout = "10s"

[upload]
provider = "fs"

[upload.fs]
upload_path = 'uploads'
expiry = "1h"

[upload.s3]
url = ""
access_key = ""
secret_key = ""
region = "ap-south-1"
bucket = "bucket-name"
bucket_path = ""
expiry = "30m"

[db]
host = "db"
port = 5432
user = "libredesk"
password = "libredesk"
database = "libredesk"
ssl_mode = "disable"
max_open = 30
max_idle = 30
max_lifetime = "300s"

[redis]
address = "redis:6379"
user = ""
password = ""
db = 0

[message]
outgoing_queue_workers = 10
incoming_queue_workers = 10
message_outgoing_scan_interval = "50ms"
incoming_queue_size = 5000
outgoing_queue_size = 5000

[notification]
concurrency = 2
queue_size = 2000

[automation]
worker_count = 10

[autoassigner]
autoassign_interval = "5m"

[webhook]
workers = 5
queue_size = 10000
timeout = "15s"
allowed_hosts = []

[conversation]
unsnooze_interval = "5m"
draft_retention_duration = "360h"
continuity_scan_interval = "5m"

[sla]
evaluation_interval = "5m"
CONFIG_EOF

echo "=== [4/6] 创建 uploads 目录 ==="
mkdir -p uploads

echo "=== [5/6] 拉取镜像并启动服务 ==="
if docker compose version &>/dev/null; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

echo "使用命令: $COMPOSE_CMD"
$COMPOSE_CMD pull
$COMPOSE_CMD up -d

echo "=== [6/6] 部署完成 ==="
echo ""
echo "=============================================="
echo " 服务已启动！"
echo ""
echo " 查看日志:"
echo "   cd $DEPLOY_DIR && $COMPOSE_CMD logs -f app"
echo ""
echo " 设置管理员密码（等约30秒服务就绪后执行）:"
echo "   docker exec -it libredesk_app ./libredesk --set-system-user-password"
echo ""
echo " 访问地址: http://$SERVER_IP:9000"
echo " 登录用户名: System"
echo "=============================================="
