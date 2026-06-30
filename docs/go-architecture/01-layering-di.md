# 架构分层与依赖注入设计

> 本文档以 LibreDesk 客户支持平台为真实案例，讲解 Go 后端项目的分层架构设计和依赖注入模式。

---

## 1. 整体架构分层设计

### 1.1 三层架构

LibreDesk 采用经典的**三层架构**（Layered Architecture），这是 Go 后端项目中最主流的组织方式：

```
┌──────────────────────────────────────────────────────┐
│                   HTTP 层 (cmd/)                      │
│  路由注册 → 中间件链 → Handler 函数 → 请求解析/响应   │
│  职责：HTTP 协议处理，不包含业务逻辑                  │
├──────────────────────────────────────────────────────┤
│                 业务逻辑层 (internal/)                  │
│  Manager 结构体 → 业务规则 → 数据编排 → 事件触发      │
│  职责：核心业务逻辑，不依赖 HTTP 框架                  │
├──────────────────────────────────────────────────────┤
│                  数据访问层 (internal/)                │
│  SQL 文件 → queries 结构体 → sqlx 预编译语句          │
│  职责：数据库 CRUD，不包含业务判断                     │
└──────────────────────────────────────────────────────┘
```

**项目对应代码**：

| 层级 | 目录 | 职责 | 示例 |
|------|------|------|------|
| HTTP 层 | `cmd/handlers.go` | 路由注册 | `g.GET("/api/v1/conversations", ...)` |
| HTTP 层 | `cmd/middlewares.go` | 认证/权限/限流 | `auth()`, `perm()`, `rateLimit()` |
| HTTP 层 | `cmd/conversation.go` | 请求解析+响应 | `handleGetConversations()` |
| 业务层 | `internal/conversation/conversation.go` | 会话业务逻辑 | `Manager.CreateConversation()` |
| 业务层 | `internal/automation/automation.go` | 自动化规则引擎 | `Engine.handleNewConversation()` |
| 数据层 | `internal/conversation/queries.sql` | SQL 语句 | `-- name: get-conversation` |
| 数据层 | `internal/conversation/conversation.go` | queries 结构体 | `type queries struct { ... }` |

### 1.2 为什么 Go 项目偏向三层架构而非六边形架构？

| 架构风格 | 适用场景 | Go 社区偏好 |
|---------|---------|-----------|
| 三层架构 | CRUD 为主、业务流程明确的系统 | **最常见**，简单直接 |
| 六边形架构 | 需要多适配器、多端口的复杂系统 | 较少使用，Go 哲学偏好简单 |
| DDD | 领域逻辑极复杂的系统 | 极少使用，Go 偏好"实用主义" |
| 微服务 | 超大规模、团队独立部署 | 中大型项目使用 |

LibreDesk 选择三层架构的**考量**：
- 业务逻辑以 CRUD + 消息处理为主，不需要过度抽象
- Go 的接口系统天然支持解耦，不需要额外端口/适配器层
- 代码直观可读，新人上手成本低

### 1.3 cmd/ vs internal/ 的职责划分

```
cmd/              → "薄" HTTP 层，只做协议适配
                     ├── 参数解析（从请求中提取参数）
                     ├── 调用 internal 层的 Manager 方法
                     └── 构造 HTTP 响应

internal/         → "厚" 业务层，包含所有核心逻辑
                     ├── 业务规则判断
                     ├── 数据库操作
                     ├── 事件触发
                     └── 跨模块协调
```

**Handler 的标准写法**（`cmd/conversation.go`）：

```go
func handleGetConversations(r *fastglue.Request) error {
    // 1. 获取全局上下文
    app := r.Context.(*App)

    // 2. 从请求提取参数
    page, pageSize := getPagination(r)
    user := r.RequestCtx.UserValue("user").(amodels.User)

    // 3. 调用业务层（核心逻辑在 internal/ 中）
    conversations, err := app.conversation.GetConversations(...)

    // 4. 构造响应
    if err != nil {
        return sendErrorEnvelope(r, err)
    }
    return r.SendEnvelope(conversations)
}
```

**关键原则：Handler 不做业务判断，只做协议转换。**

---

## 2. 依赖注入与解耦设计

### 2.1 构造函数注入

LibreDesk 不使用 DI 框架（如 Wire、Dig），而是用**手工构造函数注入**。这在 Go 中是最主流的做法：

```go
// internal/conversation/conversation.go
func New(
    wsHub *ws.Hub,                  // WebSocket Hub
    i18n *i18n.I18n,                 // 国际化
    slaStore slaStore,               // SLA 服务（接口，不是具体类型！）
    statusStore statusStore,          // 状态服务（接口）
    priorityStore priorityStore,      // 优先级服务（接口）
    inboxStore inboxStore,            // 收件箱服务（接口）
    userStore userStore,              // 用户服务（接口）
    teamStore teamStore,              // 团队服务（接口）
    mediaStore mediaStore,            // 媒体服务（接口）
    settingsStore settingsStore,      // 设置服务（接口）
    csatStore csatStore,              // CSAT 服务（接口）
    automation *automation.Engine,    // 自动化引擎（具体类型）
    template *template.Manager,       // 模板管理（具体类型）
    webhook webhookStore,             // Webhook 服务（接口）
    dispatcher *notifier.Dispatcher,  // 通知分发器（具体类型）
    opts Opts,                        // 配置选项
) (*Manager, error) {
    // ...
}
```

### 2.2 接口 vs 具体类型的选择考量

项目中混合使用了**接口**和**具体类型**作为依赖，选择依据：

| 依赖方式 | 何时使用 | 项目示例 |
|---------|---------|---------|
| 接口 | 可能被替换/模拟；仅使用部分方法 | `userStore`, `inboxStore`, `webhookStore` |
| 具体类型 | 一对一绑定；使用其完整 API | `*ws.Hub`, `*notifier.Dispatcher` |
| 接口（小接口） | 只需要 1-3 个方法 | `conversationStore` 在 ws 包中 |

**接口粒度的考量**：

```go
// 大接口（internal/conversation/conversation.go 中）
type userStore interface {
    Get(int, string, []string) (umodels.User, error)
    GetAgent(int, string) (umodels.User, error)
    GetAgentCachedOrLoad(int) (umodels.User, error)
    GetSystemUser() (umodels.User, error)
    CreateContact(user *umodels.User) error
    UpgradeVisitorToContact(visitorID int) error
}

// 小接口（internal/ws/ws.go 中）—— 只需要 1 个方法
type userStore interface {
    UpdateLastActive(userID int) (bool, error)
}
```

**Go 的接口设计哲学**：**"The bigger the interface, the weaker the abstraction."**（接口越大，抽象越弱）。Go 鼓励定义小而精的接口，由消费者定义，而非提供者。

### 2.3 循环依赖的解决

Conversation Manager 和 Automation Engine 之间存在**双向依赖**：

```
Conversation ←→ Automation
    (调用 Automation)    (调用 Conversation.ApplyAction)
```

LibreDesk 的解决方案——**两阶段初始化 + Setter 注入**：

```go
// cmd/main.go
// 阶段1：创建 Automation Engine（不依赖 Conversation）
automation := initAutomationEngine(db, i18n)

// 阶段2：创建 Conversation Manager（注入 Automation）
conversation := initConversations(i18n, ..., automation, ...)

// 阶段3：回填依赖 — Automation 需要 Conversation，通过 Setter 注入
wsHub.SetConversationStore(conversation)
automation.SetConversationStore(conversation)
```

```go
// internal/automation/automation.go
type Engine struct {
    conversationStore conversationStore  // 接口！不是 *conversation.Manager
    // ...
}

func (e *Engine) SetConversationStore(store conversationStore) {
    e.conversationStore = store  // 后注入
}
```

**为什么用接口？** 如果 `Engine` 直接依赖 `*conversation.Manager`，就会产生 Go 编译期的**循环导入**错误。用接口切断依赖链，只在运行时注入实现。

---

> **相关文档**：
> - 下一篇：[后台任务与消息队列架构](02-task-queue.md)
> - 基础知识：[Go 接口](../go-basics/06-interfaces.md)
