# 安全防护与配置管理架构

> 本文档讲解 LibreDesk 中的限流策略、安全纵深防御和配置管理架构。

---

## 1. 限流与安全防护架构

### 1.1 限流架构

LibreDesk 实现了多层次的限流：

| 层级 | 实现方式 | 作用 |
|------|---------|------|
| 全局限流 | Redis 滑动窗口 | 按 IP + 规则名限流 |
| 业务限流 | 数据库 SQL | 限制同一联系人创建会话频率 |
| WS 限流 | Channel 缓冲区大小 | 限制消息推送速率 |

**Redis 滑动窗口限流**（`internal/ratelimit/ratelimit.go`）：

```go
type Rule struct {
    Name              string
    Enabled           bool
    RequestsPerMinute int
}

type Limiter struct {
    redis *redis.Client
    rules map[string]Rule
}

// 使用 Redis Sorted Set 实现滑动窗口
func (l *Limiter) Check(ctx *fasthttp.RequestCtx, ruleName string) error {
    // 1. 清理窗口外的记录
    pipe.ZRemRangeByScore(ctx, key, "-inf", windowStart)
    // 2. 添加当前请求
    pipe.ZAdd(ctx, key, redis.Z{Score: float64(nowUnix), Member: nowNano})
    // 3. 统计窗口内请求数
    countCmd := pipe.ZCard(ctx, key)
    // 4. 设置过期
    pipe.Expire(ctx, key, time.Minute*2)

    if countCmd.Val() > int64(rule.RequestsPerMinute) {
        return envelope.NewError(envelope.RateLimitError, "too many requests", nil)
    }
    return nil
}
```

### 1.2 SSRF 防护

Webhook 外发请求使用 `ssrfguard` 防止 SSRF 攻击：

```go
// internal/webhook/webhook.go
guard := ssrfguard.New(allowed...)

httpClient := &http.Client{
    Transport: &http.Transport{
        DialContext: (&net.Dialer{
            Control: guard.Control,  // 在 Dial 阶段检查目标 IP
        }).DialContext,
    },
}
```

### 1.3 CSRF 防护

双重提交 Cookie 模式：

```go
// Cookie 中的 csrf_token 必须等于 Header 中的 X-CSRFTOKEN
cookieToken := r.RequestCtx.Request.Header.Cookie("csrf_token")
hdrToken := r.RequestCtx.Request.Header.Peek("X-CSRFTOKEN")
if cookieToken == "" || hdrToken == "" || cookieToken != hdrToken {
    return envelope.NewError(envelope.PermissionError, "CSRF token mismatch", nil)
}
```

### 1.4 加密密钥管理

敏感数据（OAuth Secret、SMTP 密码等）使用 AES 加密后存入数据库：

```go
// internal/webhook/webhook.go
encryptedSecret, err := m.encryptSecret(webhook.Secret)  // 入库前加密
decryptedSecret, err := m.decryptWebhook(&webhook)        // 读取后解密
```

### 1.5 安全纵深防御总览

```
┌──────────────────────────────────────────────────┐
│ 第1层：限流 (Rate Limit)                          │
│   防止暴力攻击、DDoS                              │
├──────────────────────────────────────────────────┤
│ 第2层：认证 (Authentication)                      │
│   API Key / Session / OIDC                        │
├──────────────────────────────────────────────────┤
│ 第3层：授权 (Authorization)                       │
│   RBAC: object:action 权限检查                    │
├──────────────────────────────────────────────────┤
│ 第4层：CSRF 防护                                  │
│   双重提交 Cookie 模式                            │
├──────────────────────────────────────────────────┤
│ 第5层：SSRF 防护                                  │
│   ssrfguard 检查外发请求目标                       │
├──────────────────────────────────────────────────┤
│ 第6层：数据加密                                   │
│   AES 加密敏感字段 (OAuth Secret 等)              │
├──────────────────────────────────────────────────┤
│ 第7层：输入校验                                   │
│   参数校验 + SQL 参数化 + 结构体标签               │
└──────────────────────────────────────────────────┘
```

---

## 2. 配置管理架构

### 2.1 多源配置合并

```
┌─────────────────────────────────────────┐
│              Koanf 实例                   │
│                                          │
│  合并顺序（后者覆盖前者）：               │
│  1. 代码默认值                            │
│  2. config.toml 文件                      │
│  3. LIBREDESK_ 环境变量                    │
│  4. --config 命令行参数                    │
│  5. 数据库 settings 表（运行时）           │
└─────────────────────────────────────────┘
```

### 2.2 静态配置 vs 动态配置

| 类型 | 来源 | 修改方式 | 示例 |
|------|------|---------|------|
| 静态配置 | config.toml | 修改文件 + 重启 | `db.host`, `app.encryption_key` |
| 动态配置 | 数据库 settings 表 | API 修改 + 即时生效 | `app.site_name`, `app.logo_url` |

**动态配置加载流程**（`cmd/init.go`）：

```go
// 启动时从 DB 加载配置
func loadSettings(m *setting.Manager) {
    j, err := m.GetAllJSON()            // 从数据库查询所有 settings
    var out map[string]interface{}
    json.Unmarshal(j, &out)             // 反序列化
    ko.Load(confmap.Provider(out, "."), nil)  // 合并到 koanf
}
```

### 2.3 敏感配置保护

```toml
# config.toml 中的敏感字段
[app]
encryption_key = "openssl rand -hex 16 生成的 32 字符密钥"

# config.toml 在 .gitignore 中，不提交到版本控制
```

---

> **相关文档**：
> - 上一篇：[实时通信与多渠道架构](03-realtime-channels.md)
> - 下一篇：[数据访问、缓存与生命周期管理](05-data-cache-lifecycle.md)
