# 主流技术：缓存与 Redis

## Redis 客户端

**项目实例** — 使用 `go-redis`：

```go
import "github.com/redis/go-redis/v9"

func initRedis() *redis.Client {
    rdb := redis.NewClient(&redis.Options{
        Addr:     ko.String("redis.address"),
        Password: ko.String("redis.password"),
        DB:       ko.Int("redis.db"),
    })
    return rdb
}
```

## Redis 限流

**项目实例** — `internal/ratelimit/ratelimit.go`（基于 Redis 的滑动窗口限流）：

```go
func (l *Limiter) Check(ctx *fasthttp.RequestCtx, ruleName string) error {
    rule, ok := l.rules[ruleName]
    if !ok || !rule.Enabled {
        return nil    // 规则不存在或未启用，直接放行
    }

    clientIP := realip.FromRequest(ctx)
    key := fmt.Sprintf("rate_limit:%s:%s", ruleName, clientIP)

    // Redis Pipeline：一次性执行多个命令
    pipe := l.redis.Pipeline()
    pipe.ZRemRangeByScore(ctx, key, "-inf", windowStart)  // 清理过期记录
    pipe.ZAdd(ctx, key, redis.Z{Score: float64(nowUnix), Member: nowNano})  // 添加当前请求
    countCmd := pipe.ZCard(ctx, key)                       // 统计窗口内请求数
    pipe.Expire(ctx, key, time.Minute*2)                   // 设置过期时间

    _, err := pipe.Exec(ctx)  // 执行 pipeline
    // ...
}
```

---

> **相关文档**：
> - 上一章：[日志](05-logging.md)
> - 下一章：[WebSocket 实时通信](07-websocket.md)
