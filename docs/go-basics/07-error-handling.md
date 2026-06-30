# 基础概念：错误处理

Go 没有 try/catch，错误通过**返回值**传递。这是 Go 最独特的设计之一。

## error 接口

Go 的 error 只是一个接口：

```go
type error interface {
    Error() string
}
```

**项目实例** — `internal/envelope/envelope.go` 自定义错误类型：

```go
// Error 实现了 error 接口
type Error struct {
    Code      int         // HTTP 状态码
    ErrorType string      // 错误类型
    Message   string      // 错误消息
    Data      interface{} // 附加数据
}

// Error() 方法满足 error 接口
func (e Error) Error() string {
    return e.Message
}

// 工厂函数创建特定类型的错误
func NewError(etype string, message string, data interface{}) error {
    err := Error{
        Message:   message,
        ErrorType: etype,
        Data:      data,
    }
    switch etype {
    case GeneralError:
        err.Code = fasthttp.StatusInternalServerError
    case PermissionError:
        err.Code = fasthttp.StatusForbidden
    case InputError:
        err.Code = fasthttp.StatusBadRequest
    // ...
    }
    return err
}
```

## 错误处理惯用法

**项目实例** — 典型的 Go 错误处理模式：

```go
// 模式1：if err != nil { return }
func initSettings(db *sqlx.DB) *setting.Manager {
    s, err := setting.New(setting.Opts{
        DB:            db,
        Lo:            initLogger("settings"),
        EncryptionKey: ko.MustString("app.encryption_key"),
    })
    if err != nil {
        log.Fatalf("error initializing setting manager: %v", err)  // 启动阶段直接 fatal
    }
    return s
}

// 模式2：错误包装（添加上下文）
// 使用 fmt.Errorf("context: %w", err) 包装错误
func (e *Enforcer) EnforceMediaAccess(user umodels.User, model string) (bool, error) {
    if model != "messages" {
        return true, nil
    }
    if !slices.Contains(user.Permissions, "messages:read") {
        return false, envelope.NewError(envelope.UnauthorizedError, e.i18n.T("status.deniedPermission"), nil)
    }
    return true, nil
}

// 模式3：启动阶段 vs 运行阶段的错误处理
// 启动阶段：log.Fatalf() 直接退出（因为无法恢复）
// 运行阶段：返回错误给上层处理（HTTP handler 返回错误响应）
```

## 错误 vs panic

- **error**：正常业务逻辑中的可预期错误（文件不存在、权限不足、网络超时）
- **panic**：不可恢复的编程错误（空指针、数组越界），类似其他语言的异常
- **项目中只使用 error**，不使用 panic 做业务错误处理

---

> **相关文档**：
> - 上一章：[接口](06-interfaces.md)
> - 下一章：[并发编程](08-concurrency.md)
