# LibreDesk 开发环境搭建

> 原文: https://docs.libredesk.io/contributing/developer-setup
> 关键词: 开发环境, 开发者, dev setup, make, 前端, 后端, 构建

LibreDesk 是 monorepo 结构：Go 后端 + Vue.js 前端（Shadcn UI 组件）。

## 前置条件

- Go
- Node.js + pnpm（前端开发时需要）
- Redis
- PostgreSQL >= 13

## 首次搭建

```bash
git clone https://github.com/abhinavxd/libredesk.git
cd libredesk

# 配置
cp config.sample.toml config.toml
# 编辑 config.toml 填入数据库凭据等

# 构建并初始化数据库
make
./libredesk --install
# 按提示设置 System 用户密码
```

## 开发模式运行

### 全栈开发

```bash
# 终端 1: 启动后端（端口 :9000）
make run-backend

# 终端 2: 启动前端（端口 :8000，代理到 :9000）
make run-frontend
```

前端通过 `vite.config.js` 配置代理，将 API 请求转发到后端 `:9000`。

### 仅后端

```bash
make run-backend
# 访问 http://localhost:9000
```

### 仅前端

```bash
make run-frontend
# 访问 http://localhost:8000
```

## 生产构建

```bash
make
```

此命令会：
1. 构建 Go 二进制
2. 构建 JavaScript 前端
3. 嵌入静态资源（通过 stuffbin）
4. 产出单一自包含二进制文件: `libredesk`
