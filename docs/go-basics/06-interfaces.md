# 基础概念：接口 — Go 的多态核心

Go 的接口是**隐式实现**的：只要一个类型实现了接口要求的所有方法，它就自动满足该接口，无需声明 `implements`。

## 接口定义

**项目实例** — `internal/ws/ws.go` 中的接口：

```go
// userStore 接口定义了 WebSocket Hub 需要的用户操作
type userStore interface {
    UpdateLastActive(userID int) (bool, error)
}

// conversationStore 接口定义了 Hub 需要的会话操作
type conversationStore interface {
    BroadcastTypingToWidgetClientsOnly(conversationUUID string, isTyping bool)
    FilterAuthorizedListUUIDs(agentID int, uuids []string) ([]string, error)
}
```

## 接口的依赖注入

接口在 Go 中最重要的用途是**解耦**和**依赖注入**：

**项目实例** — `internal/conversation/conversation.go`：

Conversation Manager 不直接依赖具体的 User、Team、Inbox 实现，而是依赖接口：

```go
type Manager struct {
    inboxStore    inboxStore      // 接口，不是具体类型
    userStore     userStore       // 接口
    teamStore     teamStore       // 接口
    mediaStore    mediaStore      // 接口
    settingsStore settingsStore   // 接口
    csatStore     csatStore       // 接口
    webhookStore  webhookStore    // 接口
    // ...
}

// 这些接口的定义
type inboxStore interface {
    Get(int) (inbox.Inbox, error)
    GetDBRecord(any) (imodels.Inbox, error)
    GetAll() ([]imodels.Inbox, error)
}

type userStore interface {
    Get(int, string, []string) (umodels.User, error)
    GetAgent(int, string) (umodels.User, error)
    GetAgentCachedOrLoad(int) (umodels.User, error)
    // ...
}
```

**好处**：
1. **可测试**：测试时可用 mock 替换真实实现
2. **松耦合**：Conversation 不需要知道 User 的内部实现
3. **可替换**：换一个 User 实现不影响 Conversation 代码

## 接口类型断言

当需要从接口值中获取具体类型信息时，使用类型断言：

**项目实例** — `cmd/middlewares.go`：

```go
func auth(handler fastglue.FastRequestHandler) fastglue.FastRequestHandler {
    return func(r *fastglue.Request) error {
        user, err := authenticateUser(r, app)
        if err != nil {
            // 类型断言：检查 error 是否是 envelope.Error 类型
            if envErr, ok := err.(envelope.Error); ok {
                if envErr.ErrorType == envelope.PermissionError {
                    return r.SendErrorEnvelope(http.StatusForbidden, envErr.Message, nil, envelope.PermissionError)
                }
                return r.SendErrorEnvelope(http.StatusUnauthorized, envErr.Message, nil, envelope.GeneralError)
            }
            return sendErrorEnvelope(r, err)
        }
        // ...
    }
}
```

---

> **相关文档**：
> - 上一章：[结构体与方法](05-structs-methods.md)
> - 下一章：[错误处理](07-error-handling.md)
