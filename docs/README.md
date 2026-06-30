# LibreDesk 学习文档

> 基于 LibreDesk 开源客户支持平台，系统讲解 Go 语言基础、主流技术栈和后端架构设计。所有代码示例均来自项目源码。

---

## 文档导航

### 1. Go 语言基础 (`go-basics/`)

Go 语言核心概念入门，从零开始学习 Go 语法，每个概念都对照项目真实代码。

| 文件 | 主题 | 核心内容 |
|------|------|---------|
| [01-overview.md](go-basics/01-overview.md) | 概述与项目全景 | Go 特性、技术栈总览 |
| [02-packages-modules.md](go-basics/02-packages-modules.md) | 包与模块 | go.mod、import、可见性规则 |
| [03-variables-types.md](go-basics/03-variables-types.md) | 变量、常量与类型 | var/const/:=、struct tag、null 类型 |
| [04-functions.md](go-basics/04-functions.md) | 函数 | 多返回值、闭包、Opts 模式 |
| [05-structs-methods.md](go-basics/05-structs-methods.md) | 结构体与方法 | 指针/值接收者、嵌入组合 |
| [06-interfaces.md](go-basics/06-interfaces.md) | 接口 | 隐式实现、依赖注入、类型断言 |
| [07-error-handling.md](go-basics/07-error-handling.md) | 错误处理 | error 接口、自定义错误、if err != nil |
| [08-concurrency.md](go-basics/08-concurrency.md) | 并发编程 | goroutine、channel、select、Mutex、Context |
| [09-embed.md](go-basics/09-embed.md) | embed 嵌入资源 | //go:embed、二进制自包含 |

### 2. Go 主流技术栈 (`go-tech/`)

Web 开发实战中常用的 Go 技术方案，结合项目讲解选型与用法。

| 文件 | 主题 | 核心内容 |
|------|------|---------|
| [01-http-routing.md](go-tech/01-http-routing.md) | HTTP 框架与路由 | fasthttp + fastglue、Handler 签名 |
| [02-middleware.md](go-tech/02-middleware.md) | 中间件模式 | 高阶函数、洋葱模型、auth/perm/rateLimit |
| [03-database.md](go-tech/03-database.md) | 数据库访问层 | sqlx、goyesql SQL 分离、空导入 |
| [04-config.md](go-tech/04-config.md) | 配置管理 | koanf 多源合并、TOML、环境变量 |
| [05-logging.md](go-tech/05-logging.md) | 日志 | logf 结构化日志、Key-Value 格式 |
| [06-redis-cache.md](go-tech/06-redis-cache.md) | 缓存与 Redis | go-redis、Redis Pipeline 滑动窗口限流 |
| [07-websocket.md](go-tech/07-websocket.md) | WebSocket 实时通信 | Hub-Client 模式、并发安全广播 |
| [08-architecture-summary.md](go-tech/08-architecture-summary.md) | 架构模式总结与学习路线 | 分层架构、Manager 模式、学习阶段规划 |

### 3. Go 后端架构设计 (`go-architecture/`)

后端常用架构设计模式与方案选型考量，深度分析设计决策背后的权衡。

| 文件 | 主题 | 核心内容 |
|------|------|---------|
| [01-layering-di.md](go-architecture/01-layering-di.md) | 架构分层与依赖注入 | 三层架构、构造函数注入、循环依赖解决 |
| [02-task-queue.md](go-architecture/02-task-queue.md) | 后台任务与消息队列 | Worker Pool、Channel Queue、事件驱动、通知分发器 |
| [03-realtime-channels.md](go-architecture/03-realtime-channels.md) | 实时通信与多渠道架构 | WebSocket Hub-Client、RBAC 权限、Inbox 适配器模式 |
| [04-security-config.md](go-architecture/04-security-config.md) | 安全防护与配置管理 | 限流/SSRF/CSRF/加密、静态/动态配置、koanf 五源合并 |
| [05-data-cache-lifecycle.md](go-architecture/05-data-cache-lifecycle.md) | 数据访问、缓存与生命周期 | sqlx vs ORM、四级缓存策略、优雅关闭、架构全景图、核心考量 |

### 4. 技术亮点分析 (`tech-highlights-report.md`)

从后端、前端、数据库、跨端通信四个维度梳理项目表现突出的技术选型与实现。

### 5. 技术价值深挖 (`tech-value-deep-dive.md`)

`tech-highlights-report.md` 的补充，覆盖前者未涉及的 5 大领域：业务引擎层（SLA 工时计算器、规则求值器、Importer 等）、安全防护层（SSRF、字段加密、HMAC 签名、RBAC 数据可见等）、集成通信层（IMAP/SMTP 协议栈、OIDC SSO、Webhook 投递闭环等）、前端工程化层（DraftManager 双写、CommandBox、消息去重等）、数据与可观测层（统一 Envelope、双轨文件系统、Goroutine 生命周期编排等）。

---

## 阅读路线建议

### 入门路线（Go 零基础）

```
go-basics/01 → 02 → 03 → 04 → 05 → 06 → 07 → 08 → 09
                                                         ↓
                                              go-tech/01 → 02 → 03 → ... → 08
```

### 架构路线（有 Go 基础）

```
go-tech/08（架构总结）→ go-architecture/01 → 02 → 03 → 04 → 05
```

### 快速参考（查漏补缺）

直接根据上方表格定位到感兴趣的章节即可，各文件之间有前后导航链接。

---

> 所有文档基于 LibreDesk 项目源码生成，项目路径：`github.com/abhinavxd/libredesk`
