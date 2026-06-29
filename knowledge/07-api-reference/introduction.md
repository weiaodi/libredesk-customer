# API 简介

> 原文: https://docs.libredesk.io/api-reference/introduction
> 关键词: API, 认证, API Key, Basic Auth, Token Auth, JSON

通过生成 API Key 可编程访问 LibreDesk 实例。

## 认证方式

### Basic Authentication

```bash
curl -X GET "https://your-instance.com/api/v1/endpoint" \
  -H "Authorization: Basic <base64_encoded_api_key:api_secret>"
```

### Token Authentication

```bash
curl -X GET "https://your-instance.com/api/v1/endpoint" \
  -H "Authorization: token api_key:api_secret"
```

## 获取 API Key

1. 导航到 **Admin > Teammate > Agent > Edit**
2. 生成新的 API Key
3. 保存 API Key 和 API Secret

## Base URL

```
https://your-instance.com/api/v1
```

## 响应格式

所有 API 响应以 JSON 格式返回。
