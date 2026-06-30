# 基础概念：包与模块

## 模块（Module）

Go 的模块是依赖管理的基本单位，通过 `go.mod` 文件定义。

**项目实例** — `go.mod`：

```go
module github.com/abhinavxd/libredesk  // 模块路径，也是代码的导入前缀

go 1.25.0  // Go 版本

require (
    github.com/valyala/fasthttp v1.62.0     // 直接依赖
    github.com/jmoiron/sqlx v1.4.0
    github.com/redis/go-redis/v9 v9.5.5
    // ...
)
```

**关键理解**：
- `module` 声明了这个项目的全局唯一路径，其他项目引用时用这个路径
- `require` 列出所有依赖及其版本
- Go 使用**语义化版本**（Semantic Versioning）管理依赖

## 包（Package）

Go 的每个目录就是一个包，同一个目录下的所有 `.go` 文件必须属于同一个包。

**项目实例** — 包的组织：

```
cmd/                          → package main（可执行程序入口）
internal/conversation/        → package conversation（业务逻辑）
internal/conversation/models/ → package models（数据模型）
internal/ws/                  → package ws（WebSocket 逻辑）
internal/authz/               → package authz（权限控制）
```

**项目中的包导入** — `cmd/main.go`：

```go
package main  // 可执行程序必须是 main 包

import (
    "context"       // 标准库
    "fmt"           // 标准库
    "sync"          // 标准库
    "time"          // 标准库

    // 项目内部包（用模块路径前缀）
    "github.com/abhinavxd/libredesk/internal/conversation"
    "github.com/abhinavxd/libredesk/internal/ws"

    // 第三方包
    "github.com/valyala/fasthttp"
    "github.com/zerodha/fastglue"
)
```

**包的别名**：当包名冲突或路径太长时，可用别名：

```go
import (
    auth_ "github.com/abhinavxd/libredesk/internal/auth"     // auth_ 避免与关键字冲突
    umodels "github.com/abhinavxd/libredesk/internal/user/models"  // 缩短路径
    activitylog "github.com/abhinavxd/libredesk/internal/activity_log"  // 重命名
)
```

## 可见性规则

- 大写字母开头 = 导出（public），其他包可访问
- 小写字母开头 = 未导出（private），仅包内可访问

```go
// internal/ws/ws.go
type Hub struct {
    lo            *logf.Logger     // 小写：包外不可访问
    clients       map[int][]*Client // 小写：包外不可访问
    clientsMutex  sync.RWMutex     // 小写：包外不可访问
}

func (h *Hub) BroadcastMessage(msg models.BroadcastMessage) {  // 大写：可导出
    // ...
}

func (h *Hub) kickIdleClients() {  // 小写：不可导出，仅包内使用
    // ...
}
```

---

> **相关文档**：
> - 上一章：[概述与项目全景](01-overview.md)
> - 下一章：[变量、常量与类型](03-variables-types.md)
