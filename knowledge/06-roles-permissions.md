# 角色与权限

> 原文: https://docs.libredesk.io/roles/overview
> 关键词: 角色, 权限, RBAC, Agent, Admin, 访问控制

角色是命名的权限集合。每个 Agent 分配一个或多个角色，Agent 的有效访问权限是所有角色权限的并集。

角色管理路径: **Admin > Teams > Roles**

## 默认角色

| 角色 | 说明 |
|------|------|
| `Admin` | 完全访问权限，包括所有设置。此角色不可编辑，如需变体请新建角色 |
| `Agent` | 有限的对话、消息和视图访问权限 |

> `Admin` 角色锁定不可修改。如需部分管理权限，创建新角色并仅勾选所需权限。

## 权限列表

权限格式: `object:action`（如 `roles:manage`）

### 对话权限

| 权限 | 授予的能力 |
|------|-----------|
| `conversations:read` | 打开和读取单个对话（含参与者和搜索），查看任何对话必须此权限 |
| `conversations:write` | 发起新对话 |
| `conversations:read_assigned` | 列出分配给该 Agent 的对话 |
| `conversations:read_all` | 列出所有对话（不论分配给谁） |
| `conversations:read_unassigned` | 列出未分配的对话 |
| `conversations:read_team_inbox` | 列出该 Agent 团队收件箱中未分配的对话 |
| `conversations:read_team_all` | 列出分配给该 Agent 团队的所有对话 |
| `conversations:update_user_assignee` | 分配/移除对话的 Agent |
| `conversations:update_team_assignee` | 分配/移除对话的团队 |
| `conversations:update_priority` | 设置对话优先级 |
| `conversations:update_status` | 变更对话状态（如 open、resolved、snoozed） |
| `conversations:update_tags` | 添加/移除对话标签 |
| `messages:read` | 读取对话中的消息和下载记录 |
| `messages:write` | 回复和发送消息 |
| `messages:write_as_contact` | 以联系人身份发送消息 |
| `view:manage` | 创建和管理 Agent 自己保存的对话视图（过滤器） |

### 管理权限

| 权限 | 授予的能力 |
|------|-----------|
| `general_settings:manage` | 编辑实例级设置（业务名称、品牌、默认值等） |
| `notification_settings:manage` | 配置 Agent 收到的邮件通知 |
| `status:manage` | 创建、重命名和删除对话状态 |
| `oidc:manage` | 添加和编辑 SSO (OpenID Connect) 登录提供商 |
| `tags:manage` | 创建、编辑、删除和导入标签 |
| `macros:manage` | 创建和编辑宏（可复用的回复和操作集合） |
| `users:manage` | 创建、编辑、删除 Agent 并分配角色（见下方警告） |
| `teams:manage` | 创建和编辑团队及其成员 |
| `automations:manage` | 创建和编辑作用于对话的自动化规则 |
| `inboxes:manage` | 创建、配置和删除收件箱（邮件、实时聊天、WhatsApp） |
| `roles:manage` | 创建、编辑和删除角色及其权限 |
| `templates:manage` | 创建和编辑邮件模板 |
| `reports:manage` | 查看报表仪表板（概览、CSAT、SLA、消息量、标签分布） |
| `business_hours:manage` | 定义 SLA 使用的营业时间计划和假期 |
| `sla:manage` | 创建和编辑 SLA 策略 |
| `ai:manage` | 配置 AI 提供商和提示 |
| `custom_attributes:manage` | 创建和编辑对话/联系人的自定义字段 |
| `activity_logs:manage` | 查看活动（审计）日志 |
| `webhooks:manage` | 创建和编辑 Webhook |
| `shared_views:manage` | 创建和管理与其他 Agent 共享的保存视图 |
| `context_links:manage` | 配置对话旁显示的上下文链接 |

> **`users:manage` 等同于完全访问权限**。持有此权限的 Agent 可以给自己分配任何角色（包括 Admin），等同于管理员权限。仅授予完全信任的人。

### 联系人权限

| 权限 | 授予的能力 |
|------|-----------|
| `contacts:read_all` | 列出和查看所有联系人 |
| `contacts:read` | 查看单个联系人资料和搜索联系人 |
| `contacts:write` | 编辑联系人详情 |
| `contacts:block` | 封禁/解封联系人 |
| `contact_notes:read` | 读取联系人的私人备注 |
| `contact_notes:write` | 添加联系人的私人备注 |
| `contact_notes:delete` | 删除联系人的私人备注 |

## 创建角色

1. 导航到 **Admin > Teams > Roles** > **New role**
2. 输入名称和可选描述
3. 勾选要授予的权限（未勾选的即被拒绝）
4. 保存角色，然后在 Agent 的用户设置中分配角色

Agent 的访问权限 = 所有已分配角色权限的并集。
