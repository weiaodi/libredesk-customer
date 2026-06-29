# Webhook 事件通知

> 原文: https://docs.libredesk.io/configuration/webhooks
> 关键词: Webhook, 事件通知, HTTP, 回调, 消息, 对话

LibreDesk 支持发送实时 HTTP 通知，当特定事件发生时向外部系统推送数据。

## 事件类型

### message.created

当对话中创建新消息时触发。

**Payload 示例**：

```json
{
  "event": "message.created",
  "timestamp": "2025-06-15T10:33:00Z",
  "payload": {
    "id": 987,
    "created_at": "2025-06-15T10:33:00Z",
    "updated_at": "2025-06-15T10:33:00Z",
    "uuid": "123e4567-e89b-12d3-a456-426614174000",
    "type": "outgoing",
    "status": "sent",
    "conversation_id": 123,
    "content": "<p>Hello! How can I help you today?</p>",
    "text_content": "Hello! How can I help you today?",
    "content_type": "html",
    "private": false,
    "sender_id": 789,
    "sender_type": "agent",
    "attachments": []
  }
}
```

**Payload 字段说明**：

| 字段 | 说明 |
|------|------|
| `id` | 消息 ID |
| `uuid` | 消息 UUID |
| `type` | 消息类型: `incoming` / `outgoing` |
| `status` | 消息状态: `sent` / `delivered` / `failed` 等 |
| `conversation_id` | 所属对话 ID |
| `content` | HTML 内容 |
| `text_content` | 纯文本内容 |
| `content_type` | 内容类型: `html` |
| `private` | 是否为内部备注 |
| `sender_id` | 发送者 ID |
| `sender_type` | 发送者类型: `agent` / `contact` |
| `attachments` | 附件列表 |

## 配置 Webhook

在 LibreDesk: Admin > Settings > Webhooks > New webhook，输入目标 URL 并选择要订阅的事件类型。
