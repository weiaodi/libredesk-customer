# 邮件模板

> 原文: https://docs.libredesk.io/configuration/email-templates
> 关键词: 邮件模板, 模板变量, Go template, 发件格式

模板支持 HTML 格式化。使用 `<p>` 和 `<br>` 标签控制间距和换行。不带 HTML 标签的纯文本不会渲染换行。

## 模板结构

当配置了外发邮件模板时，它会自动包裹消息内容。`{{ template "content" . }}` 占位符表示消息正文插入的位置。

**示例模板**：

```html
<p>Dear {{ .Recipient.FirstName }},</p>

{{ template "content" . }}

<p>Best regards,<br>
{{ .Author.FullName }}</p>
---
<p>Reference: {{ .Conversation.ReferenceNumber }}</p>
```

## 模板行为规则

- **问候语**：如果模板已包含问候（如 `Dear {{ .Recipient.FirstName }}`），不要再在消息正文中添加问候
- **结束语**：如果模板已包含结束语（如 `Best regards, {{ .Author.FullName }}`），不要再在消息正文中添加结束语
- **消息内容**：只写应该在 `{{ template "content" . }}` 部分出现的主要内容

### 正确示例

**消息编辑器中写的内容**：
```
Thank you for contacting us. I've reviewed your account and can confirm that your refund has been processed.
```

**客户收到的邮件**：
```
Dear John,
Thank you for contacting us. I've reviewed your account and can confirm that your refund has been processed.
Best regards, Sarah Smith
---
Reference: TKT-2024-001
```

### 错误示例（重复）

**消息编辑器中写的内容**：
```
Hello John, Thank you for contacting us...
Best regards, Sarah
```

**客户收到的邮件（出现不必要的重复）**：
```
Dear John,
Hello John, Thank you for contacting us...
Best regards, Sarah
Best regards, Sarah Smith
---
Reference: TKT-2024-001
```

## 适配不同模板配置

- **无问候语的模板**：在消息正文中包含自己的问候
- **仅含内容占位符的模板**：写完整邮件包括问候和结束语
- **自定义模板**：查看当前活跃的模板配置，了解哪些元素是自动包含的
