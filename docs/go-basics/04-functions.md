# 基础概念：函数

## 函数基础

Go 函数可以返回多个值，这是 Go 的核心特性之一：

```go
// 标准多返回值模式：结果 + 错误
func (e *Enforcer) Enforce(user umodels.User, obj, act string) (bool, error) {
    return slices.Contains(user.Permissions, obj+":"+act), nil
}
```

## 函数是值类型

在 Go 中，函数是一等公民，可以赋值给变量、作为参数传递：

**项目实例** — `cmd/main.go` 中的回调函数模式：

```go
// onUsersOffline 返回一个函数（闭包）
func onUsersOffline(conv *conversation.Manager) func([]umodels.OfflineUser) {
    return func(users []umodels.OfflineUser) {   // 返回一个匿名函数
        for _, u := range users {
            switch u.Type {
            case umodels.UserTypeAgent:
                conv.BroadcastAgentAvailability(u.ID, umodels.Offline)
            case umodels.UserTypeContact, umodels.UserTypeVisitor:
                conv.BroadcastContactUpdate(u.ID, map[string]any{"availability_status": umodels.Offline})
            }
        }
    }
}

// 使用时
go user.MonitorUserAvailability(ctx, onUsersOffline(conversation))
```

## 可变参数与选项模式

**项目实例** — 初始化函数使用 Opts 结构体替代可变参数：

```go
// Opts 模式（Go 中的 "选项模式"）
type Opts struct {
    DB                       *sqlx.DB
    Lo                       *logf.Logger
    OutgoingMessageQueueSize int
    IncomingMessageQueueSize int
    ContinuityConfig         *ContinuityConfig
    SubjectRefFormat         string
}

func New(wsHub *ws.Hub, i18n *i18n.I18n, ..., opts Opts) (*Manager, error) {
    // 使用 opts 中的值初始化
    c := &Manager{
        incomingMessageQueue: make(chan models.IncomingMessage, opts.IncomingMessageQueueSize),
        outgoingMessageQueue: make(chan models.Message, opts.OutgoingMessageQueueSize),
        // ...
    }
    return c, nil
}
```

这种 Opts 结构体模式在 Go 中非常普遍，比可变参数更清晰、更易扩展。

---

> **相关文档**：
> - 上一章：[变量、常量与类型](03-variables-types.md)
> - 下一章：[结构体与方法](05-structs-methods.md)
