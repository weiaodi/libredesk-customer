# 实时通信与多渠道架构

> 本文档讲解 LibreDesk 中的 WebSocket Hub-Client 架构和多渠道适配器（Inbox）设计模式。

---

## 1. WebSocket Hub-Client 架构

### 1.1 架构设计

```
┌─ Agent Browser ─┐         ┌─ Agent Browser ─┐
│   WS Client A    │         │   WS Client B    │
└───────┬──────────┘         └───────┬──────────┘
        │ WS 连接                    │ WS 连接
        ▼                            ▼
┌─────────────────────────────────────────────────┐
│                     Hub                          │
│                                                  │
│  clients: map[userID][]*Client                    │
│  ├── 用户1 → [Client1, Client2]  (多标签页)      │
│  └── 用户2 → [Client3]                           │
│                                                  │
│  convSubsList: 会话UUID → 订阅的客户端集合         │
│  ├── conv-aaa → {Client1, Client3}               │
│  └── conv-bbb → {Client2}                        │
│                                                  │
│  convSubsOpen: 会话UUID → 当前打开的客户端         │
│  ├── conv-aaa → {Client1}   (当前正在查看)        │
│  └── conv-bbb → {Client2}                        │
└─────────────────────────────────────────────────┘
```

### 1.2 双层订阅模型

LibreDesk 设计了**双层订阅**来区分"列表中的会话"和"当前打开的会话"：

```go
// 列表订阅（用户在收件箱列表页看到的所有会话）
convSubsList  map[string]map[*Client]struct{}

// 打开订阅（用户当前正在查看的会话）
convSubsOpen  map[string]map[*Client]struct{}
```

**设计考量**：用户在收件箱列表刷新时，列表订阅会全部替换（`SubscribeListReplace`），但打开的会话订阅不受影响（`SubscribeOpenConv`）。这保证了从列表页点击进入某个会话时，深度链接的实时消息不会中断。

### 1.3 多标签页支持

同一用户可能有多个浏览器标签页连接：

```go
clients map[int][]*Client  // userID → 多个 Client 连接
```

广播时遍历该用户的所有连接，确保每个标签页都收到消息。

### 1.4 心跳与断线检测

```go
func (c *Client) Serve() {
    heartBeatTicker := time.NewTicker(2 * time.Second)
    for {
        select {
        case <-heartBeatTicker.C:
            // 发送 Ping，如果连接已断开则 WriteMessage 返回错误
            if err := c.Conn.WriteMessage(websocket.PingMessage, nil); err != nil {
                return  // 连接已断，Serve goroutine 退出
            }
        case msg := <-c.Send:
            c.Conn.WriteMessage(msg.MessageType, msg.Data)
        }
    }
}
```

---

## 2. 认证与授权架构

### 2.1 多方式认证

LibreDesk 支持**三种认证方式**，由统一的 `authenticateUser` 函数处理：

```
请求到达
  │
  ├── 检查 Authorization Header (API Key + Secret)
  │    └── 成功 → 设置 auth_method = "api_key"
  │
  ├── 检查 Session Cookie (Session-Based)
  │    ├── POST/PUT/DELETE → 验证 CSRF Token
  │    └── 验证 Session → 成功 → 设置 auth_method = "session"
  │
  └── 都失败 → 返回 401
```

**项目实例** — `cmd/middlewares.go`：

```go
func authenticateUser(r *fastglue.Request, app *App) (models.User, error) {
    // 1. 先尝试 API Key 认证
    apiKey, apiSecret, err := r.ParseAuthHeader(fastglue.AuthBasic | fastglue.AuthToken)
    if err == nil && len(apiKey) > 0 {
        user, err = app.user.ValidateAPIKey(string(apiKey), string(apiSecret))
        if err == nil {
            r.RequestCtx.SetUserValue("auth_method", "api_key")
            return user, nil
        }
    }

    // 2. Session 认证（需验证 CSRF）
    if method == "POST" || method == "PUT" || method == "DELETE" {
        // CSRF: Cookie 中的 token 必须等于 Header 中的 token
        cookieToken := r.RequestCtx.Request.Header.Cookie("csrf_token")
        hdrToken := r.RequestCtx.Request.Header.Peek("X-CSRFTOKEN")
        if cookieToken != hdrToken {
            return user, envelope.NewError(envelope.PermissionError, "CSRF mismatch", nil)
        }
    }

    // 3. 验证 Session
    sessUser, err := app.auth.ValidateSession(r)
    // ...
}
```

### 2.2 RBAC 权限模型

LibreDesk 使用**基于角色的访问控制**（RBAC），权限粒度为 `object:action`：

```
用户 → 角色 → 权限列表
                ├── conversations:read_all
                ├── conversations:read_assigned
                ├── conversations:update_status
                ├── messages:write
                ├── teams:manage
                └── ...
```

**项目实例** — `internal/authz/authz.go`：

```go
func (e *Enforcer) Enforce(user umodels.User, obj, act string) (bool, error) {
    return slices.Contains(user.Permissions, obj+":"+act), nil
}
```

**会话级权限**（更细粒度）：

```go
func CanReadAssignment(user umodels.User, assignedUserID, assignedTeamID null.Int) bool {
    // 基础权限
    if !slices.Contains(user.Permissions, authzmodels.PermConversationsRead) {
        return false
    }
    // 全局权限
    if slices.Contains(user.Permissions, authzmodels.PermConversationsReadAll) {
        return true
    }
    // 分配给自己的
    if assignedUserID.Valid && assignedUserID.Int == user.ID &&
        slices.Contains(user.Permissions, authzmodels.PermConversationsReadAssigned) {
        return true
    }
    // 团队收件箱
    if assignedTeamID.Valid && slices.Contains(user.Teams.IDs(), assignedTeamID.Int) {
        if !assignedUserID.Valid && slices.Contains(user.Permissions, authzmodels.PermConversationsReadTeamInbox) {
            return true
        }
    }
    // 未分配的
    if !assignedUserID.Valid && !assignedTeamID.Valid &&
        slices.Contains(user.Permissions, authzmodels.PermConversationsReadUnassigned) {
        return true
    }
    return false
}
```

### 2.3 中间件链组合

认证和权限通过中间件组合，在路由注册时声明式指定：

```go
// 需要登录 + 特定权限
g.PUT("/api/v1/conversations/{uuid}/status", perm(handleUpdateConversationStatus, "conversations:update_status"))

// 只需要登录
g.GET("/api/v1/conversations", auth(handleGetConversations))

// 公开接口 + 限流
g.POST("/api/v1/auth/login", rateLimit(handleLogin, "auth"))

// 多层组合：限流 + 可选认证
g.POST("/api/v1/agents/reset-password", rateLimit(tryAuth(handleResetPassword), "auth"))

// 签名 URL 或认证（媒体访问）
g.GET("/uploads/{uuid}", authOrSignedURL(handleServeMedia))
```

---

## 3. 多渠道适配器架构

### 3.1 Strategy 模式

LibreDesk 支持多种消息渠道（Email、LiveChat），通过**接口 + 策略模式**实现渠道适配：

```go
// internal/inbox/inbox.go

// Inbox 接口 — 所有渠道必须实现
type Inbox interface {
    Closer                              // Close() error
    Identifier                          // Identifier() int
    MessageHandler                      // Receive(ctx) + Send(msg)
    Name() string
    FromAddress() string
    Channel() string
}

// 具体实现
// internal/inbox/channel/email/     → Email Inbox
// internal/inbox/channel/livechat/  → LiveChat Inbox
```

### 3.2 运行时注册

Inbox Manager 在启动时从数据库加载所有收件箱配置，按渠道类型初始化对应实现：

```go
type Manager struct {
    inboxes   map[int]Inbox     // 内存中维护所有活跃的收件箱实例
    msgStore  MessageStore      // 消息存储（接口）
    usrStore  UserStore         // 用户存储（接口）
}

// 注册收件箱实例
func (m *Manager) Register(i Inbox) {
    m.mu.Lock()
    defer m.mu.Unlock()
    m.inboxes[i.Identifier()] = i
}

// 获取收件箱
func (m *Manager) Get(id int) (Inbox, error) {
    m.mu.RLock()
    defer m.mu.RUnlock()
    i, ok := m.inboxes[id]
    // ...
}
```

### 3.3 新增渠道的扩展方式

只需三步即可添加新的消息渠道（如 SMS、WhatsApp）：

1. 实现 `Inbox` 接口
2. 在初始化函数中注册新渠道的 `initFn`
3. 数据库中添加渠道记录

不需要修改任何已有代码——**开闭原则（OCP）**。

---

> **相关文档**：
> - 上一篇：[后台任务与消息队列架构](02-task-queue.md)
> - 下一篇：[安全防护与配置管理](04-security-config.md)
> - 基础知识：[Go 接口](../go-basics/06-interfaces.md)
