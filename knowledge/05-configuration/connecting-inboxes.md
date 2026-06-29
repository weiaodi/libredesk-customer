# 连接收件箱

> 原文: https://docs.libredesk.io/configuration/connecting-inboxes
> 关键词: 收件箱, 邮箱, Google, Gmail, Microsoft, Outlook, IMAP, SMTP, OAuth

LibreDesk 支持三种方式连接邮箱收件箱：Google OAuth、Microsoft OAuth、手动 IMAP/SMTP 配置。

## Google 设置

### OAuth 方式

**前置条件**：Google Cloud Console 项目 + OAuth 2.0 凭据

**所需 OAuth Scopes**：

| Scope | 用途 |
|-------|------|
| `https://mail.google.com/` | 完整 Gmail 读写权限 |
| `https://www.googleapis.com/auth/userinfo.email` | 访问用户邮箱地址 |

**配置步骤**：
1. 在 LibreDesk: Admin > Inboxes > New inbox > Google，复制 Callback URL
2. 在 Google Cloud Console: 创建项目 > 启用 Gmail API > 配置 OAuth consent screen > 创建 OAuth client ID (Web application) > 添加 Callback URL 到 Authorized redirect URIs
3. 回到 LibreDesk: 输入 Client ID 和 Client Secret > 点击 Authorize

### App Password 方式

Google 账号需开启 2-Step Verification。访问 myaccount.google.com/apppasswords 生成 16 位应用密码。

在 LibreDesk: Admin > Inboxes > New inbox > **Other provider**：

**IMAP 设置**:

| 字段 | 值 |
|------|-----|
| Host | `imap.gmail.com` |
| Port | `993` |
| TLS | SSL/TLS |
| Username | 完整 Gmail 地址 |
| Password | 应用密码 |

**SMTP 设置**:

| 字段 | 值 |
|------|-----|
| Host | `smtp.gmail.com` |
| Port | `587` |
| TLS | STARTTLS |
| Authentication Protocol | PLAIN |
| Username | 完整 Gmail 地址 |
| Password | 应用密码 |

## Microsoft 设置

**前置条件**：Azure AD 应用注册 + OAuth 2.0 凭据

**所需 Microsoft Graph 委托权限**：

| Permission | Type | 描述 |
|-----------|------|------|
| email | Delegated | 查看用户邮箱地址 |
| IMAP.AccessAsUser.All | Delegated | 通过 IMAP 读写邮箱 |
| offline_access | Delegated | 维持数据访问 |
| openid | Delegated | 用户登录 |
| SMTP.Send | Delegated | 通过 SMTP AUTH 发送邮件 |
| User.Read | Delegated | 登录并读取用户资料 |

**配置步骤**：
1. LibreDesk: Admin > Inboxes > New inbox > Microsoft，复制 Callback URL
2. Azure Portal > Azure AD > App registrations > New registration > 添加 Callback URL 为 Redirect URI
3. API permissions > 添加上述委托权限 > Grant admin consent
4. Certificates & secrets > New client secret > 复制 secret value
5. 复制 Application (client) ID 和 Directory (tenant) ID
6. 回到 LibreDesk: 输入 Client ID、Client Secret、Tenant ID(可选) > Authorize

## 手动 IMAP/SMTP 设置

适用于自建邮件服务器或不支持 OAuth 的邮件服务。

在 LibreDesk: Admin > Inboxes > New inbox > Other provider > 配置 IMAP 和 SMTP 设置 > Save。
