/* ============================================================================
 * 干部考核管理系统 - 配置模板
 *
 * 使用方法：复制本文件并重命名为 config.js，然后填入真实配置
 *   1. Supabase 配置：Dashboard → Settings → API 中查看 url 和 anon key
 *   2. AI 配置：https://open.bigmodel.cn 注册 → 创建 API Key
 *
 * config.js 已在 .gitignore 中排除，不会被上传到代码仓库
 * ========================================================================== */

const SUPABASE_CONFIG = {
  url: 'https://你的项目ID.supabase.co',
  anonKey: '在此填入你的Supabase_anon_public密钥'
};

// AI 视觉识别配置（智能导入页 import.html 使用，OpenAI 兼容接口）
const AI_CONFIG = {
  url: 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
  apiKey: '在此填入你的智谱API_Key',
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
