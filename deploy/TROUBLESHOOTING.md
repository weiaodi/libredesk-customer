# libredesk 部署过程问题总结与经验

## 目录

- [部署环境](#部署环境)
- [问题一：SSH 私钥格式不对](#问题一ssh-私钥格式不对)
- [问题二：Mixed Content 混合内容拦截](#问题二mixed-content-混合内容拦截)
- [问题三：Cloudflare 只支持特定端口](#问题三cloudflare-只支持特定端口)
- [问题四：Cloudflare SSL 模式选错](#问题四cloudflare-ssl-模式选错)
- [问题五：yum 安装卡死](#问题五yum-安装卡死)
- [问题六：域名控制台混淆](#问题六域名控制台混淆)
- [问题七：unsafeWindow 未定义](#问题七unsafewindow-未定义)
- [问题八：油猴 GM 只能绕过加载不能绕过运行时请求](#问题八油猴-gm-只能绕过加载不能绕过运行时请求)
- [关键知识点总结](#关键知识点总结)
- [最终正确架构](#最终正确架构)

---

## 部署环境

| 项目 | 值 |
|------|------|
| 服务器 | 阿里云海外轻量服务器 |
| 公网 IP | 47.254.82.193 |
| 应用 | libredesk v2.4.0 |
| 部署方式 | Docker Compose |
| 域名 | flqartw.cn（阿里云注册，已接入 Cloudflare） |
| 目标网站 | storiago.com（HTTPS） |

---

## 问题一：SSH 私钥格式不对

**现象**
```
Load key "/tmp/libredesk_key": invalid format
Permission denied (publickey)
```

**原因**

SSH 私钥必须是 PEM 格式（以 `-----BEGIN RSA PRIVATE KEY-----` 开头），不是普通的字符串或哈希值。

**教训**

- 阿里云轻量服务器默认只支持密钥对登录，不支持密码登录
- 密钥对需要在阿里云控制台创建并下载 `.pem` 文件
- 如果是 Workbench（阿里云网页终端），可以直接在浏览器登录，无需本地密钥

---

## 问题二：Mixed Content 混合内容拦截

**现象**
```
Mixed Content: The page at 'https://storiago.com/...' was loaded over HTTPS,
but requested an insecure resource 'http://47.254.82.193:9000/widget.js'.
This request has been blocked.
```

**原因**

浏览器安全策略：**HTTPS 页面不允许加载任何 HTTP 资源**，包括脚本、图片、API 请求。

**规律**

| 页面协议 | 资源协议 | 结果 |
|------|------|------|
| HTTPS | HTTPS | ✅ 允许 |
| HTTPS | HTTP | ❌ 拦截 |
| HTTP | HTTPS | ✅ 允许 |
| HTTP | HTTP | ✅ 允许 |

**解决方案**

给服务器配置 HTTPS（Nginx + SSL 证书 或 Cloudflare 代理）。

**教训**

只要目标网站是 HTTPS，你的服务也必须是 HTTPS，否则 widget 无法嵌入。

---

## 问题三：Cloudflare 只支持特定端口

**现象**

通过 Cloudflare 代理访问 `http://flqartw.cn:9000` 时，请求一直 pending，永远不响应。

**原因**

Cloudflare 免费代理**只支持以下端口**：

| 协议 | 支持的端口 |
|------|------|
| HTTP | 80, 8080, 8880, 2052, 2082, 2086, 2095 |
| HTTPS | 443, 2053, 2083, 2087, 2096, 8443 |

9000 端口不在列表内，Cloudflare 直接丢弃请求。

**解决方案**

必须在服务器上装 Nginx，把 80/443 端口的请求转发到 9000。

**教训**

用 Cloudflare 代理时，不能直接暴露非标准端口，必须用 Nginx 做反向代理。

---

## 问题四：Cloudflare SSL 模式选错

**现象**
```
ERR_SSL_PROTOCOL_ERROR
www.flqartw.cn 发送了无效的响应
```

**原因**

Cloudflare SSL 模式设置为 `Full`，意味着 Cloudflare 到服务器这段也要用 HTTPS。但服务器只有 HTTP（9000 端口没有 SSL），导致握手失败。

**四种 SSL 模式说明**

| 模式 | 浏览器→CF | CF→服务器 | 适用场景 |
|------|------|------|------|
| Off | HTTP | HTTP | 不推荐 |
| Flexible | HTTPS | HTTP | 服务器无证书时用 |
| Full | HTTPS | HTTPS（不验证） | 服务器有自签名证书 |
| Full (Strict) | HTTPS | HTTPS（验证） | 服务器有正规证书 |

**解决方案**

服务器没有 SSL 证书时，选 **Flexible** 模式。

---

## 问题五：yum 安装卡死

**现象**

执行 `sudo yum install -y nginx certbot python3-certbot-nginx` 时，命令卡住无响应。

**原因**

海外服务器连接国内 yum 镜像源（阿里云国内源）速度极慢，容易超时卡死。

**解决方案**

**方案一**：换海外镜像源
```bash
sudo sed -i 's|mirrors.cloud.aliyuncs.com|mirrors.aliyun.com|g' /etc/yum.repos.d/*.repo
sudo yum clean all && sudo yum makecache
```

**方案二**：用 Docker 代替 yum（推荐，服务器已有 Docker）
```bash
# 用 Docker 运行 Nginx，完全不需要 yum
sudo docker run -d --name nginx_proxy \
  -p 80:80 -p 443:443 \
  nginx:alpine
```

**教训**

海外服务器建议预先换好镜像源，或者优先使用 Docker 方式部署，避免包管理器的网络问题。

---

## 问题六：域名控制台混淆

**现象**

在阿里云**轻量服务器**控制台的「域名」tab 添加域名，报错：
```
域名格式不正确，请输入正确的域名，由二级域名和顶级域名构成
```

**原因**

阿里云轻量服务器的「域名」功能是用来绑定二级域名的，**不是 DNS 解析管理**，且不接受三级子域名（如 `desk.storiago.bbroot.com`）。

**正确入口**

- DNS 解析管理：https://dc.console.aliyun.com（域名控制台）
- 轻量服务器的「域名」tab 只是记录绑定关系，对实际访问没影响

**教训**

阿里云有多个控制台，功能不同：
- **ECS 控制台**：管理云服务器
- **轻量应用服务器控制台**：管理轻量服务器
- **域名控制台**（dc.console.aliyun.com）：管理 DNS 解析
- **SSL 证书控制台**：申请和下载证书

不要混淆，DNS 解析一定要在域名控制台改。

---

## 问题七：unsafeWindow 未定义

**现象**
```
ReferenceError: unsafeWindow is not defined
```

**原因**

油猴脚本中使用 `unsafeWindow` 需要在头部声明 `@grant unsafeWindow`，否则该变量不存在。

**解决方案**

两种方式：

1. 在头部添加声明：
```javascript
// @grant unsafeWindow
```

2. 直接用 `window` 替代（更简单）：
```javascript
// unsafeWindow 改成 window
if (window.__libredeskInjected) return;
window.__libredeskInjected = true;
```

---

## 问题八：油猴 GM 只能绕过加载不能绕过运行时请求

**现象**

使用 `GM_xmlhttpRequest` 成功加载了 `widget.js`，控制台显示「Widget 注入成功」，但 widget 仍然不显示，且出现 Mixed Content 错误：
```
Mixed Content: ... 'http://47.254.82.193:9000/api/v1/widget/chat/settings/launcher'
This request has been blocked.
```

**原因**

`GM_xmlhttpRequest` 只能绕过**脚本文件本身的加载**，但 `widget.js` 运行后内部发起的所有 `fetch`/`XHR` 请求都是在**页面上下文**中执行的，浏览器的 Mixed Content 限制照常生效。

**结论**

这个问题**无法用纯前端手段绕过**，必须让服务器支持 HTTPS。

---

## 关键知识点总结

### 1. HTTPS 嵌入的唯一要求

只要目标网站是 HTTPS，被嵌入的服务**必须也是 HTTPS**，没有任何绕过方式（除非修改浏览器安全设置，不现实）。

### 2. 域名获取 HTTPS 的方式对比

| 方式 | 难度 | 费用 | 备注 |
|------|------|------|------|
| Cloudflare 代理 | ⭐ | 免费 | 需要自己的根域名 |
| Certbot 免费证书 | ⭐⭐ | 免费 | 需要域名，90天自动续期 |
| 阿里云 SSL 证书 | ⭐⭐ | 免费1年 | 需要域名，到期需续费 |
| Cloudflare Tunnel | ⭐ | 免费 | 可以不需要域名 |
| 裸 IP HTTPS | ❌ | 极贵 | 不推荐 |

### 3. Cloudflare 使用要点

- 必须接管**根域名**（如 `flqartw.cn`），不能只接管子域名
- 代理模式（橙色云朵）只转发 80/443 等标准端口
- SSL 模式选择：服务器无证书选 Flexible，有证书选 Full
- 接管后 DNS 生效需要等待 NS 传播（最长 48 小时，通常 5-30 分钟）

### 4. Docker Compose 服务启动顺序

`depends_on` 只保证容器**启动顺序**，不保证服务就绪。数据库健康检查配合 `healthcheck` 才能确保 app 在 DB 真正就绪后再启动。

### 5. .cn 域名在海外的使用

- `.cn` 域名全球可以正常解析
- 服务器在**海外**：不需要备案，国内外均可访问
- 服务器在**国内**：必须备案才能正常访问

---

## 最终正确架构

```
用户浏览器（HTTPS）
       ↓
  Cloudflare（SSL 终止，Flexible 模式）
       ↓ HTTP
  服务器 Nginx（80/443 端口）
       ↓ HTTP
  libredesk Docker 容器（9000 端口）
       ↓
  PostgreSQL + Redis（容器内网，不对外暴露）
```

**需要开放的安全组端口**

| 端口 | 说明 |
|------|------|
| 22 | SSH 登录 |
| 80 | HTTP（Cloudflare 回源） |
| 443 | HTTPS（如果有证书） |
| 9000 | libredesk 直接访问（可选，测试用） |

**不需要对外开放的端口**（已绑定 127.0.0.1）

| 端口 | 说明 |
|------|------|
| 5432 | PostgreSQL |
| 6379 | Redis |

---

## 后续待完成

- [ ] 服务器安装 Nginx，把 80 端口转发到 9000
- [ ] 验证 `https://flqartw.cn` 可正常访问 libredesk
- [ ] 更新 `config.toml` 的 `disable_secure_cookies = false`
- [ ] 更新油猴脚本 `baseURL` 改为 `https://flqartw.cn`
- [ ] 验证 widget 在 storiago.com 正常显示
