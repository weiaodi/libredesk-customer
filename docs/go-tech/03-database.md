# 主流技术：数据库访问层

## sqlx — SQL 的好搭档

LibreDesk 使用 `sqlx`（在标准库 `database/sql` 基础上扩展），而非 ORM：

```go
import "github.com/jmoiron/sqlx"
```

**为什么不用 GORM 等 ORM？**
- Go 社区更偏好 "写 SQL" 而非 "用 ORM 生成 SQL"
- sqlx 提供了结构体映射但不隐藏 SQL 细节
- 复杂查询更容易编写和优化

## SQL 与代码分离（goyesql）

LibreDesk 使用 `goyesql` 将 SQL 语句写在独立的 `.sql` 文件中，通过标签与 Go 变量关联：

**项目实例** — `internal/conversation/queries.sql`：

```sql
-- name: get-conversation
SELECT * FROM conversations WHERE uuid = $1;

-- name: get-conversation-uuid
SELECT uuid FROM conversations WHERE id = $1;

-- name: update-conversation-status
UPDATE conversations SET status_id = $1 WHERE id = $2;
```

**项目实例** — `internal/conversation/conversation.go` 中加载 SQL：

```go
// 嵌入 SQL 文件
//go:embed queries.sql
efs embed.FS

// 定义查询结构体，标签对应 SQL 文件中的 -- name: xxx
type queries struct {
    GetConversationUUID              *sqlx.Stmt `query:"get-conversation-uuid"`
    GetConversation                  *sqlx.Stmt `query:"get-conversation"`
    UpdateConversationStatus         *sqlx.Stmt `query:"update-conversation-status"`
    UpdateConversationAssignedUser   *sqlx.Stmt `query:"update-conversation-assigned-user"`
    GetConversations                 string     `query:"get-conversations"`  // string 表示动态 SQL
    // ...
}

// 加载 SQL
var q queries
if err := dbutil.ScanSQLFile("queries.sql", &q, opts.DB, efs); err != nil {
    return nil, err
}
```

## 数据库初始化

**项目实例** — `cmd/init.go`：

```go
import _ "github.com/lib/pq"  // 空导入：注册 PostgreSQL 驱动

func initDB() *sqlx.DB {
    db, err := sqlx.Connect("postgres", fmt.Sprintf(
        "host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
        ko.String("db.host"),
        ko.Int("db.port"),
        ko.String("db.user"),
        ko.String("db.password"),
        ko.String("db.database"),
        ko.String("db.ssl_mode"),
    ))
    if err != nil {
        log.Fatalf("error connecting to DB: %v", err)
    }

    db.SetMaxOpenConns(ko.Int("db.max_open"))
    db.SetMaxIdleConns(ko.Int("db.max_idle"))
    db.SetConnMaxLifetime(ko.MustDuration("db.max_lifetime"))

    return db
}
```

**空导入（_ import）**：`_ "github.com/lib/pq"` 只执行包的 `init()` 函数（注册数据库驱动），不使用包的其他导出内容。

---

> **相关文档**：
> - 上一章：[中间件模式](02-middleware.md)
> - 下一章：[配置管理](04-config.md)
