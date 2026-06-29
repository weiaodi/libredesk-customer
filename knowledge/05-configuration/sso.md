# SSO 单点登录配置

> 原文: https://docs.libredesk.io/configuration/sso
> 关键词: SSO, 单点登录, OpenID Connect, Keycloak, OAuth

LibreDesk 支持外部 OpenID Connect 提供商（如 Google、Keycloak）用于用户登录。

> 注意：用户账号必须在 LibreDesk 中手动创建，不支持注册。

## 通用配置步骤

1. **提供商设置**：在提供商管理控制台创建新的 OpenID Connect 应用/客户端，获取 Client ID 和 Client Secret
2. **LibreDesk 配置**：导航到 Security > SSO，点击 New SSO，输入：
   - Provider URL（如 OpenID 提供商的 URL）
   - Client ID
   - Client Secret
   - 描述性名称
3. **回调 URL**：保存后复制 LibreDesk 生成的 Callback URL，将其添加到提供商客户端设置的 Valid Redirect URIs

## Keycloak 示例

### 创建客户端

在 Keycloak: Clients > Create:
- Client ID: 如 `libredesk-app`
- Client Protocol: `openid-connect`
- Root URL 和 Web Origins: 你的应用域名（如 `https://ticket.example.com`）
- Authentication flow: 仅勾选 standard flow
- 保存

### 配置凭据

Credentials 标签页:
- Client Authenticator: `Client Id and Secret`
- 记录生成的 Client Secret

### 配置 LibreDesk SSO

Admin > Security > SSO > New SSO:
- Provider URL: 如 `https://keycloak.example.com/realms/yourrealm`
- Name: 如 `Keycloak`
- Client ID + Client Secret
- 保存

保存后:
1. 点击三点菜单 > Edit 打开 SSO 条目
2. 复制 LibreDesk 生成的 Callback URL
3. 在 Keycloak 中编辑客户端，将 Callback URL 添加到 Valid Redirect URIs（如 `https://ticket.example.com/api/v1/oidc/1/finish`）
