// 一致性校验脚本：对比 SQL 种子 / index.html DEFAULT_RULES / import.html SIX_DIMS，
// 并用 index.html 同款公式对 test-data-verify.sql 的数据模拟计分，验证 65.35。
const fs = require('fs');
const base = 'd:/Users/许家铭/Desktop/assessment-system-main/assessment/';

// ---------- 1. 提取 SQL 种子 JSON ----------
function extractSeed(file) {
    const txt = fs.readFileSync(base + file, 'utf8');
    const m = txt.match(/'sixDimRules',\s*'([\s\S]*?)'::jsonb\)/);
    if (!m) throw new Error('seed not found in ' + file);
    return JSON.parse(m[1]);
}
const migRules = extractSeed('supabase-migration-sixdim.sql');
const schemaRules = extractSeed('supabase-schema.sql');

// ---------- 2. 提取 index.html DEFAULT_RULES ----------
const idxTxt = fs.readFileSync(base + 'index.html', 'utf8');
const dStart = idxTxt.indexOf('const DEFAULT_RULES = {');
const dEnd = idxTxt.indexOf('};', dStart);
const frontRules = eval('(' + idxTxt.slice(dStart + 'const DEFAULT_RULES = '.length, dEnd + 1) + ')');

// ---------- 3. 提取 import.html SIX_DIMS + DEDUCTION_ITEMS ----------
const impTxt = fs.readFileSync(base + 'import.html', 'utf8');
const sStart = impTxt.indexOf('const SIX_DIMS = {');
const sEnd = impTxt.indexOf('};', sStart);
const importDims = eval('(' + impTxt.slice(sStart + 'const SIX_DIMS = '.length, sEnd + 1) + ')');
const kStart = impTxt.indexOf('const DEDUCTION_ITEMS = {');
const kEnd = impTxt.indexOf('};', kStart);
const importDeduc = eval('(' + impTxt.slice(kStart + 'const DEDUCTION_ITEMS = '.length, kEnd + 1) + ')');

// ---------- 4. 对比维度/权重/分项上限 ----------
let errors = [];
function cmp(label, a, b) {
    if (JSON.stringify(a) !== JSON.stringify(b)) errors.push(`${label}: ${JSON.stringify(a)} != ${JSON.stringify(b)}`);
}
const DIMS = ['A','B','C','D','E','F'];
let wSum = 0;
for (const d of DIMS) {
    const m = migRules.dimensions[d], s = schemaRules.dimensions[d], f = frontRules.dimensions[d], i = importDims[d];
    if (!m || !s || !f || !i) { errors.push(`${d}: 某文件缺维度`); continue; }
    wSum += m.weight;
    cmp(`${d}.weight mig/schema`, m.weight, s.weight);
    cmp(`${d}.weight mig/front`, m.weight, f.weight);
    cmp(`${d}.name mig/front`, m.name, f.name);
    cmp(`${d}.name mig/import`, m.name, i.name);
    // 分项集合
    const mk = Object.keys(m.items).sort(), sk = Object.keys(s.items).sort(),
          fk = Object.keys(f.items).sort(), ik = Object.keys(i.items).sort();
    cmp(`${d}.items mig/schema`, mk, sk);
    cmp(`${d}.items mig/front`, mk, fk);
    cmp(`${d}.items mig/import`, mk, ik);
    for (const k of mk) {
        cmp(`${d}.${k}.max mig/schema`, m.items[k].max, s.items[k].max);
        cmp(`${d}.${k}.max mig/front`, m.items[k].max, f.items[k].max);
        cmp(`${d}.${k}.max mig/import`, m.items[k].max, i.items[k].max);
        cmp(`${d}.${k}.name mig/front`, m.items[k].name, f.items[k].name);
        cmp(`${d}.${k}.name mig/import`, m.items[k].name, i.items[k].name);
    }
}
console.log('权重合计 =', wSum.toFixed(2), wSum === 1 ? '✓' : '✗ 必须=1.00');

// ---------- 5. 对比扣分项 ----------
const mkK = Object.keys(migRules.deductions).sort();
const skK = Object.keys(schemaRules.deductions).sort();
const fkK = Object.keys(frontRules.deductions).sort();
const ikK = Object.keys(importDeduc).sort();
cmp('K集合 mig/schema', mkK, skK);
cmp('K集合 mig/front', mkK, fkK);
cmp('K集合 mig/import', mkK, ikK);
for (const k of mkK) {
    const m = migRules.deductions[k], s = schemaRules.deductions[k], f = frontRules.deductions[k], i = importDeduc[k];
    cmp(`${k}.perEvent mig/schema`, m.perEvent, s.perEvent);
    cmp(`${k}.perEvent mig/front`, m.perEvent, f.perEvent);
    cmp(`${k}.name mig/front`, m.name, f.name);
    cmp(`${k}.name mig/import`, m.name, i.name);
    cmp(`${k}.fixedDim mig/schema`, m.fixedDim || null, s.fixedDim || null);
    cmp(`${k}.fixedDim mig/front`, m.fixedDim || null, f.fixedDim || null);
    cmp(`${k}.fixedDim mig/import`, m.fixedDim || null, i.fixedDim || null);
    cmp(`${k}.dynamic mig/front`, !!m.dynamicDim, !!f.dynamicDim);
    cmp(`${k}.dynamic mig/import`, !!m.dynamicDim, !!i.dynamic);
}

// ---------- 6. 用前端公式模拟 test-data-verify.sql ----------
// 解析测试 SQL 里的 values 元组
const testTxt = fs.readFileSync(base + 'test-data-verify.sql', 'utf8');
const scoreBlock = testTxt.match(/cross join \(values([\s\S]*?)\) as t\(dim_code/)[1];
const scoreRows = [...scoreBlock.matchAll(/\('([A-F])','([A-F]\d)','[^']*',[^,]*,[^,]*,[^,]*,\s*(\d+)\)/g)]
    .map(m => ({ dim: m[1], item: m[2], score: +m[3] }));
const deducBlock = testTxt.match(/cross join \(values([\s\S]*?)\) as t\(item_code/)[1];
const deducRows = [...deducBlock.matchAll(/\('(K\d+)','([A-F])',[^,]*,[^,]*,[^,]*,[^,]*,[^,]*,\s*(\d+)\)/g)]
    .map(m => ({ item: m[1], dim: m[2], val: +m[3] }));
console.log(`解析到加分 ${scoreRows.length} 条 / 扣分 ${deducRows.length} 条`);

// 复刻 calculateMemberScore
const dimItemSum = {};
for (const r of scoreRows) {
    const key = r.dim + '|' + r.item;
    dimItemSum[key] = (dimItemSum[key] || 0) + r.score;
}
const dedByDim = {}; DIMS.forEach(d => dedByDim[d] = 0);
for (const r of deducRows) dedByDim[r.dim] += r.val;
let total = 0; const nets = {};
for (const d of DIMS) {
    const dimRule = migRules.dimensions[d];
    let pos = 0;
    for (const code of Object.keys(dimRule.items)) {
        pos += Math.min(dimItemSum[d + '|' + code] || 0, dimRule.items[code].max);
    }
    pos = Math.min(pos, dimRule.max);
    nets[d] = Math.max(0, pos - dedByDim[d]);
    total += nets[d] * dimRule.weight;
}
total = Math.round(total * 100) / 100;
console.log('模拟净分:', JSON.stringify(nets));
console.log('模拟综合总分 =', total, total === 65.35 ? '✓ 与期望一致' : '✗ 期望 65.35');

// ---------- 结果 ----------
console.log('\n===== 对比结果 =====');
if (errors.length) { console.log('发现 ' + errors.length + ' 处不一致:'); errors.forEach(e => console.log(' ✗', e)); }
else console.log('全部一致 ✓（4 个文件规则同源）');
