# 主流技术：日志

## 结构化日志

LibreDesk 使用 `logf` 进行结构化日志记录，每条日志包含键值对：

```go
// 创建 logger
lo := initLogger("conversation_manager")

// 记录日志（键值对格式）
lo.Error("error checking permission", "error", err)
lo.Error("csrf token mismatch", "method", method, "cookie_token", cookieToken, "header_token", hdrToken)
lo.Debug("kicking user ws connections", "user_id", userID, "connections", len(clients))
```

**结构化日志的好处**：
- 机器可解析（方便 ELK、Grafana Loki 等日志系统）
- 搜索过滤方便（按 user_id、error 等字段过滤）

---

> **相关文档**：
> - 上一章：[配置管理](04-config.md)
> - 下一章：[缓存与 Redis](06-redis-cache.md)
