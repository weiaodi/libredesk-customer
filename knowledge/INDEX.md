# LibreDesk 知识库

> 文档来源: https://docs.libredesk.io
> 构建时间: 2026-06-28
> OpenAPI 规范: https://docs.libredesk.io/api-reference/openapi.json

本知识库将 LibreDesk 官方文档结构化整理，方便 AI 和开发者快速查阅。内容以中文为主，保留英文专有名词和代码片段。

## 目录结构

```
knowledge/
├── INDEX.md                          # 本文件 - 总索引
├── 01-introduction.md                 # 项目介绍与功能特性
├── 02-installation.md                 # 安装部署指南（Docker/二进制/源码/Nginx）
├── 03-developer-setup.md              # 开发环境搭建
├── 04-upgrade.md                      # 升级指南
├── 05-configuration/
│   ├── connecting-inboxes.md          # 收件箱连接（Google/Microsoft/IMAP）
│   ├── livechat.md                    # 实时聊天 Widget 配置与 JS API
│   ├── sso.md                         # SSO 单点登录（Keycloak 等）
│   ├── webhooks.md                    # Webhook 事件通知
│   ├── email-templates.md             # 邮件模板与 Go template 变量
│   └── context-links.md               # 上下文链接与加密 Token
├── 06-roles-permissions.md            # 角色与权限体系（完整权限列表）
├── 07-api-reference/
│   ├── introduction.md                # API 认证（Basic/Token Auth）
│   ├── widget-api.md                  # Widget API 与 WebSocket 协议
│   └── endpoints-summary.md           # 50+ API 端点分类汇总
└── 08-hosting/
    └── railway.md                     # Railway 一键部署
```

## 按主题索引

### 快速入门
- 项目介绍 → [01-introduction.md](01-introduction.md)
- 安装部署 → [02-installation.md](02-installation.md)
- 开发环境 → [03-developer-setup.md](03-developer-setup.md)
- 升级 → [04-upgrade.md](04-upgrade.md)

### 配置
- 收件箱（邮箱连接）→ [05-configuration/connecting-inboxes.md](05-configuration/connecting-inboxes.md)
- 实时聊天 Widget → [05-configuration/livechat.md](05-configuration/livechat.md)
- SSO 单点登录 → [05-configuration/sso.md](05-configuration/sso.md)
- Webhook → [05-configuration/webhooks.md](05-configuration/webhooks.md)
- 邮件模板 → [05-configuration/email-templates.md](05-configuration/email-templates.md)
- 上下文链接 → [05-configuration/context-links.md](05-configuration/context-links.md)

### 权限与 API
- 角色权限 → [06-roles-permissions.md](06-roles-permissions.md)
- API 认证 → [07-api-reference/introduction.md](07-api-reference/introduction.md)
- Widget API → [07-api-reference/widget-api.md](07-api-reference/widget-api.md)
- 端点汇总 → [07-api-reference/endpoints-summary.md](07-api-reference/endpoints-summary.md)

### 部署
- Railway → [08-hosting/railway.md](08-hosting/railway.md)

## 关键词速查

| 关键词 | 文档 |
|--------|------|
| Docker, 安装, Nginx | 02-installation.md |
| 开发, make, run-backend, run-frontend | 03-developer-setup.md |
| Gmail, Outlook, IMAP, SMTP, OAuth | 05-configuration/connecting-inboxes.md |
| Widget, 聊天, JWT, JavaScript API | 05-configuration/livechat.md |
| SSO, Keycloak, OpenID Connect | 05-configuration/sso.md |
| Webhook, 事件, 通知 | 05-configuration/webhooks.md |
| 邮件模板, Go template | 05-configuration/email-templates.md |
| Context Links, CRM, 加密 Token | 05-configuration/context-links.md |
| 权限, 角色, RBAC, Admin, Agent | 06-roles-permissions.md |
| API, 认证, API Key | 07-api-reference/introduction.md |
| WebSocket, Widget 协议 | 07-api-reference/widget-api.md |
| 端点, Conversations, Agents, Teams | 07-api-reference/endpoints-summary.md |
| Railway, 云部署 | 08-hosting/railway.md |
