# 后台任务与消息队列架构

> 本文档讲解 LibreDesk 中的 Worker Pool、Channel Queue 和事件驱动架构模式。

---

## 1. Worker Pool 模式

### 1.1 模式概述

LibreDesk 中有大量需要持续运行的后台任务，统一采用 **Worker Pool + Channel Queue** 模式：

```
                    ┌──→ Worker 1 ──→ 处理任务
                    │
生产者 ──→ Channel  ├──→ Worker 2 ──→ 处理任务
  Queue     │
                    ├──→ Worker 3 ──→ 处理任务
                    │
                    └──→ Worker N ──→ 处理任务
```

### 1.2 项目中的 Worker Pool 实例

**Automation Engine**（`internal/automation/automation.go`）：

```go
type Engine struct {
    taskQueue chan ConversationTask       // 任务队列（带缓冲 channel）
    wg        sync.WaitGroup              // 跟踪所有 worker
    closed    bool                        // 关闭标志
    closedMu  sync.RWMutex               // 保护关闭标志
}

// 启动 Worker Pool
func (e *Engine) Run(ctx context.Context, workerCount int) {
    for i := 0; i < workerCount; i++ {
        e.wg.Add(1)
        go e.worker(ctx)  // 启动 worker goroutine
    }

    // 定时触发器
    ticker := time.NewTicker(1 * time.Hour)
    for {
        select {
        case <-ctx.Done():
            return                    // 收到取消信号
        case <-ticker.C:
            e.taskQueue <- ConversationTask{taskType: TimeTrigger}
        }
    }
}

// 单个 worker
func (e *Engine) worker(ctx context.Context) {
    defer e.wg.Done()
    for {
        select {
        case <-ctx.Done():
            return
        case task, ok := <-e.taskQueue:
            if !ok { return }         // 队列关闭
            switch task.taskType {
            case NewConversation:
                e.handleNewConversation(task.conversation)
            case UpdateConversation:
                e.handleUpdateConversation(task.conversation, task.eventType)
            case TimeTrigger:
                e.handleTimeTrigger()
            }
        }
    }
}

// 优雅关闭
func (e *Engine) Close() {
    e.closedMu.Lock()
    defer e.closedMu.Unlock()
    if e.closed { return }
    e.closed = true
    close(e.taskQueue)     // 关闭 channel，所有 worker 会收到零值
    e.wg.Wait()            // 等待所有 worker 处理完当前任务
}
```

### 1.3 同一模式在项目中的多种应用

| 后台服务 | Worker 数量 | 队列类型 | 配置来源 |
|---------|-----------|---------|---------|
| Automation Engine | 可配置 | `chan ConversationTask` | `automation.worker_count` |
| Message Outgoing | 可配置 | `chan Message` | `message.outgoing_queue_workers` |
| Message Incoming | 可配置 | `chan IncomingMessage` | `message.incoming_queue_workers` |
| Webhook Delivery | 可配置 | `chan DeliveryTask` | `webhook.workers` |
| Auto-Assigner | 1（定时器） | 无队列 | `autoassigner.autoassign_interval` |
| SLA Evaluator | 1（定时器） | 无队列 | `sla.evaluation_interval` |

### 1.4 设计考量

**Q: 为什么用 channel 而不是 Redis/List 队列？**

| 方案 | 优点 | 缺点 | 适用场景 |
|------|------|------|---------|
| Go channel | 零外部依赖、极低延迟、类型安全 | 进程内、重启丢失 | 单进程内的异步任务 |
| Redis List | 持久化、跨进程、可横向扩展 | 延迟较高、依赖 Redis | 分布式/多实例部署 |
| 消息队列 (NATS/RabbitMQ) | 可靠投递、多消费者 | 运维复杂 | 大规模分布式系统 |

LibreDesk 选择 channel 的考量：
- 单进程部署（Go 编译为单二进制）
- 任务处理延迟要求低（毫秒级）
- 优雅关闭时 channel 中的任务会被 worker 处理完再退出
- 如果进程崩溃，丢失的是"进行中的任务"，重启后从数据库重新加载即可

---

## 2. 消息队列架构：Channel-Based Queue

### 2.1 生产者-消费者模式

Conversation Manager 同时扮演消息队列的**生产者和消费者**：

```
收件箱(Email/LiveChat)                    HTTP Handler(Agent 发消息)
       │                                        │
       │ IncomingMessage                        │ Message
       ▼                                        ▼
  ┌──────────────────────────────────────────────────┐
  │              Conversation Manager                  │
  │                                                   │
  │  incomingMessageQueue ←── EnqueueIncoming()       │
  │  outgoingMessageQueue ←── EnqueueOutgoing()       │
  │                                                   │
  │  Worker 1 ──→ ProcessIncoming ──→ 入库+通知+自动化│
  │  Worker 2 ──→ ProcessOutgoing ──→ 发送邮件/聊天   │
  └──────────────────────────────────────────────────┘
```

**项目实例** — `internal/conversation/conversation.go`：

```go
type Manager struct {
    incomingMessageQueue chan models.IncomingMessage  // 进站消息队列
    outgoingMessageQueue chan models.Message          // 出站消息队列
    outgoingProcessingMessages sync.Map               // 正在处理的消息（幂等性保护）
}

// 创建带缓冲的队列
c := &Manager{
    incomingMessageQueue: make(chan models.IncomingMessage, opts.IncomingMessageQueueSize),  // 例如 5000
    outgoingMessageQueue: make(chan models.Message, opts.OutgoingMessageQueueSize),           // 例如 5000
}
```

### 2.2 队列满时的降级策略

当 channel 缓冲满时，不同场景采用不同策略：

| 场景 | 策略 | 代码位置 |
|------|------|---------|
| WS 消息推送 | **丢弃 + 日志告警** | `ws/client.go` SendMessage |
| WS 错误消息 | **断开客户端** | `ws/client.go` SendError |
| 业务消息入队 | **阻塞等待**（默认行为） | `conversation.go` EnqueueIncoming |

**丢弃 vs 阻塞的考量**：
- 实时推送（WS）：消息时效性短，丢弃比阻塞更合理，避免影响其他客户端
- 业务消息（入库）：数据不能丢，阻塞等待直到队列有空间

---

## 3. 事件驱动架构：观察者与发布订阅

### 3.1 隐式事件流

LibreDesk 的核心业务流程中存在一条隐式的事件链：

```
新消息到达
  │
  ├──→ 入库（Conversation Manager）
  │
  ├──→ 触发自动化规则（Automation Engine）
  │      │
  │      └──→ 执行动作（修改状态/分配/发通知）
  │
  ├──→ 触发 Webhook（Webhook Manager）
  │      │
  │      └──→ HTTP POST 到外部系统
  │
  ├──→ 触发通知（Dispatcher）
  │      │
  │      ├──→ 应用内通知（DB 存储）
  │      ├──→ WebSocket 推送
  │      └──→ 邮件通知
  │
  └──→ 触发 SLA 评估（SLA Manager）
         │
         └──→ 检查是否违反 SLA → 发送警告
```

### 3.2 通知分发器模式

**项目实例** — `internal/notification/dispatcher.go`：

```go
// Dispatcher 是多通道通知分发器
type Dispatcher struct {
    inApp        *UserNotificationManager  // 应用内通知（DB）
    outbound     *Service                  // 邮件通知
    wsHub        WSHub                     // WebSocket 实时推送
    emailEnabled bool                      // 邮件是否启用
}

// Send 发送通知到所有通道
func (d *Dispatcher) Send(n Notification) {
    for _, recipientID := range n.RecipientIDs {
        // 1. 创建应用内通知（持久化到数据库）
        d.sendToRecipient(recipientID, n)

        // 2. 邮件通知（如果启用且提供了邮件内容）
        if d.outbound != nil && n.Email != nil && d.emailEnabled {
            d.sendEmail(recipientID, email, n.Email.Subject, n.Email.Content, n.Type)
        }
    }
}

// sendToRecipient 同时推送 WebSocket 和存储 DB
func (d *Dispatcher) sendToRecipient(recipientID int, n Notification) {
    // 先写入数据库
    notification, err := d.inApp.Create(recipientID, ...)
    
    // 再通过 WebSocket 实时推送
    data, _ := json.Marshal(...)
    d.wsHub.BroadcastMessage(wsmodels.BroadcastMessage{
        Users: []int{recipientID},
        Data:  data,
    })
}
```

### 3.3 事件驱动 vs 直接调用的选择

| 方式 | 优点 | 缺点 | 项目中的使用 |
|------|------|------|------------|
| 直接调用 | 简单、可追踪、同步执行 | 耦合度高、调用链长 | 小范围调用（如 Conversation → Dispatcher） |
| 事件队列 | 解耦、异步、可扩展 | 复杂、调试难、最终一致性 | Automation Engine 的 taskQueue |
| 发布订阅 | 完全解耦、多订阅者 | 需要中间件、运维成本 | WebSocket Hub 的订阅模式 |

LibreDesk 的选择：**小范围直接调用 + 大范围事件队列**。没有引入消息中间件（如 NATS/Kafka），因为单进程部署不需要。

---

> **相关文档**：
> - 上一篇：[架构分层与依赖注入](01-layering-di.md)
> - 下一篇：[实时通信与多渠道架构](03-realtime-channels.md)
> - 基础知识：[Go 并发编程](../go-basics/08-concurrency.md)
