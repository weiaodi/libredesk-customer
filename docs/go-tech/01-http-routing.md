# 主流技术：HTTP 框架与路由

## fasthttp + fastglue

LibreDesk 使用 `fasthttp`（高性能 HTTP 引擎，比标准库 `net/http` 快约 10 倍）+ `fastglue`（路由框架）：

**项目实例** — `cmd/main.go` + `cmd/handlers.go`：

```go
// 创建路由引擎
g := fastglue.NewGlue()
g.SetContext(app)   // 将全局 App 上下文注入

// 注册路由
g.GET("/api/v1/conversations", perm(handleGetConversations, "conversations:read_all"))
g.POST("/api/v1/conversations", perm(handleCreateConversation, "conversations:write"))
g.PUT("/api/v1/conversations/{uuid}/status", perm(handleUpdateConversationStatus, "conversations:update_status"))
g.DELETE("/api/v1/conversations/{uuid}", perm(handleDeleteConversation, "conversations:delete"))

// WebSocket 路由
g.GET("/ws", auth(func(r *fastglue.Request) error {
    return handleWS(r, hub)
}))

// 配置 HTTP 服务器
s := &fasthttp.Server{
    Name:                 "libredesk",
    ReadTimeout:          ko.MustDuration("app.server.read_timeout"),
    WriteTimeout:         ko.MustDuration("app.server.write_timeout"),
    MaxRequestBodySize:   ko.MustInt("app.server.max_body_size"),
    MaxKeepaliveDuration: ko.MustDuration("app.server.keepalive_timeout"),
}

// 启动服务器
g.ListenAndServe(ko.String("app.server.address"), ko.String("app.server.socket"), s)
```

## Handler 函数签名

fastglue 的 handler 统一签名为 `func(*fastglue.Request) error`：

```go
func handleGetConversations(r *fastglue.Request) error {
    app := r.Context.(*App)               // 获取全局上下文
    page, pageSize := getPagination(r)     // 解析分页参数
    // 业务逻辑...
    return r.SendEnvelope(data)            // 返回 JSON 响应
}
```

## Go 标准库 net/http vs fasthttp

| 对比项 | net/http | fasthttp |
|-------|----------|----------|
| 性能 | 标准性能 | 约 10x 更快 |
| 内存分配 | 较多 | 极少（对象复用） |
| 兼容性 | 生态最广 | 部分库不兼容 |
| 适用场景 | 通用 | 高性能/高并发 |

---

> **相关文档**：
> - 上一章节：[embed 嵌入资源](../go-basics/09-embed.md)
> - 下一章：[中间件模式](02-middleware.md)
