# Railway 部署

> 原文: https://docs.libredesk.io/hosting-providers/railway
> 关键词: Railway, 部署, 云托管, 托管 PostgreSQL, 托管 Redis

一键在 Railway 上部署 LibreDesk，使用 Railway 托管的 PostgreSQL 和 Redis。

## 部署步骤

1. 访问 LibreDesk 的 Railway 模板页面
2. 点击 **Deploy** 按钮
3. Railway 自动创建 PostgreSQL 和 Redis 服务
4. 配置环境变量（加密密钥等）
5. 等待部署完成后访问应用 URL

## 配置要点

- 在 Railway 环境变量中设置 `LIBREDESK_` 前缀的配置项
- `encryption_key` 必须设置为 32 字符随机字符串
- PostgreSQL 和 Redis 连接信息由 Railway 自动注入
