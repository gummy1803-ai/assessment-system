# 干部考核管理系统 - 数据同步服务器

## 系统概述

本项目为干部考核管理系统提供了一个数据同步服务器，允许将本地数据同步到中央服务器，实现多设备数据共享和备份。

## 服务器功能

- ✅ 数据同步：支持将本地数据上传到服务器和从服务器下载最新数据
- ✅ 自动同步：每5分钟自动从服务器同步最新数据
- ✅ 手动同步：可随时手动触发数据同步
- ✅ 密码管理：管理员密码也会同步到服务器
- ✅ 数据备份：所有数据安全存储在SQLite数据库中

## 安装和配置

### 1. 安装Node.js

首先需要安装Node.js环境：

1. 访问Node.js官方网站：https://nodejs.org/zh-cn/
2. 下载并安装LTS版本（长期支持版本）
3. 安装完成后，打开命令提示符验证安装：
   ```bash
   node --version
   npm --version
   ```

### 2. 安装依赖

在项目目录中打开命令提示符，运行以下命令安装依赖：

```bash
npm install
```

### 3. 启动服务器

安装完成后，运行以下命令启动服务器：

```bash
npm start
```

服务器将在 http://localhost:3000 上运行

## 使用说明

### 1. 启动服务器

每次使用前需要先启动服务器：

```bash
cd 项目目录
npm start
```

### 2. 使用考核系统

直接在浏览器中打开 `cadre-assessment.html` 文件即可使用系统。系统会自动检测服务器状态并进行数据同步。

### 3. 数据同步

- **自动同步**：系统每5分钟会自动从服务器同步最新数据
- **手动同步**：可以通过控制台手动调用 `manualSync()` 函数进行同步
- **数据修改**：所有本地数据修改都会自动上传到服务器

### 4. 服务器状态检查

可以在浏览器控制台中运行以下命令检查服务器状态：

```javascript
checkServerStatus()
```

## 服务器API

服务器提供以下API接口：

- `GET /api/sync/all` - 获取所有数据
- `POST /api/sync/upload` - 批量上传数据
- `DELETE /api/sync/clear` - 清除所有数据
- `GET /api/cadres` - 获取干部列表
- `POST /api/cadres` - 添加/更新干部
- `DELETE /api/cadres/:id` - 删除干部
- 以及其他针对比赛成绩、协会贡献、新生指导和职责扣分的API

## 数据结构

### 干部数据
```javascript
{
  id: "唯一标识",
  name: "姓名",
  department: "部门",
  position: "职务",
  major: "专业",
  class: "班级",
  grade: "级数",
  equipmentScore: "设备掌控分数"
}
```

### 比赛成绩
```javascript
{
  id: "唯一标识",
  cadreId: "干部ID",
  name: "比赛名称",
  level: "级别",
  award: "奖项",
  score: "分数"
}
```

### 协会贡献
```javascript
{
  id: "唯一标识",
  cadreId: "干部ID",
  type: "贡献类型",
  count: "次数",
  totalScore: "总分"
}
```

### 新生指导
```javascript
{
  id: "唯一标识",
  cadreId: "干部ID",
  traineeName: "新生姓名",
  hours: "培训时长",
  score: "分数"
}
```

### 职责扣分
```javascript
{
  id: "唯一标识",
  cadreId: "干部ID",
  score: "扣分",
  reason: "原因"
}
```

## 故障排除

### 服务器连接失败
- 确保服务器已经启动
- 检查防火墙设置，确保端口3000已开放
- 检查网络连接

### 数据同步失败
- 检查服务器日志，查看具体错误信息
- 确保本地数据格式正确
- 尝试重新启动服务器和刷新页面

### 依赖安装失败
- 确保网络连接正常
- 尝试使用 `npm cache clean --force` 清理缓存后重新安装
- 检查Node.js版本是否兼容

## 注意事项

1. 首次使用时，服务器会自动创建数据库文件 `cadre_assessment.db`
2. 数据库文件包含所有数据，建议定期备份
3. 默认管理员密码为 "123456"，首次登录后请修改密码
4. 服务器支持多用户同时访问，但建议避免多人同时编辑同一数据

## 技术栈

- **前端**：HTML, CSS, JavaScript
- **后端**：Node.js, Express
- **数据库**：SQLite
- **依赖**：cors, body-parser, sqlite3

## 许可证

MIT License