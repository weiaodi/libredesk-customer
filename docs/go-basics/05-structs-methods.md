# 基础概念：结构体与方法

## 结构体定义

结构体是 Go 中组织数据的核心方式：

**项目实例** — `cmd/main.go` 中的 App 结构体（全局应用上下文）：

```go
// App 是全局应用上下文，被注入到所有 HTTP handler 中
type App struct {
    ctx              context.Context     // 上下文
    fs               stuffbin.FileSystem // 文件系统
    consts           atomic.Value        // 原子值（线程安全）
    auth             *auth_.Auth         // 认证服务
    authz            *authz.Enforcer     // 权限服务
    i18n             *i18n.I18n          // 国际化
    lo               *logf.Logger        // 日志
    user             *user.Manager       // 用户管理
    conversation     *conversation.Manager  // 会话管理
    wsHub            *ws.Hub             // WebSocket 中心
    redis            *redis.Client       // Redis 客户端
    // ... 更多服务

    sync.Mutex                            // 嵌入互斥锁（组合）
}
```

## 方法定义

Go 的方法就是带**接收者**的函数，接收者决定了这个方法属于哪个类型：

**项目实例** — `internal/conversation/models/models.go`：

```go
// 值接收者：方法不会修改结构体
func (c *ConversationContact) FullName() string {
    if c.LastName == "" {
        return c.FirstName
    }
    return c.FirstName + " " + c.LastName
}

// 指针接收者：方法会修改结构体
func (m *Message) CensorCSATContentWithStatus(csatSubmitted bool, csatUUID string, rating int, feedback string) {
    m.Content = "Please rate this conversation"    // 修改字段
    m.TextContent = m.Content                       // 修改字段
    // ...
}
```

**何时用指针接收者 vs 值接收者？**
- 需要修改接收者 → 指针接收者
- 结构体较大（避免拷贝开销）→ 指针接收者
- 需要保证一致性（同一类型所有方法用同一种接收者）→ 通常全用指针

## 结构体嵌入（组合代替继承）

Go 没有继承，使用**组合**来实现代码复用：

**项目实例** — `cmd/main.go`：

```go
type App struct {
    // ...
    sync.Mutex    // 嵌入 Mutex，App 直接拥有 Lock/Unlock 方法
}
```

**项目实例** — `internal/ws/client.go` 中的线程安全布尔：

```go
type SafeBool struct {
    flag bool
    mu   sync.RWMutex    // 嵌入 RWMutex（私有，组合但不暴露方法）
}

func (b *SafeBool) Set(value bool) {
    b.mu.Lock()         // 使用嵌入的 RWMutex
    defer b.mu.Unlock()
    b.flag = value
}
```

---

> **相关文档**：
> - 上一章：[函数](04-functions.md)
> - 下一章：[接口](06-interfaces.md)
