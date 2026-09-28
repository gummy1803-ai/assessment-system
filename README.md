# 干部考核管理系统

> 版本：2.0（云端版）  更新日期：2026-09-28

## 系统概述

面向协会/学生组织的多维度量化考核系统。采用纯前端 + 云数据库架构，支持浏览器访问、实时同步、AI 图片识别入库。

## 技术栈

| 层级 | 技术 |
|------|------|
| 前端 | 原生 HTML / CSS / JavaScript（无框架依赖） |
| 数据库 | Supabase（PostgreSQL + RLS 行级安全） |
| 文件存储 | Supabase Storage（图片存档） |
| 静态托管 | 腾讯云 COS 静态网站 |
| AI 识别 | 智谱 GLM-4V-Flash（免费视觉模型） |
| Excel 解析 | SheetJS（浏览器端） |

## 部署方式

仅需上传 3 个文件到腾讯云 COS 存储桶根目录：

1. `index.html` — 主系统
2. `config.js` — Supabase/AI 配置
3. `import.html` — 智能导入工作台

（`背景图.jpg` 为装饰素材，可选）

数据库结构通过 `supabase-schema.sql` 在 Supabase Dashboard 的 SQL Editor 中执行，可重复执行（幂等）。

## 核心功能

- **5 维评分**：部门职责、比赛成绩、协会贡献、设备掌控、新生指导
- **密码鉴权**：查看模式（匿名可读）/ 编辑模式（密码校验 RPC）
- **实时同步**：Supabase Realtime，多人同时使用即时同步
- **Excel 导入**：人员名册、设备分批量导入（浏览器端解析，数据不上传第三方）
- **智能导入**：拍奖状/值班表/名单照片，AI 自动识别字段并入库
- **批量设置**：勾选成员，一次性统一设置专业/班级/年级
- **表单式规则编辑**：计分规则可视化调整，每种贡献类型独立分值
- **数据备份**：JSON 导出/导入（追加更新模式，不删除已有数据）

## 项目结构

```
assessment/
├── index.html              # 主系统（单文件，含全部 UI 和逻辑）
├── import.html             # 智能导入工作台（AI 图片识别）
├── config.js               # Supabase 连接配置 + AI API 配置
├── supabase-schema.sql     # 数据库结构（建表、RLS、RPC 函数）
├── 背景图.jpg               # 页面背景图
├── 使用说明.md             # 用户使用文档
├── README.md               # 本文件
├── keep-alive.js           # Supabase 休眠保活脚本（可选）
└── server.js               # 旧版本地服务器（已弃用，保留作参考）
```

## 配置说明

`config.js` 中需配置：

```javascript
const SUPABASE_CONFIG = {
    url: 'https://xxx.supabase.co',
    anonKey: 'eyJhbGc...'
};

const AI_CONFIG = {
    url: 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
    apiKey: '你的智谱API Key',
    model: 'glm-4v-flash'
};
```

## 安全机制

- 数据库 RLS 策略：匿名用户只能读，写操作全部通过 `verify_admin_password` 校验的 RPC 函数
- 密码存储：bcrypt（`crypt() + gen_salt('bf')`），不明文存储
- 防刷分校验：前后端双重校验（贡献次数≤100、培训时长≤100h、单次扣分≤1000）
- 审计日志：所有写操作自动记录到 `audit_logs` 表

## 许可证

MIT License
