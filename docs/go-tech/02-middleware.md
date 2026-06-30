# 主流技术：中间件模式

中间件是 Web 开发中的核心模式，用于在请求到达 handler 前插入通用逻辑（认证、限流、日志等）。

## 中间件的本质

中间件就是一个**高阶函数**：接收一个 handler，返回一个包装后的 handler。

**项目实例** — `cmd/middlewares.go`：

```go
// auth 中间件：验证用户身份
func auth(handler fastglue.FastRequestHandler) fastglue.FastRequestHandler {
    return func(r *fastglue.Request) error {
        app := r.Context.(*App)
        
        // 前置逻辑：认证用户
        user, err := authenticateUser(r, app)
        if err != nil {
            return sendErrorEnvelope(r, err)    // 认证失败，直接返回
        }
        
        // 将用户信息注入到请求上下文
        r.RequestCtx.SetUserValue("user", amodels.User{
            ID: user.ID, Email: user.Email.String,
        })
        
        // 调用下一个 handler
        return handler(r)
    }
}

// perm 中间件：检查权限
func perm(handler fastglue.FastRequestHandler, perm string) fastglue.FastRequestHandler {
    return func(r *fastglue.Request) error {
        app := r.Context.(*App)
        
        // 先认证
        user, err := authenticateUser(r, app)
        if err != nil {
            return sendErrorEnvelope(r, err)
        }
        
        // 再鉴权
        parts := strings.Split(perm, ":")
        ok, err := app.authz.Enforce(user, parts[0], parts[1])
        if !ok {
            return r.SendErrorEnvelope(http.StatusForbidden, "denied", nil, envelope.PermissionError)
        }
        
        r.RequestCtx.SetUserValue("user", ...)
        return handler(r)
    }
}

// rateLimit 中间件：限流
func rateLimit(handler fastglue.FastRequestHandler, ruleName string) fastglue.FastRequestHandler {
    return func(r *fastglue.Request) error {
        app := r.Context.(*App)
        if err := app.rateLimit.Check(r.RequestCtx, ruleName); err != nil {
            return err     // 被限流，直接返回错误
        }
        return handler(r)  // 通过限流，继续处理
    }
}
```

## 中间件链（洋葱模型）

中间件可以层层嵌套，形成链式调用：

```go
// 路由注册时组合多个中间件
g.POST("/api/v1/agents/reset-password", rateLimit(tryAuth(handleResetPassword), "auth"))
//                                    ↑ 限流    ↑ 可选认证   ↑ 业务处理
```

调用顺序：rateLimit → tryAuth → handleResetPassword

---

> **相关文档**：
> - 上一章：[HTTP 框架与路由](01-http-routing.md)
> - 下一章：[数据库访问层](03-database.md)
