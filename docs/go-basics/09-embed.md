# 基础概念：embed 嵌入资源

Go 1.16 引入了 `//go:embed` 指令，可以在编译时将文件嵌入到二进制中。

**项目实例** — 多处使用 embed：

```go
// internal/conversation/conversation.go
var (
    //go:embed queries.sql
    efs embed.FS    // 将 queries.sql 文件嵌入到二进制
)

// internal/user/user.go
var (
    //go:embed queries.sql
    efs embed.FS
)
```

这意味着 SQL 查询文件在编译时就打包进了二进制，部署时不需要携带额外的 SQL 文件。

**注意**：`//go:embed` 是编译器指令，不是注释，`//` 和 `go:embed` 之间不能有空格。

---

> **相关文档**：
> - 上一章：[并发编程](08-concurrency.md)
> - 下一章节：[HTTP 框架与路由](../go-tech/01-http-routing.md)
