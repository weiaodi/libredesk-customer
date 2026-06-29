# 上下文链接 (Context Links)

> 原文: https://docs.libredesk.io/configuration/context-links
> 关键词: Context Links, 上下文链接, CRM, 集成, 加密 Token, AES-256

上下文链接是对话侧边栏中的按钮，打开外部 URL 时自动填入联系人和对话详情。Agent 点击即可跳转到 CRM、计费系统或内部仪表板，无需手动复制粘贴。

## URL 模板变量

| 变量 | 说明 |
|------|------|
| `{{email}}` | 联系人邮箱 |
| `{{phone}}` | 联系人电话 |
| `{{phone_country_code}}` | 电话国家代码 |
| `{{external_user_id}}` | 外部用户 ID |
| `{{contact_id}}` | LibreDesk 内部联系人 ID |
| `{{first_name}}` | 联系人名 |
| `{{last_name}}` | 联系人姓 |
| `{{conversation_uuid}}` | 当前对话 UUID |
| `{{token}}` | 包含所有字段的加密 Token（需要密钥） |

除 `{{contact_id}}` 和 `{{conversation_uuid}}` 外，所有值自动 URL 编码。

### 示例

**按邮箱查找**：
```
https://crm.example.com/contacts?email={{email}}
```

**多参数**：
```
https://billing.example.com/customer?ext_id={{external_user_id}}&email={{email}}
```

**内部仪表板**：
```
https://dashboard.internal/lookup?contact={{contact_id}}&conv={{conversation_uuid}}
```

**安全集成（加密 Token）**：
```
https://api.example.com/auth/libredesk?token={{token}}
```

## 加密 Token

使用 `{{token}}` 时，LibreDesk 生成 AES-256-GCM 加密的限时 Token，包含上述所有字段加上 `agent_id`、`agent_email`、`iat`、`exp`。接收系统用共享密钥解密。

### 解密 Token (Python)

```python
import base64, json, time
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

def decrypt_context_token(token, secret):
    raw = base64.b64decode(token)
    nonce = raw[:12]
    ciphertext = raw[12:]

    aesgcm = AESGCM(secret.encode('utf-8'))
    plaintext = aesgcm.decrypt(nonce, ciphertext, None)
    return json.loads(plaintext)

# 使用
secret = "your-32-character-shared-secret!"  # 恰好 32 字符
payload = decrypt_context_token(token_from_url, secret)

if payload["exp"] < time.time():
    raise ValueError("Token has expired")

print(payload["email"], payload["conversation_uuid"])
```
