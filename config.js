/* ============================================================================
 * 干部考核管理系统 - Supabase 配置文件
 *
 * 只需填写下面两项（在 Supabase Dashboard → Settings → API 中查看）：
 *   url     : Project URL，形如 https://xxxxxxxxxxxx.supabase.co
 *   anonKey : anon public 密钥（公开安全，前端使用的就是它）
 *
 * 本文件同时被浏览器（index.html）和 Node.js（keep-alive.js）使用，请勿改名
 * ========================================================================== */

const SUPABASE_CONFIG = {
  url: 'https://hkfrovwhvygdxuvqfohw.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhrZnJvdndodnlnZHh1dnFmb2h3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAzMDEyOTksImV4cCI6MjEwNTg3NzI5OX0.dXOFcpGQAjuTI_EZHF47KbHMfGNJQUC_oUeet3I9wSI'
};

// AI 视觉识别配置（智能导入页 import.html 使用，OpenAI 兼容接口）
// 默认智谱 GLM-4V-Flash（免费）：https://open.bigmodel.cn 注册 → 创建 API Key → 填入 apiKey
// 也可换成硅基流动等任何支持图片的 OpenAI 兼容接口
const AI_CONFIG = {
  url: 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
  apiKey: '5abdfe531e554b7c91208fb1555bf8d9.2Cb0ZD1BDNFRE2G3',
  model: 'glm-4v-flash'
};

// 浏览器环境
if (typeof window !== 'undefined') {
  window.SUPABASE_CONFIG = SUPABASE_CONFIG;
  window.AI_CONFIG = AI_CONFIG;
}
// Node.js 环境
if (typeof module !== 'undefined' && module.exports) {
  module.exports = SUPABASE_CONFIG;
}
