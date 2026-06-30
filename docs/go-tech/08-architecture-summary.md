# 架构模式总结与学习路线

## 分层架构

LibreDesk 的 Go 后端采用经典的**三层架构**：

```
cmd/                    → HTTP 层（handler + 中间件 + 路由）
  ├── handlers.go       → 路由注册
  ├── middlewares.go    → 认证、权限、限流中间件
  ├── conversation.go  → 会话相关 handler
  ├── users.go         → 用户相关 handler
  └── ...

internal/               → 业务逻辑层（核心逻辑，不依赖 HTTP）
  ├── conversation/     → 会话管理
  │   ├── conversation.go   → Manager（业务逻辑）
  │   ├── models/models.go → 数据模型
  │   └── queries.sql      → SQL 语句
  ├── user/            → 用户管理
  ├── ws/              → WebSocket
  ├── authz/           → 权限
  └── ...

schema.sql              → 数据库层（DDL）
```

## 依赖注入模式

LibreDesk 使用**构造函数注入**：

```go
// 创建 Conversation Manager 时注入所有依赖
func initConversations(
    i18n *i18n.I18n,
    sla *sla.Manager,           // 注入 SLA 服务
    status *status.Manager,     // 注入状态服务
    priority *priority.Manager,  // 注入优先级服务
    hub *ws.Hub,                // 注入 WebSocket Hub
    db *sqlx.DB,                // 注入数据库连接
    inboxStore *inbox.Manager,   // 注入收件箱服务
    userStore *user.Manager,     // 注入用户服务
    // ...
) *conversation.Manager {
    c, err := conversation.New(hub, i18n, sla, status, priority, inboxStore, userStore, ...)
    return c
}
```

## Manager 模式

每个业务模块都有一个 `Manager` 结构体，封装所有操作：

```go
// internal/user/user.go
type Manager struct {
    lo           *logf.Logger
    i18n         *i18n.I18n
    q            queries
    db           *sqlx.DB
    agentCache   map[int]cachedAgent
    agentCacheMu sync.RWMutex
}

// internal/tag/tag.go
type Manager struct {
    lo   *logf.Logger
    i18n *i18n.I18n
    q    queries
    db   *sqlx.DB
}
```

## 优雅关闭

**项目实例** — `cmd/main.go`：

```go
// 监听系统信号
ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGINT, syscall.SIGTERM)
defer stop()

// 启动所有服务...

// 等待关闭信号
<-ctx.Done()

// 按顺序关闭各个组件
s.Shutdown()          // HTTP 服务器
inbox.Close()         // 收件箱
automation.Close()    // 自动化引擎
autoassigner.Close()  // 自动分配
notifier.Close()      // 通知
webhook.Close()       // Webhook
conversation.Close()  // 会话
sla.Close()           // SLA
db.Close()            // 数据库
rdb.Close()           // Redis
```

---

## 学习路线建议

### 第一阶段：Go 语法基础（1-2 周）

| 主题 | 学习要点 | 项目对应代码 |
|------|---------|-------------|
| 包与模块 | go mod、import、可见性 | `go.mod`, `cmd/main.go` |
| 变量与类型 | var、const、struct tag | `cmd/main.go`, `internal/conversation/models/models.go` |
| 函数 | 多返回值、闭包、Opts 模式 | `cmd/main.go` (onUsersOffline) |
| 结构体与方法 | 指针/值接收者、嵌入 | `internal/ws/client.go` (SafeBool) |
| 接口 | 隐式实现、类型断言 | `internal/ws/ws.go` (userStore) |
| 错误处理 | if err != nil、自定义错误 | `internal/envelope/envelope.go` |

### 第二阶段：Go 并发编程（1-2 周）

| 主题 | 学习要点 | 项目对应代码 |
|------|---------|-------------|
| goroutine | go 关键字、并发启动 | `cmd/main.go` (go xxx.Run) |
| channel | 有缓冲/无缓冲、阻塞/非阻塞 | `internal/ws/client.go` (Send chan) |
| select | 多路复用、超时控制 | `internal/ws/client.go` (Serve) |
| Mutex | RWMutex、defer Unlock | `internal/ws/ws.go` |
| Context | 取消、超时、传值 | `cmd/main.go` (signal.NotifyContext) |
| WaitGroup | 等待 goroutine 完成 | `internal/conversation/conversation.go` |

### 第三阶段：Web 开发实战（2-3 周）

| 主题 | 学习要点 | 项目对应代码 |
|------|---------|-------------|
| HTTP 框架 | fasthttp/fastglue 或 net/http | `cmd/handlers.go` |
| 中间件 | 高阶函数、洋葱模型 | `cmd/middlewares.go` |
| 数据库 | sqlx、SQL 分离 | `internal/conversation/queries.sql` |
| 配置管理 | koanf、TOML | `cmd/init.go`, `config.sample.toml` |
| WebSocket | Hub-Client 模式 | `internal/ws/` |
| 日志 | 结构化日志 | 项目中广泛使用 logf |

### 第四阶段：项目实践

1. **阅读项目**：从 `cmd/main.go` 开始，跟踪服务启动流程
2. **跟踪一个请求**：从路由 → 中间件 → handler → Manager → SQL
3. **添加小功能**：比如添加一个新的 API 端点
4. **编写测试**：参考 `internal/automation/evaluator_test.go`

### 推荐学习资源

| 资源 | 说明 |
|------|------|
| [Go 官方教程](https://go.dev/tour/) | 交互式入门教程 |
| [Effective Go](https://go.dev/doc/effective_go) | 官方最佳实践 |
| [Go by Example](https://gobyexample.com/) | 代码示例学习 |
| [Go 语言圣经](https://gopl-zh.github.io/) | 中文经典教材 |
| 项目 `knowledge/` 目录 | LibreDesk 功能文档 |

---

> **相关文档**：
> - 上一章：[WebSocket 实时通信](07-websocket.md)
> - 深入架构：[后端架构设计方案](../go-architecture/)
