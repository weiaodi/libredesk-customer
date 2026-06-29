# 实时聊天 (Live Chat)

> 原文: https://docs.libredesk.io/configuration/livechat
> 关键词: 聊天, Widget, 实时, 嵌入, JWT, 身份验证, JavaScript API, WebSocket

LibreDesk 实时聊天 Widget 可嵌入任何网站。`baseURL` 是 LibreDesk 实例 URL，`inboxID` 是收件箱 UUID（在收件箱的 **Installation** 标签页查看）。

每个会话默认视为新的匿名访客，除非添加身份验证。

## 身份验证 (Identity Verification)

用户已登录你的产品时，传递签名 JWT 让 Widget 加载其已有 LibreDesk 联系人。

### 工作原理

1. 你的服务器用收件箱 **Secret key**（在 **Security** 标签页）签名 JWT
2. 页面通过 `userJWT` 传递 JWT 给 Widget
3. LibreDesk 验证签名，通过 `external_user_id` upsert 联系人

签名算法: **HS256** (HMAC-SHA256)。密钥永远不要离开服务器。

### JWT Payload

```json
{
  "external_user_id": "your_app_user_123",
  "email": "user@example.com",
  "first_name": "John",
  "last_name": "Doe",
  "exp": 1735689600,
  "contact_custom_attributes": {
    "plan": "premium",
    "company": "Acme Inc"
  }
}
```

| 字段 | 必填 | 说明 |
|------|------|------|
| `external_user_id` | 是 | 你系统中的稳定唯一 ID，用于匹配回访用户 |
| `email` | 是 | 用户邮箱 |
| `first_name` | 是 | 用户名 |
| `last_name` | 否 | 姓氏 |
| `exp` | 是 | Token 过期的 Unix 时间戳（秒） |
| `contact_custom_attributes` | 否 | 写入联系人记录的自定义属性对象 |

### 服务端签名示例

**Python**:
```python
import jwt, time
payload = {
    "external_user_id": "your_app_user_123",
    "email": "user@example.com",
    "first_name": "John",
    "exp": int(time.time()) + 3600,
}
token = jwt.encode(payload, SECRET, algorithm="HS256")
```

**Node.js**:
```javascript
const jwt = require('jsonwebtoken');
const token = jwt.sign({
  external_user_id: 'your_app_user_123',
  email: 'user@example.com',
  first_name: 'John',
  exp: Math.floor(Date.now() / 1000) + 3600,
}, SECRET, { algorithm: 'HS256' });
```

**Go**:
```go
import (
    "time"
    "github.com/golang-jwt/jwt/v5"
)
claims := jwt.MapClaims{
    "external_user_id": "your_app_user_123",
    "email":            "user@example.com",
    "first_name":       "John",
    "exp":              time.Now().Add(time.Hour).Unix(),
}
token, _ := jwt.NewWithClaims(jwt.SigningMethodHS256, claims).
    SignedString([]byte(SECRET))
```

> 永远不要将收件箱密钥嵌入客户端代码。在服务端签名 JWT 并在渲染时注入页面。

## JavaScript API

Widget 加载后，`window.Libredesk` 暴露以下方法：

| 方法 | 说明 |
|------|------|
| `Libredesk.show()` | 打开 Widget |
| `Libredesk.hide()` | 关闭 Widget |
| `Libredesk.toggle()` | 切换开关 |
| `Libredesk.setUser(jwt)` | 用签名 JWT 登录用户 |
| `Libredesk.logout()` | 清除当前会话，重置为匿名 |
| `Libredesk.onShow(fn)` | Widget 打开时触发回调 |
| `Libredesk.onHide(fn)` | Widget 关闭时触发回调 |
| `Libredesk.onUnreadCountChange(fn)` | 未读消息数变化时触发回调 |

示例:
```javascript
window.Libredesk.onUnreadCountChange(function (count) {
  document.title = count > 0 ? `(${count}) Inbox` : 'Inbox';
});
```

## 对话连续性 (Conversation Continuity)

Agent 离线时，访客通常离开。在 **General > Conversation continuity** 中将实时聊天收件箱链接到邮箱收件箱，LibreDesk 会将访客消息通过邮件发送给 Agent。

| 设置 | 说明 |
|------|------|
| `offline_threshold` | Agent 离线多久后启动邮件回退（如 `10m`） |
| `max_messages_per_email` | 每封邮件最大消息数，超出则分拆为新邮件 |
| `min_email_interval` | 同一对话两次回退邮件的最小间隔 |

邮件回复会回到同一实时聊天对话中。

## 安全设置

### 可信域名 (Trusted Domains)

在 **Security** 标签页列出允许嵌入 Widget 的域名，支持通配符：

```
example.com
*.example.com
staging.example.com
```

留空则允许所有来源（生产环境务必设置）。

### 封禁 IP

阻止特定 IP 或 CIDR 范围打开 Widget：

```
192.168.1.0/24
10.0.0.1
2001:db8::/32
```

### 会话时长

控制 Widget 会话在重新验证 JWT 前保持认证多长时间。默认 `10h`。格式支持 `s`、`m`、`h`（如 `30m`、`24h`）。
