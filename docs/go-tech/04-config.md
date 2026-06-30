# 主流技术：配置管理

## koanf 配置框架

LibreDesk 使用 `koanf` 管理配置，支持 TOML 文件、环境变量、命令行参数等多源合并：

**项目实例** — `cmd/init.go`：

```go
var ko = koanf.New(".")  // "." 作为键分隔符

// 加载 TOML 配置文件
func initConfig(ko *koanf.Koanf) {
    for _, f := range ko.Strings("config") {
        if err := ko.Load(file.Provider(f), toml.Parser()); err != nil {
            log.Fatalf("error loading config: %v.", err)
        }
    }
    
    // 加载环境变量（前缀 LIBREDESK_）
    ko.Load(env.Provider(".", env.Opt{
        Prefix: "LIBREDESK_",
        TransformFunc: func(key, val string) (string, any) {
            key = strings.ReplaceAll(strings.ToLower(strings.TrimPrefix(key, "LIBREDESK_")), "__", ".")
            return key, val
        },
    }), nil)
}

// 读取配置值
ko.MustString("app.encryption_key")     // 必须存在，否则 panic
ko.String("app.root_url")               // 可选，不存在返回 ""
ko.MustDuration("app.server.read_timeout")  // 解析为 time.Duration
ko.Bool("install")                      // 解析为布尔值
ko.Int("db.port")                       // 解析为整数
```

## TOML 配置文件

**项目实例** — `config.sample.toml`：

```toml
[app]
log_level = "debug"
env = "dev"
encryption_key = "your-32-char-random-string-here!"

[app.server]
address = "0.0.0.0:9000"
read_timeout = "5s"
write_timeout = "5s"

[db]
host = "db"
port = 5432
user = "libredesk"
password = "libredesk"

[redis]
address = "redis:6379"
```

## 命令行参数

**项目实例** — `cmd/init.go`：

```go
import flag "github.com/spf13/pflag"

func initFlags() {
    f := flag.NewFlagSet("config", flag.ContinueOnError)
    f.StringSlice("config", []string{"config.toml"}, "config file path")
    f.Bool("version", false, "show version")
    f.Bool("install", false, "setup database")
    f.Bool("upgrade", false, "upgrade database schema")
    f.Parse(os.Args[1:])

    // 将命令行参数合并到 koanf
    ko.Load(posflag.Provider(f, ".", ko), nil)
}
```

**配置优先级**（从低到高）：
1. 代码中的默认值
2. TOML 配置文件
3. 环境变量（`LIBREDESK_` 前缀）
4. 命令行参数

---

> **相关文档**：
> - 上一章：[数据库访问层](03-database.md)
> - 下一章：[日志](05-logging.md)
