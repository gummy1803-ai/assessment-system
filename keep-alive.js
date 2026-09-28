/**
 * Supabase 保活脚本
 * 定时向 Supabase 发送请求，防止免费版项目因 7 天无活动而休眠
 *
 * 配置已统一放在 config.js，无需在此重复填写
 * 配合 Windows 任务计划程序每天运行一次：node keep-alive.js
 */

const https = require('https');
const cfg = require('./config');

function keepAlive() {
  return new Promise((resolve, reject) => {
    const url = `${cfg.url}/rest/v1/cadres?select=id&limit=1`;

    const req = https.get(url, {
      headers: {
        'apikey': cfg.anonKey,
        'Authorization': `Bearer ${cfg.anonKey}`
      }
    }, (res) => {
      res.resume();
      const time = new Date().toLocaleString('zh-CN');
      console.log(`[${time}] 保活请求完成，状态码: ${res.statusCode}`);
      resolve(res.statusCode === 200);
    });

    req.on('error', (err) => {
      console.error(`[${new Date().toLocaleString('zh-CN')}] 保活失败: ${err.message}`);
      reject(err);
    });

    req.setTimeout(10000, () => {
      req.destroy();
      reject(new Error('请求超时'));
    });
  });
}

keepAlive().catch(() => process.exit(1));
