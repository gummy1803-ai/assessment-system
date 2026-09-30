-- ============================================================
-- 六维考核系统 测试数据 + 验算脚本（最终版权重 A15/B20/C20/D15/E10/F20）
-- 依据：重构方案文档第 15 章 15.5 完整结算案例
-- 用法：Supabase Dashboard SQL Editor 整段粘贴执行
-- 幂等：开头先清空旧测试数据，可重复执行
-- 期望输出：测试同学甲 综合总分 = 65.35，等级=一般
-- 注意：插入段用 DO 块（不返回结果集），保证 Results 面板只显示最后的验算行
-- ============================================================

-- ============================================================
-- 0. 清空旧测试数据（幂等）
-- ============================================================
delete from public.score_records where created_by = 'test-verify';
delete from public.deduction_records where created_by = 'test-verify';
delete from public.cadres where name = '测试同学甲';

-- ============================================================
-- 1. 测试成员
-- ============================================================
insert into public.cadres (name, department, position, major, class, grade, equipment_score)
values ('测试同学甲', '技术部', '干事', '电气工程及其自动化', '1班', '2023', 0);

-- ============================================================
-- 2. 插入 26 条加分记录 + 2 条扣分记录（DO 块，无返回结果集）
-- ============================================================
do $$
begin
  -- 加分记录：每分项 1 条，名义分值不超过该分项 max
  insert into public.score_records (member_id, dim_code, item_code, activity_name, task_desc, output_desc, evidence_ref, nominal_score, status, created_by)
  select
    m.id,
    t.dim_code::char,
    t.item_code,
    t.activity_name,
    t.task_desc,
    t.output_desc,
    t.evidence_ref,
    t.nominal_score,
    'approved',
    'test-verify'
  from (select id from public.cadres where name = '测试同学甲' limit 1) m
  cross join (values
    -- A 智慧学习 目标正向分 72
    ('A','A1','AI 应用作业','完成 4 次 AI 应用任务','4 份作业','作业档案/2026-09', 20),
    ('A','A2','专业课程','主修课程','期末成绩 75','教务系统截图',     15),
    ('A','A3','办公数据处理','处理 3 类数据','3 份数据表','数据档案', 15),
    ('A','A4','多媒体作品','制作 5 个多媒体','5 份作品','作品库',       10),
    ('A','A6','实践课程贡献','协助实验课','4 次实验课','签到表',        12),
    -- B 学科竞赛 目标正向分 58
    ('B','B1','省级竞赛参赛','2 次参赛+1 参赛奖','完成 3 次','证书',     15),
    ('B','B2','省级竞赛获奖','省一等奖','提交作品','获奖证书',          20),
    ('B','B3','技术贡献','二档贡献','提供技术方案','评审记录',           8),
    ('B','B4','跨学科整合','1 次整合','跨学科项目','项目报告',           15),
    -- C 实践能力 目标正向分 80
    ('C','C1','安全知识','理论+实操+记录','通过考核','安全考核记录',     25),
    ('C','C2','设备工艺','5 次设备操作','5 次操作','操作日志',            20),
    ('C','C3','CAD/CAE/CAM','3 次 CAD 制图','3 张图纸','图纸库',          15),
    ('C','C4','实验数据','2 次数据采集','2 份数据','实验报告',            10),
    ('C','C5','设备维护改进','2 次设备维护','2 次修复','维修记录',         10),
    -- D 团队协作 目标正向分 65
    ('D','D1','任务交付','完成 8 个任务','8 个交付物','交付清单',         25),
    ('D','D2','组织协调','1 次大型协调','组织活动','活动照片',            20),
    ('D','D3','沟通展示','3 次主讲','3 次演讲','演讲视频',                15),
    ('D','D4','共同活动','1 次共同活动','团队活动','活动记录',             5),
    -- E 研究创新 目标正向分 40
    ('E','E1','课题方案设计','2 份研究方案','2 个方案','方案文档',         10),
    ('E','E2','学术论文','成稿 1 篇+录用','1 篇录用论文','录用通知',       15),
    ('E','E3','知识产权(专利)','1 项受理专利','申请专利','受理通知书',     10),
    ('E','E4','研究报告','1 份完成报告','提交报告','报告归档',              5),
    -- F 履职助新 目标正向分 74
    ('F','F1','岗位服务','7 次常规+4 次复杂','完成 11 次','值班表',       30),
    ('F','F2','带新培训','主讲 4 次','4 次培训','培训记录',              20),
    ('F','F3','资料传承','3 档资料','整理资料','资料库',                  15),
    ('F','F4','服务改进','二档改进','提出改进','改进方案',                 9)
  ) as t(dim_code, item_code, activity_name, task_desc, output_desc, evidence_ref, nominal_score);

  -- 扣分记录：K1→F 扣 3，K6→C 扣 5
  insert into public.deduction_records (member_id, item_code, target_dim_code, event_date, fact_desc, clause_ref, told_date, member_statement, nominal_deduction, status, created_by)
  select
    m.id,
    t.item_code,
    t.target_dim_code::char,
    t.event_date::date,
    t.fact_desc,
    t.clause_ref,
    t.told_date::date,
    t.member_statement,
    t.nominal_deduction,
    'approved',
    'test-verify'
  from (select id from public.cadres where name = '测试同学甲' limit 1) m
  cross join (values
    ('K1','F','2026-09-10','值班迟到 3 次','考勤记录','2026-09-12','已确认', 3),
    ('K6','C','2026-09-15','未戴护目镜','安全规程第 5 条','2026-09-15','已签收', 5)
  ) as t(item_code, target_dim_code, event_date, fact_desc, clause_ref, told_date, member_statement, nominal_deduction);
end $$;

-- ============================================================
-- 3. 验算（独立语句：READ COMMITTED 下能看到上面插入的行）
-- ============================================================
with
  -- 聚合加分：每分项累计 nominal_score 封顶到该分项 max
  item_scores as (
    select
      s.member_id,
      s.dim_code,
      s.item_code,
      -- 分项累计封顶：min(sum(nominal_score), 该分项 max)
      least(
        sum(s.nominal_score),
        coalesce(((r.value)::jsonb #>> array['dimensions', s.dim_code::text, 'items', s.item_code, 'max'])::numeric, 100)
      ) as capped_item_score
    from public.score_records s
    cross join lateral (select value from public.settings where key = 'sixDimRules' limit 1) r
    where s.created_by = 'test-verify'
      and s.status = 'approved'
    group by s.member_id, s.dim_code, s.item_code, r.value
  ),
  -- 维度正向分：Σ 分项封顶分，再封顶到维度 max=100
  dim_positive as (
    select
      member_id,
      dim_code,
      least(sum(capped_item_score), 100) as positive
    from item_scores
    group by member_id, dim_code
  ),
  -- 维度扣分合计：按 target_dim_code 聚合
  dim_deduction as (
    select
      d.target_dim_code as dim_code,
      sum(d.nominal_deduction) as total_deduction
    from public.deduction_records d
    where d.created_by = 'test-verify'
      and d.status = 'approved'
    group by d.target_dim_code
  ),
  -- 维度净分 = max(0, 正向分 - 扣分)
  dim_net as (
    select
      p.member_id,
      p.dim_code,
      p.positive,
      coalesce(dd.total_deduction, 0) as deduction,
      greatest(0, p.positive - coalesce(dd.total_deduction, 0)) as net
    from dim_positive p
    left join dim_deduction dd on dd.dim_code = p.dim_code
  )
-- 输出验算结果
select
  c.name as 成员,
  string_agg(
    dn.dim_code || '=' || dn.positive::text ||
    case when dn.deduction > 0 then '-' || dn.deduction::text || '=' || dn.net::text
         else '=' || dn.net::text end,
    ' / ' order by dn.dim_code
  ) as 六维净分,
  -- 综合总分 = Σ 净分 × 权重
  round(
    sum(
      dn.net *
      coalesce(((r.value)::jsonb #>> array['dimensions', dn.dim_code::text, 'weight'])::numeric, 0)
    )::numeric,
    2
  ) as 综合总分,
  case
    when sum(dn.net * coalesce(((r.value)::jsonb #>> array['dimensions', dn.dim_code::text, 'weight'])::numeric, 0))::numeric >= 85 then '优秀'
    when sum(dn.net * coalesce(((r.value)::jsonb #>> array['dimensions', dn.dim_code::text, 'weight'])::numeric, 0))::numeric >= 70 then '良好'
    when sum(dn.net * coalesce(((r.value)::jsonb #>> array['dimensions', dn.dim_code::text, 'weight'])::numeric, 0))::numeric >= 50 then '一般'
    else '待改进'
  end as 等级
from dim_net dn
join public.cadres c on c.id = dn.member_id
cross join lateral (select value from public.settings where key = 'sixDimRules' limit 1) r
group by c.name;

-- 期望输出（最终版权重 A15/B20/C20/D15/E10/F20）：
--   成员=测试同学甲
--   六维净分: A=72 / B=58 / C=80-5=75 / D=65 / E=40 / F=74-3=71
--   综合总分: 65.35
--   等级: 一般
