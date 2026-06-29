# API 端点汇总

> 原文: https://docs.libredesk.io/llms.txt
> 完整 OpenAPI 规范: https://docs.libredesk.io/api-reference/openapi.json
> 关键词: API, 端点, Agents, Conversations, Contacts, Teams, Search, AI, Media

Base URL: `https://your-instance.com/api/v1`

认证方式见 [API 简介](introduction.md)

## Agents (代理管理)

| 方法 | 端点 | 说明 |
|------|------|------|
| POST | `/agents` | 创建 Agent |
| GET | `/agents` | 获取所有 Agent |
| GET | `/agents/{id}` | 获取单个 Agent |
| PUT | `/agents/{id}` | 更新 Agent |
| DELETE | `/agents/{id}` | 删除 Agent |
| GET | `/agents/me` | 获取当前 Agent |
| POST | `/agents/{id}/api_key` | 生成 API Key |
| DELETE | `/agents/{id}/api_key` | 撤销 API Key |
| PUT | `/agents/me/availability` | 更新当前 Agent 在线状态 |

## AI Completions (AI 补全)

| 方法 | 端点 | 说明 |
|------|------|------|
| POST | `/ai/completion` | AI 文本补全 |
| GET | `/ai/prompts` | 获取 AI 提示词 |
| PUT | `/ai/provider` | 更新 AI 提供商 |

## Contact Notes (联系人备注)

| 方法 | 端点 | 说明 |
|------|------|------|
| POST | `/contacts/{id}/notes` | 创建联系人备注 |
| GET | `/contacts/{id}/notes` | 获取联系人备注 |
| DELETE | `/contacts/{id}/notes/{note_id}` | 删除联系人备注 |

## Contacts (联系人)

| 方法 | 端点 | 说明 |
|------|------|------|
| GET | `/contacts` | 获取所有联系人 |
| GET | `/contacts/{id}` | 获取单个联系人 |
| PUT | `/contacts/{id}` | 更新联系人 |
| POST | `/contacts/{id}/block` | 封禁/解封联系人 |

## Conversations (对话)

| 方法 | 端点 | 说明 |
|------|------|------|
| POST | `/conversations` | 创建对话 |
| GET | `/conversations` | 获取所有对话 |
| GET | `/conversations/assigned` | 获取当前用户分配的对话 |
| GET | `/conversations/unassigned` | 获取未分配的对话 |
| GET | `/conversations/team_unassigned` | 获取团队已分配但未分配给 Agent 的对话 |
| GET | `/conversations/view/{view_id}` | 获取特定视图的对话 |
| GET | `/conversations/{id}` | 获取单个对话 |
| GET | `/conversations/{id}/participants` | 获取对话参与者 |
| GET | `/conversations/{id}/messages` | 获取对话消息列表 |
| GET | `/conversations/{id}/messages/{msg_id}` | 获取单条消息 |
| POST | `/conversations/{id}/messages` | 发送消息 |
| POST | `/conversations/{id}/messages/{msg_id}/retry` | 重试发送失败的消息 |
| PUT | `/conversations/{id}/status` | 更新对话状态 |
| PUT | `/conversations/{id}/priority` | 更新对话优先级 |
| PUT | `/conversations/{id}/tags` | 更新对话标签 |
| PUT | `/conversations/{id}/assignee/user` | 更新 Agent 分配 |
| PUT | `/conversations/{id}/assignee/team` | 更新团队分配 |
| DELETE | `/conversations/{id}/assignee/user` | 移除 Agent 分配 |
| DELETE | `/conversations/{id}/assignee/team` | 移除团队分配 |
| PUT | `/conversations/{id}/assignee/last_seen` | 更新分配人最后查看时间 |
| PUT | `/conversations/{id}/custom_attributes` | 更新对话自定义属性 |
| PUT | `/conversations/{id}/contact_custom_attributes` | 更新联系人自定义属性 |

## Search (搜索)

| 方法 | 端点 | 说明 |
|------|------|------|
| GET | `/search/contacts` | 搜索联系人 |
| GET | `/search/conversations` | 搜索对话 |
| GET | `/search/messages` | 搜索消息 |

## Status & Priority (状态与优先级)

| 方法 | 端点 | 说明 |
|------|------|------|
| GET | `/statuses` | 获取对话状态列表 |
| POST | `/statuses` | 创建对话状态 |
| PUT | `/statuses/{id}` | 更新对话状态 |
| DELETE | `/statuses/{id}` | 删除对话状态 |
| GET | `/priorities` | 获取优先级列表 |

## Teams (团队)

| 方法 | 端点 | 说明 |
|------|------|------|
| POST | `/teams` | 创建团队 |
| GET | `/teams` | 获取所有团队 |
| GET | `/teams/{id}` | 获取单个团队 |
| PUT | `/teams/{id}` | 更新团队 |
| DELETE | `/teams/{id}` | 删除团队 |

## Other (其他)

| 方法 | 端点 | 说明 |
|------|------|------|
| GET | `/health` | 健康检查 |
| POST | `/media/upload` | 媒体文件上传 |

> 详细的请求/响应参数请参考完整 OpenAPI 规范: https://docs.libredesk.io/api-reference/openapi.json
