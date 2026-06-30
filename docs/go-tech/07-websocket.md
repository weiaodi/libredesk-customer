# 主流技术：WebSocket 实时通信

## Hub-Client 模式

LibreDesk 实现了经典的 WebSocket Hub-Client 架构：

```
┌─────────────┐     ┌─────────────┐
│   Client A   │     │   Client B   │
│  (Agent 1)   │     │  (Agent 2)   │
└──────┬───────┘     └──────┬───────┘
       │                    │
       │  WebSocket         │  WebSocket
       │                    │
┌──────▼──────────────────────▼───────┐
│              Hub                     │
│  - 管理所有连接                      │
│  - 订阅/发布机制                     │
│  - 消息广播                         │
└─────────────────────────────────────┘
```

**核心流程**：
1. Agent 连接 → Hub 创建 Client 对象
2. Agent 订阅会话 → Hub 记录订阅关系
3. 新消息到达 → Hub 查找订阅者 → 推送给相关 Client
4. Agent 断开 → Hub 移除 Client 和订阅

## 并发安全的 Hub

**项目实例** — `internal/ws/ws.go`：

```go
type Hub struct {
    lo *logf.Logger

    clients      map[int][]*Client     // 用户ID → 该用户的多个连接
    clientsMutex sync.RWMutex          // 保护 clients map

    convSubsList   map[string]map[*Client]struct{}  // 会话UUID → 订阅的客户端列表
    convSubsOpen   map[string]map[*Client]struct{}  // 会话UUID → 打开的客户端
    clientListSubs map[*Client]map[string]struct{}  // 客户端 → 订阅的会话列表
    clientOpenSub  map[*Client]string                 // 客户端 → 当前打开的会话
    subsMu         sync.RWMutex                      // 保护订阅 map
}

// 广播消息给指定用户的所有连接
func (h *Hub) BroadcastMessage(msg models.BroadcastMessage) {
    h.clientsMutex.RLock()
    defer h.clientsMutex.RUnlock()

    if len(msg.Users) == 0 {
        // 广播给所有人
        for _, clients := range h.clients {
            for _, client := range clients {
                client.SendMessage(msg.Data, websocket.TextMessage)
            }
        }
        return
    }

    // 广播给指定用户
    for _, userID := range msg.Users {
        for _, client := range h.clients[userID] {
            client.SendMessage(msg.Data, websocket.TextMessage)
        }
    }
}
```

---

> **相关文档**：
> - 上一章：[缓存与 Redis](06-redis-cache.md)
> - 下一章：[架构模式总结与学习路线](08-architecture-summary.md)
> - 深入架构：[后端架构设计方案](../go-architecture/)
