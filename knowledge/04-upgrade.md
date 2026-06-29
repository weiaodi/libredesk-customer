# LibreDesk 升级指南

> 原文: https://docs.libredesk.io/getting-started/upgrade
> 关键词: 升级, 备份, pg_dump, Docker, 迁移

**升级前务必备份 PostgreSQL 数据库！**

```bash
pg_dump -h localhost -U libredesk libredesk > libredesk_backup.sql
```

此命令对 Docker 和非 Docker 方式都适用（Docker 暴露 Postgres 在 `localhost:5432`）。

## 二进制升级

1. 停止正在运行的 libredesk 进程
2. 下载 [最新 Release](https://github.com/abhinavxd/libredesk/releases) 并覆盖旧版本

```bash
./libredesk --upgrade   # 升级是幂等的，多次执行无副作用
./libredesk             # 启动
```

## Docker 升级

```bash
docker compose down app
docker compose pull
docker compose up app -d
```
