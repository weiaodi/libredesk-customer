# 基础概念：变量、常量与类型

## 变量声明

Go 有多种变量声明方式：

**项目实例** — `cmd/main.go`：

```go
// 方式1：var 块声明（包级别变量）
var (
    ko          = koanf.New(".")    // 短变量声明初始化
    ctx         = context.Background()
    appName     = "libredesk"       // 字符串字面量
    frontendDir = "frontend/dist/main"
    buildString string              // 零值声明（string 零值为 ""）
    versionString string
)

// 方式2：const 块声明（编译期常量）
const (
    sampleEncKey = "your-32-char-random-string-here!"
)

// 方式3：函数内短变量声明（最常用）
func main() {
    db := initDB()                    // 推荐写法，:= 自动推断类型
    fs := initFS(getCustomStaticDir()) 
    var app = &App{...}              // 显式类型（结构体指针）
}
```

## 基本类型

```go
// 内置基本类型
int         // 整数（根据平台 32 或 64 位）
string      // 字符串（UTF-8）
bool        // 布尔值
time.Time   // 时间（标准库类型）
error       // 错误接口

// 项目中使用到的特殊类型
null.String  // 可空字符串（数据库字段可能为 NULL）
null.Int     // 可空整数
null.Time    // 可空时间
json.RawMessage // 原始 JSON 数据（延迟解析）
```

## 结构体标签（Struct Tag）

Go 的结构体标签是实现 ORM 映射和 JSON 序列化的核心机制：

**项目实例** — `internal/conversation/models/models.go`：

```go
type Conversation struct {
    ID        int       `db:"id" json:"id"`           // 数据库列名 + JSON 字段名
    CreatedAt time.Time `db:"created_at" json:"created_at"`
    UUID      string    `db:"uuid" json:"uuid"`
    Status    null.String `db:"status" json:"status"`  // 可空字段
    Meta      json.RawMessage `db:"meta" json:"meta"` // 原始 JSON
    Tags      null.JSON `db:"tags" json:"tags"`      // JSON 数组

    PreviousConversations []PreviousConversation `db:"-" json:"previous_conversations"`
    //                       db:"-" 表示不映射数据库列 ↑
}
```

**标签解读**：
- `db:"column_name"` → sqlx 库用这个标签将查询结果映射到结构体字段
- `json:"field_name"` → encoding/json 用这个标签控制 JSON 序列化
- `db:"-"` → 忽略数据库映射（该字段不从数据库读取）

---

> **相关文档**：
> - 上一章：[包与模块](02-packages-modules.md)
> - 下一章：[函数](04-functions.md)
