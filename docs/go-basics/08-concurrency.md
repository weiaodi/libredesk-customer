# 基础概念：并发编程

Go 的并发模型基于 **CSP（Communicating Sequential Processes）**，核心概念是 goroutine 和 channel。

## Goroutine

goroutine 是 Go 的轻量级线程，使用 `go` 关键字启动：

**项目实例** — `cmd/main.go` 中大量使用 goroutine：

```go
// 启动多个后台任务（各自独立运行）
go automation.Run(ctx, automationWorkers)           // 自动化规则引擎
go autoassigner.Run(ctx, autoAssignInterval)        // 自动分配器
go conversation.Run(ctx, messageIncomingQWorkers, messageOutgoingQWorkers, messageOutgoingScanInterval)
go conversation.RunUnsnoozer(ctx, unsnoozeInterval) // 取消延时
go conversation.RunContinuity(ctx)                  // 连续性邮件
go webhook.Run(ctx)                                 // Webhook 投递
go notifier.Run(ctx)                                // 通知发送
go sla.Run(ctx, slaEvaluationInterval)              // SLA 评估
go media.DeleteUnlinkedMedia(ctx)                   // 清理无用媒体
go user.MonitorUserAvailability(ctx, onUsersOffline(conversation))  // 用户在线监控

// HTTP 服务器也在 goroutine 中启动
go func() {
    colorlog.Green("Server started at %s", ko.String("app.server.address"))
    if err := g.ListenAndServe(...); err != nil {
        log.Fatalf("error starting server: %v", err)
    }
}()
```

## Channel（通道）

channel 是 goroutine 之间通信的管道，遵循 "不要通过共享内存来通信，而要通过通信来共享内存" 的原则。

**项目实例** — `internal/conversation/conversation.go` 消息队列：

```go
type Manager struct {
    incomingMessageQueue chan models.IncomingMessage  // 带缓冲的传入消息通道
    outgoingMessageQueue chan models.Message          // 带缓冲的传出消息通道
    // ...
}

// 创建带缓冲的 channel
c := &Manager{
    incomingMessageQueue: make(chan models.IncomingMessage, opts.IncomingMessageQueueSize),
    outgoingMessageQueue: make(chan models.Message, opts.OutgoingMessageQueueSize),
}
```

**项目实例** — `internal/ws/client.go` 中的 channel 使用：

```go
type Client struct {
    ID   int
    Hub  *Hub
    Conn *websocket.Conn
    Send chan models.WSMessage  // 发送消息的通道
}

// 从 channel 读取消息（阻塞直到有消息）
func (c *Client) Serve() {
    for {
        select {
        case msg, ok := <-c.Send:     // 从 channel 读取
            if !ok {                   // channel 已关闭
                return
            }
            c.Conn.WriteMessage(msg.MessageType, msg.Data)
        }
    }
}
```

## select 多路复用

`select` 同时监听多个 channel，哪个就绪执行哪个：

**项目实例** — `internal/ws/client.go`：

```go
func (c *Client) Serve() {
    var heartBeatTicker = time.NewTicker(2 * time.Second)
    defer heartBeatTicker.Stop()
    defer c.Conn.Close()

    for {
        select {
        case <-heartBeatTicker.C:        // 心跳定时器触发
            if err := c.Conn.WriteMessage(websocket.PingMessage, nil); err != nil {
                return
            }
        case msg, ok := <-c.Send:        // 有消息待发送
            if !ok {
                return
            }
            c.Conn.WriteMessage(msg.MessageType, msg.Data)
        }
    }
}
```

## 非阻塞 channel 操作

使用 `select + default` 实现非阻塞发送，避免 channel 满时阻塞：

**项目实例** — `internal/ws/client.go`：

```go
// 非阻塞发送：channel 满时丢弃消息而不是阻塞
func (c *Client) SendMessage(b []byte, typ byte) {
    if c.Closed.Get() {
        return
    }
    select {
    case c.Send <- models.WSMessage{Data: b, MessageType: websocket.TextMessage}:
        // 成功发送
    default:
        // channel 已满，丢弃消息并记录警告
        c.Hub.lo.Warn("client send channel full, dropping message", "client_id", c.ID)
    }
}
```

## sync.Mutex 与 sync.RWMutex

当必须共享内存时，使用互斥锁保护：

**项目实例** — `internal/ws/ws.go`：

```go
type Hub struct {
    clients      map[int][]*Client
    clientsMutex sync.RWMutex          // 读写锁
    
    convSubsList  map[string]map[*Client]struct{}
    subsMu        sync.RWMutex         // 订阅的读写锁
}

// 写操作用写锁（Lock）
func (h *Hub) AddClient(client *Client) {
    h.clientsMutex.Lock()
    defer h.clientsMutex.Unlock()  // defer 确保一定会解锁
    h.clients[client.ID] = append(h.clients[client.ID], client)
}

// 读操作用读锁（RLock），允许多个读者并发
func (h *Hub) ConnectedUserIDs() []int {
    h.clientsMutex.RLock()
    defer h.clientsMutex.RUnlock()
    out := make([]int, 0, len(h.clients))
    for id := range h.clients {
        out = append(out, id)
    }
    return out
}
```

**RWMutex vs Mutex**：
- `Mutex`：同一时间只允许一个 goroutine 访问（无论读写）
- `RWMutex`：读操作可并发，写操作独占 → 读多写少场景性能更好

## sync.Map

`sync.Map` 是并发安全的 map，适用于读多写少且 key 相对稳定的场景：

**项目实例** — `internal/conversation/conversation.go`：

```go
type Manager struct {
    outgoingProcessingMessages sync.Map  // 并发安全的 map
    // ...
}
```

## sync.WaitGroup

`WaitGroup` 用于等待一组 goroutine 完成：

**项目实例** — `internal/conversation/conversation.go`：

```go
type Manager struct {
    wg sync.WaitGroup  // 跟踪后台 goroutine
    // ...
}
```

## Context（上下文）

`context.Context` 是 Go 并发编程的核心，用于**取消**、**超时**和**传值**：

**项目实例** — `cmd/main.go`：

```go
// 创建可取消的 context（监听系统信号）
ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGINT, syscall.SIGTERM)
defer stop()

// 所有后台 goroutine 接收 context
go automation.Run(ctx, automationWorkers)
go autoassigner.Run(ctx, autoAssignInterval)

// 等待取消信号
<-ctx.Done()              // 阻塞直到 context 被取消

// 优雅关闭
s.Shutdown()
inbox.Close()
automation.Close()
```

**Context 使用原则**：
1. Context 作为函数**第一个参数**传递，不要放在结构体里
2. 用 `context.Background()` 作为最顶层的根 context
3. 用 `context.WithCancel()` / `WithTimeout()` 创建子 context
4. 不要用 Context 传业务数据，只用它传控制信号

## atomic.Value

`atomic.Value` 提供无锁的原子读写，适用于"一次写入多次读取"的场景：

**项目实例** — `cmd/main.go`：

```go
type App struct {
    consts atomic.Value  // 原子值，存储应用常量
}

// 写入（启动时写一次）
app.consts.Store(constants)

// 读取（运行时大量读取，无锁安全）
c := app.consts.Load().(*constants)
```

---

> **相关文档**：
> - 上一章：[错误处理](07-error-handling.md)
> - 下一章：[embed 嵌入资源](09-embed.md)
