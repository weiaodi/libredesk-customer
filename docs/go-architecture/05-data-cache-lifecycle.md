# 数据访问、缓存与生命周期管理

> 本文档讲解 LibreDesk 中的数据访问层设计、缓存策略和优雅关闭机制。

---

## 1. 数据访问层架构

### 1.1 SQL 与代码分离

LibreDesk 采用 **goyesql + embed** 方案，将 SQL 写在独立 `.sql` 文件中：

```
internal/conversation/
├── conversation.go     → queries 结构体定义 + 业务逻辑
├── queries.sql         → SQL 语句（独立文件）
└── models/
    └── models.go       → 数据模型（结构体定义）
```

**queries.sql 格式**：

```sql
-- name: get-conversation
SELECT * FROM conversations WHERE uuid = $1;

-- name: update-conversation-status
UPDATE conversations SET status_id = $1 WHERE id = $2;

-- name: get-conversations
-- 动态 SQL（不预编译为 *sqlx.Stmt，因为需要拼接 WHERE 子句）
SELECT * FROM conversations WHERE ...
```

**Go 侧结构体**：

```go
type queries struct {
    GetConversation         *sqlx.Stmt `query:"get-conversation"`     // 预编译语句
    UpdateConversationStatus *sqlx.Stmt `query:"update-conversation-status"`
    GetConversations         string     `query:"get-conversations"`    // 动态 SQL 字符串
}
```

### 1.2 预编译 vs 动态 SQL 的选择

| 方式 | 性能 | 安全 | 灵活 | 使用场景 |
|------|------|------|------|---------|
| `*sqlx.Stmt`（预编译） | 高（一次编译多次执行） | 防 SQL 注入 | 低（参数固定） | 单表 CRUD、固定条件查询 |
| `string`（动态 SQL） | 中（每次解析） | 需手动防注入 | 高（可拼接条件） | 列表查询（动态筛选/排序/分页） |

### 1.3 为什么不用 ORM？

| 对比项 | sqlx（项目选用） | GORM | Ent |
|-------|----------------|------|-----|
| SQL 可控性 | 完全可控 | 框架生成 SQL | 框架生成 SQL |
| 复杂查询 | 直接写 SQL | 需要.Raw() 或链式调用 | 图查询 API |
| 性能调优 | 精确控制每条 SQL | 黑盒较多 | 中等 |
| 学习曲线 | 低（会 SQL 即可） | 中 | 高 |
| Go 社区偏好 | **主流** | 较流行 | 小众 |

**LibreDesk 选择 sqlx 的考量**：
- 查询条件复杂（动态过滤、多表 JOIN、窗口函数）
- 需要精确控制 SQL 性能（客户支持系统是高查询频次场景）
- Go 团队普遍更偏好"显式优于隐式"（Explicit is better than implicit）

### 1.4 数据库版本管理

使用迁移文件（`internal/migrations/`）管理 Schema 变更：

```
internal/migrations/
├── v0.3.0.go    → 早期版本迁移
├── v0.4.0.go
├── v0.5.0.go
├── ...
├── v2.0.0.go    → 大版本迁移
└── v2.4.0.go    → 最新迁移
```

启动时通过 `--upgrade` 标志执行待运行的迁移。

---

## 2. 缓存策略架构

### 2.1 进程内缓存

**Agent 信息缓存**（`internal/user/user.go`）：

```go
type Manager struct {
    agentCache   map[int]cachedAgent      // 进程内 LRU 缓存
    agentCacheMu sync.RWMutex             // 读写锁保护
}

type cachedAgent struct {
    user      models.User
    expiresAt time.Time                   // 10 分钟过期
}

func (m *Manager) GetAgentCachedOrLoad(id int) (models.User, error) {
    // 1. 先查缓存
    m.agentCacheMu.RLock()
    if cached, ok := m.agentCache[id]; ok && time.Now().Before(cached.expiresAt) {
        m.agentCacheMu.RUnlock()
        return cached.user, nil
    }
    m.agentCacheMu.RUnlock()

    // 2. 缓存未命中，查数据库
    user, err := m.q.GetAgent.Get(id, "")
    // 3. 写入缓存
    m.agentCacheMu.Lock()
    m.agentCache[id] = cachedAgent{user: user, expiresAt: time.Now().Add(agentCacheTTL)}
    m.agentCacheMu.Unlock()
    return user, nil
}
```

### 2.2 Redis 缓存

| 用途 | Key 格式 | TTL |
|------|---------|-----|
| 限流计数器 | `rate_limit:{rule}:{ip}` | 2 分钟 |
| Session 存储 | Redis Hash | 9 小时 |
| 用户在线状态 | — | 实时更新 |

### 2.3 缓存策略对比

| 策略 | 优点 | 缺点 | 项目使用 |
|------|------|------|---------|
| 进程内 Map | 极快、零网络延迟 | 不跨进程、需手动管理 | Agent 缓存 |
| sync.Map | 并发安全 | 不适合写多场景 | outgoingProcessingMessages |
| atomic.Value | 无锁读取 | 一次写入多次读取 | App.consts |
| Redis | 跨进程、持久化 | 网络延迟 | Session、限流 |

---

## 3. 优雅关闭与生命周期管理

### 3.1 关闭流程

```
SIGINT/SIGTERM 信号
  │
  ▼
Context 被取消
  │
  ├── HTTP Server.Shutdown()       停止接收新请求
  ├── Inbox.Close()                 停止收件箱接收
  ├── Automation.Close()            关闭 taskQueue → 等待 worker 处理完
  ├── AutoAssigner.Close()          停止定时器
  ├── Notifier.Close()              等待通知发送完
  ├── Webhook.Close()               关闭 deliveryQueue → 等待投递完
  ├── Conversation.Close()          关闭消息队列 → 等待消息处理完
  ├── SLA.Close()                   停止 SLA 评估
  ├── DB.Close()                    关闭数据库连接池
  └── Redis.Close()                 关闭 Redis 连接
```

### 3.2 统一的 Close 模式

每个后台服务遵循相同的关闭模式：

```go
func (e *Engine) Close() {
    e.closedMu.Lock()
    defer e.closedMu.Unlock()
    if e.closed { return }       // 防止重复关闭
    e.closed = true
    close(e.taskQueue)           // 关闭 channel
    e.wg.Wait()                  // 等待所有 worker 完成
}
```

**关键考量**：
1. `close(channel)` 后 worker 会从 `select` 中收到 `ok=false`，自然退出
2. `wg.Wait()` 确保正在处理的任务完成后再退出
3. `closedMu` 防止并发调用 Close 导致 panic（重复 close channel）

---

## 4. 项目架构全景图

```
┌─────────────────────────────────────────────────────────────────┐
│                         客户端                                    │
│  ┌───────────┐  ┌──────────────┐  ┌──────────────────┐          │
│  │ 管理后台    │  │ Widget(聊天) │  │ 外部系统(Webhook)│          │
│  └─────┬──────┘  └──────┬───────┘  └────────┬─────────┘          │
└────────┼────────────────┼───────────────────┼────────────────────┘
         │ HTTP/WS        │ HTTP/WS           │ HTTP POST
         ▼                ▼                   ▼
┌─────────────────────────────────────────────────────────────────┐
│                     fasthttp + fastglue                          │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ 中间件链                                                     ││
│  │ rateLimit → auth/perm → widgetAuth → authOrSignedURL         ││
│  └─────────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Handler 层 (cmd/)                                           ││
│  │ handleLogin / handleGetConversations / handleSendMessage /   ││
│  │ handleWS / handleChatInit / ...                              ││
│  └─────────────────────────┬───────────────────────────────────┘│
└────────────────────────────┼────────────────────────────────────┘
                             │ 调用
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                  业务逻辑层 (internal/)                           │
│                                                                  │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────────┐ │
│  │  Conversation     │  │  Automation       │  │  AutoAssigner  │ │
│  │  Manager          │  │  Engine            │  │  Engine        │ │
│  │  ┌──────────────┐│  │  ┌──────────────┐  │  └──────────────┘ │
│  │  │inQueue  chan  ││◄─┤  │taskQueue chan│  │  Round Robin      │
│  │  │outQueue chan  ││  │  └──────────────┘  │                    │
│  │  └──────────────┘│  │  Worker Pool × N   │                    │
│  └────────┬─────────┘  └──────────┬─────────┘                    │
│           │                       │                               │
│  ┌────────▼───────────────────────▼─────────┐                     │
│  │         Notification Dispatcher           │                     │
│  │  ┌─────────┐ ┌─────────┐ ┌────────────┐ │                     │
│  │  │  In-App  │ │  WS Hub  │ │   Email    │ │                     │
│  │  │  (DB)    │ │ Broadcast│ │  (SMTP)    │ │                     │
│  │  └─────────┘ └─────────┘ └────────────┘ │                     │
│  └──────────────────────────────────────────┘                     │
│                                                                  │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐            │
│  │  SLA      │ │  Webhook  │ │  Auth     │ │  Authz    │            │
│  │  Manager  │ │  Manager  │ │  Service  │ │  Enforcer │            │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘            │
│                                                                  │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐            │
│  │  User     │ │  Inbox    │ │  Media    │ │  Tag      │            │
│  │  Manager  │ │  Manager  │ │  Manager  │ │  Manager  │            │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘            │
└──────────┬──────────────────────────┬─────────────────────────────┘
           │                          │
           ▼                          ▼
┌─────────────────────┐  ┌─────────────────────┐
│   PostgreSQL 17      │  │     Redis 7           │
│   ┌───────────────┐ │  │  ┌───────────────────┐│
│   │ conversations │ │  │  │ sessions           ││
│   │ messages      │ │  │  │ rate_limit:{rule}  ││
│   │ users         │ │  │  │ online status      ││
│   │ inboxes       │ │  │  └───────────────────┘│
│   │ ...           │ │  │                       │
│   └───────────────┘ │  └───────────────────────┘
└─────────────────────┘
```

---

## 5. 架构设计核心考量总结

### 5.1 单体 vs 微服务

LibreDesk 选择**单体架构**的考量：

| 因素 | 单体 | 微服务 |
|------|------|--------|
| 团队规模 | 小团队（1-5 人） | 大团队（多组独立开发） |
| 部署复杂度 | 单二进制 + DB + Redis | 多服务 + 服务发现 + API 网关 |
| 开发速度 | 快（无跨服务调用） | 慢（网络调用、序列化开销） |
| 数据一致性 | 强一致（同一数据库） | 最终一致（跨服务事务复杂） |
| 运维成本 | 低 | 高（监控、日志、链路追踪） |
| 横向扩展 | 受限于单进程 | 可按服务独立扩展 |

**Go 单体的优势**：Go 编译为单二进制 + fasthttp 高性能 + goroutine 并发，单实例即可支撑万级 QPS。

### 5.2 同步 vs 异步

| 操作类型 | 方式 | 原因 |
|---------|------|------|
| Agent 读取会话列表 | 同步 | 需要立即返回结果 |
| Agent 发送消息 | 同步入库 + 异步出站 | 入库快，出站（邮件/推送）可能慢 |
| 自动化规则评估 | 异步（taskQueue） | 规则评估耗时，不应阻塞请求 |
| Webhook 投递 | 异步（deliveryQueue） | 外部系统不可控，不能阻塞业务 |
| 通知推送 | 同步写 DB + 异步 WS/邮件 | 确保通知持久化后再推送 |

### 5.3 一致性 vs 可用性

LibreDesk 在 CAP 中偏向 **AP**（可用性优先于强一致性）：

- 消息可能短暂延迟但不会丢失（channel 缓冲 + 优雅关闭）
- WebSocket 推送失败时消息仍存在于数据库
- 限流基于 Redis（Redis 不可用时限流失效，但不影响核心功能）

### 5.4 可观测性

| 维度 | 项目中的实现 |
|------|------------|
| 日志 | `logf` 结构化日志，Key-Value 格式 |
| 健康检查 | `GET /health` 端点 |
| 运行状态 | WebSocket 在线用户数、连接数 |
| 业务指标 | 会话计数、消息队列深度、SLA 统计 |
| 活动日志 | `activity_log` 表记录管理操作 |

### 5.5 扩展性设计

LibreDesk 在以下维度预留了扩展能力：

| 扩展点 | 设计 | 当前实现 |
|-------|------|---------|
| 新消息渠道 | `Inbox` 接口 + `Register()` | Email, LiveChat |
| 新存储后端 | `mediaStore` 接口 | 本地文件系统, S3 |
| 新通知通道 | `Dispatcher` 组合模式 | WS + DB + Email |
| 新认证方式 | `authenticateUser` 函数 | API Key + Session + OIDC |
| 自动化动作 | `ApplyAction` 方法 | 多种 RuleAction |
| 限流规则 | `AddRule()` 动态注册 | auth, widget, public |

---

> **相关文档**：
> - 上一篇：[安全防护与配置管理](04-security-config.md)
> - 基础知识：[Go 并发编程](../go-basics/08-concurrency.md)
> - 完整架构：[技术亮点分析报告](../tech-highlights-report.md)
