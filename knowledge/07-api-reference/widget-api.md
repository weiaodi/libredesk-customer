# Widget API 与 WebSocket 协议

> 原文: https://docs.libredesk.io/api-reference/widget-api
> 关键词: Widget API, 实时聊天, WebSocket, 会话, 前端, 自定义 Widget

本文档汇总 LibreDesk 实时聊天 Widget 使用的公开端点和 WebSocket 消息协议，用于构建自定义 Widget 前端与 LibreDesk 实例通信。

## 认证与收件箱选择

Widget HTTP 请求通过以下方式标识实时聊天收件箱：
- `X-Libredesk-Inbox-ID: <inbox_uuid>` header
- `?inbox_id=<inbox_uuid>` 查询参数

已认证的 Widget 请求还发送：
- `Authorization: Bearer <session_token>`

当已验证联系人替换访客会话时，Widget 还可发送：
- `X-Libredesk-Visitor-Token: <visitor_session_token>`

如果 LibreDesk 将访客合并到已验证联系人，响应包含 `X-Libredesk-Clear-Visitor: true`，前端应丢弃访客 Token。

API 响应使用 LibreDesk 标准信封格式，成功响应的端点 payload 放在 `data` 中。

## 公共设置端点

### `GET /api/v1/widget/chat/settings/launcher`
返回 Widget 嵌入脚本在 iframe 打开前的启动器设置。收件箱通过 `?inbox_id=<inbox_uuid>` 传递。

### `GET /api/v1/widget/chat/settings`
返回实时聊天 Widget 设置，包括公共配置，启用时还有营业时间和预聊天自定义属性元数据。

## 会话端点

### `POST /api/v1/widget/chat/auth/exchange`
将客户签名的 JWT 交换为 Widget 会话 Token。

请求体:
```json
{ "jwt": "<signed_customer_jwt>" }
```

JWT 必须包含 `external_user_id`、`email`、`first_name`。可选 `last_name` 和 `contact_custom_attributes`。

响应 `data`:
```json
{
  "session_token": "<session_token>",
  "user": {
    "user_id": 123,
    "is_visitor": false,
    "first_name": "Ada",
    "last_name": "Lovelace"
  }
}
```

### `GET /api/v1/widget/chat/auth/me`
返回当前 Bearer 会话 Token 对应的 Widget 用户元数据。

## 对话端点

### `POST /api/v1/widget/chat/conversations/init`
发起新的实时聊天对话。无 Bearer Token 时，LibreDesk 创建访客并返回新会话 Token。

请求体:
```json
{
  "message": "Hello, I need help",
  "form_data": { "company": "Example Co" }
}
```

响应 `data` 包含创建的 `conversation`、`messages`、可选营业时间字段，新访客还有 `session_token` 和 `user`。

### `GET /api/v1/widget/chat/conversations`
返回当前 Widget 用户在所选收件箱中可见的对话。

### `GET /api/v1/widget/chat/conversations/{uuid}`
返回单个对话及其消息和可选营业时间元数据。

### `POST /api/v1/widget/chat/conversations/{uuid}/message`
发送文本消息到已有对话。

请求体:
```json
{ "message": "Here are more details" }
```

### `POST /api/v1/widget/chat/conversations/{uuid}/update-last-seen`
标记对话为 Widget 用户已读。

## 上传端点

### `POST /api/v1/widget/media/upload`
上传文件到已有对话。需要 `multipart/form-data`。

表单字段:
- `conversation_uuid`: 目标对话 UUID
- `files`: 一个或多个文件

文件上传在收件箱禁用上传、文件为空、超出大小限制或扩展名不允许时会被拒绝。

## WebSocket 端点

### `GET /widget/ws`

Widget 使用此 WebSocket 端点接收实时对话事件。

打开 Socket 后，发送 `join` 消息:

```json
{
  "type": "join",
  "token": "<session_token>",
  "data": { "inbox_id": "<inbox_uuid>" }
}
```

服务端回复:
```json
{ "type": "joined", "data": { "message": "namaste!" } }
```

### 客户端->服务端消息

**typing** - 广播访客输入状态:
```json
{ "type": "typing", "data": { "conversation_uuid": "<uuid>", "is_typing": true } }
```

**page_visit** - 存储访客当前页面并广播最近页面访问:
```json
{ "type": "page_visit", "data": { "url": "https://example.com/pricing", "title": "Pricing" } }
```

**ping** - 保持会话活跃，应定期发送:
```json
{ "type": "ping" }
```
服务端回复 `pong`。

### 服务端->客户端消息

- `joined`: Socket 已加入实时聊天收件箱
- `pong`: 对 `ping` 的响应
- `new_message`: 新聊天消息，`data` 为消息 payload
- `typing`: Agent 输入状态，含 `conversation_uuid` 和 `is_typing`
- `conversation_update`: 部分对话更新
- `error`: Socket 级别错误 payload
