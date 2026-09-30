-- ============================================================
-- 干部考核系统 Supabase 数据库结构（六维版 v3.0 最终态）
-- 依据：V1.1《机电科创特色学生综合能力成长画像建设运行与加减分准则》
-- 适用于全新部署。已有库请按顺序执行：
--   1) supabase-migration-sixdim.sql（增量迁移）
--   2) supabase-migration-cleanup.sql（清理旧 4 表/RPC）
-- 本文件幂等：可重复执行。
-- ============================================================

-- 1. 扩展（密码哈希用） ----------------------------------------------------
create extension if not exists pgcrypto with schema extensions;

-- 2. 业务表 ----------------------------------------------------------------

-- 成员档案：equipment_score 字段保留（clamp 0-100），不再单独录入路径
create table if not exists public.cadres (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    department text default '',
    position text default '',
    major text default '',
    class text default '',
    grade text default '',
    equipment_score numeric default 0 check (equipment_score between 0 and 100),
    created_at timestamptz default now()
);

-- 加分记录统一表（六维 A-F × 各分项）
create table if not exists public.score_records (
    id uuid primary key default gen_random_uuid(),
    member_id uuid references public.cadres(id) on delete cascade,
    dim_code char(1) not null check (dim_code in ('A','B','C','D','E','F')),
    item_code text not null,                         -- A1-A6/B1-B4/C1-C5/D1-D4/E1-E5/F1-F4
    activity_name text default '',
    activity_date date,
    task_desc text default '',                       -- 本人承担任务
    output_desc text default '',                     -- 实际输出
    evidence_ref text default '',                     -- 证据名称及位置
    nominal_score numeric not null default 0,        -- 名义分值（不存 actual_score，读取时按当前规则算）
    status text default 'approved',                 -- MVP 简化审核流：默认已通过
    created_by text default '',
    created_at timestamptz default now()
);

create index if not exists idx_score_records_member on public.score_records(member_id);
create index if not exists idx_score_records_dim_item on public.score_records(dim_code, item_code);

-- 扣分记录表（K1-K12，target_dim_code 必填；K9/K10 动态归属，其余固定）
create table if not exists public.deduction_records (
    id uuid primary key default gen_random_uuid(),
    member_id uuid references public.cadres(id) on delete cascade,
    item_code text not null,                         -- K1-K12
    target_dim_code char(1) not null check (target_dim_code in ('A','B','C','D','E','F')),
    event_date date,
    fact_desc text default '',                       -- 事实描述
    clause_ref text default '',                      -- 适用条款
    told_date date,                                  -- 告知本人日期
    member_statement text default '',                -- 本人陈述
    nominal_deduction numeric not null default 0,
    status text default 'approved',
    created_by text default '',
    created_at timestamptz default now()
);

create index if not exists idx_deduction_records_member on public.deduction_records(member_id);
create index if not exists idx_deduction_records_target_dim on public.deduction_records(target_dim_code);

-- 通用设置表
create table if not exists public.settings (
    key text primary key,
    value jsonb,
    updated_at timestamptz default now()
);

-- 审计日志
create table if not exists public.audit_logs (
    id bigserial primary key,
    action text not null,
    table_name text default '',
    detail jsonb,
    created_at timestamptz default now()
);

-- 图片存档表（智能导入用）
create table if not exists public.import_images (
    id uuid primary key default gen_random_uuid(),
    cadre_id uuid references public.cadres(id) on delete set null,
    description text default '',
    ai_summary text default '',
    storage_path text default '',
    public_url text default '',
    record_table text default '',                     -- score_records / deduction_records / cadres
    record_id uuid,
    created_at timestamptz default now()
);

-- 3. 设置种子 --------------------------------------------------------------
-- sixDimRules：六维完整结构 + 扣分项 + 等级阈值（29 加分项 + 12 扣分项）
-- adminPasswordHash：首次改密时由 change_admin_password 生成，不在此预设
insert into public.settings (key, value) values
('sixDimRules', '{
  "dimensions": {
    "A": {"name":"智慧学习","weight":0.15,"max":100,
          "items":{"A1":{"name":"AI应用","max":20,"perItem":5,"maxCount":4},
                   "A2":{"name":"专业课程","max":20,"formula":"grade*0.20"},
                   "A3":{"name":"办公与数据工具","max":15,"perItem":5,"maxCount":3},
                   "A4":{"name":"多媒体制作","max":10,"perItem":2,"maxCount":5},
                   "A5":{"name":"科技文档","max":15,"perItem":3,"maxCount":5},
                   "A6":{"name":"实践课程建设","max":20,"perItem":5,"maxCount":4}}},
    "B": {"name":"学科竞赛","weight":0.20,"max":100,
          "items":{"B1":{"name":"有效参赛","max":20,"note":"报名+任务5，完赛再5，每项目≤10"},
                   "B2":{"name":"竞赛获奖","max":30,
                         "tiers":{"国家级":{"一":30,"二":24,"三":18},
                                  "省级":{"一":20,"二":15,"三":10},
                                  "市级":{"一":12,"二":8,"三":5},
                                  "校级":{"一":6,"二":4,"三":2}},
                         "note":"升级补差"},
                   "B3":{"name":"技术贡献","max":30,"tiers":{"模块":5,"子系统":10,"关键系统":15}},
                   "B4":{"name":"跨学科整合","max":20,"perItem":10,"maxCount":2}}},
    "C": {"name":"实践能力","weight":0.20,"max":100,
          "items":{"C1":{"name":"安全知识与习惯","max":25,"parts":{"理论":10,"实操":10,"操作日":5}},
                   "C2":{"name":"设备与工艺操作","max":25,"perItem":5,"maxCount":5},
                   "C3":{"name":"CAD/CAE/CAM","max":20,"perItem":5,"maxCount":4},
                   "C4":{"name":"实验与数据分析","max":20,"perItem":5,"maxCount":4},
                   "C5":{"name":"设备维护与改进更新","max":10,"perItem":5,"maxCount":2}}},
    "D": {"name":"团队协作","weight":0.15,"max":100,
          "items":{"D1":{"name":"团队任务交付","max":30,"perItem":3,"maxCount":10},
                   "D2":{"name":"团队组织协调","max":20,"perItem":5,"altPerItem":10},
                   "D3":{"name":"团队沟通与展示","max":20,"perItem":5,"altPerItem":2},
                   "D4":{"name":"协会共同活动","max":15,"tiers":{"参与":1,"服务":3,"主要组织":5}},
                   "D5":{"name":"协会团建活动","max":15,"note":"小型:参与1/发起主持2；中型:参与1/服务3/组织5；大型:参与2/服务4/组织8；取最高角色计一次"}}},
    "E": {"name":"研究创新","weight":0.10,"max":100,
          "items":{"E1":{"name":"课题方案设计","max":20,"perItem":5,"maxCount":4},
                   "E2":{"name":"学术论文","max":20,"tiers":{"成稿":10,"录用":15,"发表":20},"note":"取最高档"},
                   "E3":{"name":"知识产权(专利)","max":15,"tiers":{"交底":5,"受理":8,"授权":15}},
                   "E4":{"name":"研究报告(设计说明书)","max":30,"perItem":5,"altPerItem":10,"note":"完成5/份，评审通过或采用10/份"},
                   "E5":{"name":"成果转化","max":15,"tiers":{"试用":5,"采用":10,"有效果":15}}}},
    "F": {"name":"履职助新","weight":0.20,"max":100,
          "items":{"F1":{"name":"部门岗位与服务任务","max":35,"perItem":2,"altPerItem":4},
                   "F2":{"name":"带新与培训","max":25,"roles":{"主讲":5,"助教":2,"效果加成":2}},
                   "F3":{"name":"资料与经验传承","max":15,"perItem":3,"altPerItem":5},
                   "F4":{"name":"服务改进","max":10,"tiers":{"采纳":2,"实施":5,"有效果":10}},
                   "F5":{"name":"协会宣传与推广","max":15,"note":"转发0.5(≤5)；原创3+达标2(≤10)；发布:协会/学院5、校级8、市级及以上10取最高；专项宣传5；总上限15，不重复计分"}}}
  },
  "deductions": {
    "K1":{"name":"无故迟到/早退","perEvent":1,"fixedDim":"F"},
    "K2":{"name":"无故缺席","perEvent":3,"fixedDim":"F"},
    "K3":{"name":"未履行承诺任务","perEvent":3,"altPerEvent":5,"fixedDim":"F"},
    "K4":{"name":"逾期归还物资","perEvent":1,"altPerEvent":3,"fixedDim":"F"},
    "K5":{"name":"私自外借物资","perEvent":5,"fixedDim":"F"},
    "K6":{"name":"违反安全操作","perEvent":5,"altPerEvent":10,"fixedDim":"C"},
    "K7":{"name":"隐瞒设备损坏丢失","perEvent":5,"fixedDim":"C"},
    "K8":{"name":"代签/虚假出勤","perEvent":10,"fixedDim":"F"},
    "K9":{"name":"伪造篡改证明","perEvent":10,"dynamicDim":true},
    "K10":{"name":"冒领他人成果","perEvent":10,"dynamicDim":true},
    "K11":{"name":"未按规定着装或防护","perEvent":2,"fixedDim":"C"},
    "K12":{"name":"离开未关电关灯","perEvent":2,"fixedDim":"F"}
  },
  "levels":[{"name":"优秀","min":85},{"name":"良好","min":70},{"name":"一般","min":50},{"name":"待改进","min":0}]
}'::jsonb)
on conflict (key) do update set value = excluded.value;

-- 4. RLS：匿名可读，写操作一律走 RPC ---------------------------------------

alter table public.cadres enable row level security;
alter table public.score_records enable row level security;
alter table public.deduction_records enable row level security;
alter table public.settings enable row level security;
alter table public.audit_logs enable row level security;
alter table public.import_images enable row level security;

drop policy if exists "public read cadres" on public.cadres;
create policy "public read cadres" on public.cadres
    for select to anon, authenticated using (true);
drop policy if exists "public read score_records" on public.score_records;
create policy "public read score_records" on public.score_records
    for select to anon, authenticated using (true);
drop policy if exists "public read deduction_records" on public.deduction_records;
create policy "public read deduction_records" on public.deduction_records
    for select to anon, authenticated using (true);
drop policy if exists "public read settings" on public.settings;
create policy "public read settings" on public.settings
    for select to anon, authenticated using (true);
drop policy if exists "public read audit_logs" on public.audit_logs;
create policy "public read audit_logs" on public.audit_logs
    for select to anon, authenticated using (true);
drop policy if exists "public read import_images" on public.import_images;
create policy "public read import_images" on public.import_images
    for select to anon, authenticated using (true);

-- 5. RPC 函数 --------------------------------------------------------------

create or replace function public.verify_admin_password(p_password text)
returns boolean language plpgsql security definer set search_path = public, extensions as $$
declare v_hash text;
begin
    select value->>'adminPasswordHash' into v_hash from public.settings where key = 'adminPasswordHash';
    if v_hash is null then
        return p_password = '123456';  -- 初始默认密码
    end if;
    return v_hash = crypt(p_password, v_hash);
end $$;

create or replace function public.change_admin_password(p_old_password text, p_new_password text)
returns void language plpgsql security definer set search_path = public, extensions as $$
declare v_hash text;
begin
    if p_new_password is null or length(p_new_password) < 4 then
        raise exception '新密码至少4位';
    end if;
    select value->>'adminPasswordHash' into v_hash from public.settings where key = 'adminPasswordHash';
    if v_hash is not null and v_hash <> crypt(p_old_password, v_hash) then
        raise exception '原密码错误';
    end if;
    insert into public.settings (key, value)
    values ('adminPasswordHash', jsonb_build_object('adminPasswordHash', crypt(p_new_password, gen_salt('bf'))))
    on conflict (key) do update set value = excluded.value, updated_at = now();
    insert into public.audit_logs (action, table_name, detail)
    values ('change_admin_password', 'settings', '{}');
end $$;

-- upsert_cadre：equipment_score clamp 0-100（六维系统保留字段）
create or replace function public.upsert_cadre(p_password text default null, p_cadre jsonb)
returns public.cadres language plpgsql security definer set search_path = public, extensions as $$
declare v_id uuid; v_row public.cadres;
begin
    if not public.verify_admin_password(p_password) then
        raise exception '管理员密码错误';
    end if;
    if coalesce(p_cadre->>'name','') = '' then
        raise exception '干部姓名不能为空';
    end if;
    v_id := nullif(p_cadre->>'id','');
    if v_id is not null and not exists (select 1 from public.cadres where id = v_id) then
        v_id := null;
    end if;
    if v_id is null then
        insert into public.cadres (name, department, position, major, class, grade, equipment_score)
        values (p_cadre->>'name', coalesce(p_cadre->>'department',''), coalesce(p_cadre->>'position',''),
                coalesce(p_cadre->>'major',''), coalesce(p_cadre->>'class',''), coalesce(p_cadre->>'grade',''),
                least(greatest(coalesce((p_cadre->>'equipment_score')::numeric,0),0),100))
        returning * into v_row;
    else
        update public.cadres set
            name = coalesce(p_cadre->>'name', name),
            department = coalesce(p_cadre->>'department', department),
            position = coalesce(p_cadre->>'position', position),
            major = coalesce(p_cadre->>'major', major),
            class = coalesce(p_cadre->>'class', class),
            grade = coalesce(p_cadre->>'grade', grade),
            equipment_score = least(greatest(coalesce((p_cadre->>'equipment_score')::numeric, equipment_score),0),100)
        where id = v_id returning * into v_row;
    end if;
    insert into public.audit_logs (action, table_name, detail)
    values ('upsert_cadre', 'cadres', jsonb_build_object('id', v_row.id, 'name', v_row.name));
    return v_row;
end $$;

create or replace function public.delete_cadre(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
    delete from public.cadres where id = p_id;
    if not found then raise exception '所选干部不存在'; end if;
    insert into public.audit_logs (action, table_name, detail)
    values ('delete_cadre', 'cadres', jsonb_build_object('id', p_id));
end $$;

-- add_score_record：密码 + 外键 + 维度码 + 分项码 + 上限校验
create or replace function public.add_score_record(
    p_password text default null,
    p_member_id uuid default null,
    p_dim_code char default null,
    p_item_code text default null,
    p_activity_name text default null,
    p_activity_date date default null,
    p_task_desc text default null,
    p_output_desc text default null,
    p_evidence_ref text default null,
    p_nominal_score numeric default null
) returns public.score_records
language plpgsql security definer set search_path = public, extensions as $$
declare
    v_row public.score_records;
    v_max numeric;
    v_rules jsonb;
begin
    if not public.verify_admin_password(p_password) then
        raise exception '管理员密码错误';
    end if;
    if p_member_id is null or not exists (select 1 from public.cadres where id = p_member_id) then
        raise exception '所选成员不存在';
    end if;
    if p_dim_code is null or p_dim_code !~ '^[ABCDEF]$' then
        raise exception '维度码必须为 A/B/C/D/E/F';
    end if;
    if coalesce(p_item_code,'') !~ '^[A-F][1-9][0-9]?$' then
        raise exception '分项码格式错误（应为 A1-F6 等）';
    end if;
    if coalesce(p_nominal_score,0) < 0 then
        raise exception '名义分值不能为负';
    end if;
    -- 上限校验：sixDimRules.dimensions[dim].items[item].max
    select value into v_rules from public.settings where key = 'sixDimRules';
    if v_rules is not null then
        v_max := (v_rules #>> array['dimensions', p_dim_code::text, 'items', p_item_code, 'max'])::numeric;
        if v_max is not null and p_nominal_score > v_max then
            raise exception '名义分值 % 超过该分项上限 %', p_nominal_score, v_max;
        end if;
    end if;
    insert into public.score_records (
        member_id, dim_code, item_code, activity_name, activity_date,
        task_desc, output_desc, evidence_ref, nominal_score, status, created_by
    ) values (
        p_member_id, p_dim_code, p_item_code,
        coalesce(p_activity_name,''), p_activity_date,
        coalesce(p_task_desc,''), coalesce(p_output_desc,''), coalesce(p_evidence_ref,''),
        coalesce(p_nominal_score,0), 'approved', coalesce(p_password,'')
    ) returning * into v_row;
    insert into public.audit_logs (action, table_name, detail)
    values ('add_score_record', 'score_records',
            jsonb_build_object('id', v_row.id, 'member_id', p_member_id, 'dim', p_dim_code, 'item', p_item_code, 'score', p_nominal_score));
    return v_row;
end $$;

-- add_deduction_record：密码 + 外键 + K 项 + 归属维度 + 扣分上限（≤1000）
create or replace function public.add_deduction_record(
    p_password text default null,
    p_member_id uuid default null,
    p_item_code text default null,
    p_target_dim_code char default null,
    p_event_date date default null,
    p_fact_desc text default null,
    p_clause_ref text default null,
    p_told_date date default null,
    p_member_statement text default null,
    p_nominal_deduction numeric default null
) returns public.deduction_records
language plpgsql security definer set search_path = public, extensions as $$
declare v_row public.deduction_records;
begin
    if not public.verify_admin_password(p_password) then
        raise exception '管理员密码错误';
    end if;
    if p_member_id is null or not exists (select 1 from public.cadres where id = p_member_id) then
        raise exception '所选成员不存在';
    end if;
    if coalesce(p_item_code,'') !~ '^K([1-9]|1[0-2])$' then
        raise exception '扣分项码格式错误（应为 K1-K12）';
    end if;
    if p_target_dim_code is null or p_target_dim_code !~ '^[ABCDEF]$' then
        raise exception '归属维度必须为 A/B/C/D/E/F';
    end if;
    if coalesce(p_nominal_deduction,0) <= 0 then
        raise exception '扣分必须大于0';
    end if;
    if coalesce(p_nominal_deduction,0) > 1000 then
        raise exception '单次扣分不能超过1000分';
    end if;
    insert into public.deduction_records (
        member_id, item_code, target_dim_code, event_date,
        fact_desc, clause_ref, told_date, member_statement, nominal_deduction, status, created_by
    ) values (
        p_member_id, p_item_code, p_target_dim_code, p_event_date,
        coalesce(p_fact_desc,''), coalesce(p_clause_ref,''), p_told_date,
        coalesce(p_member_statement,''), coalesce(p_nominal_deduction,0), 'approved', coalesce(p_password,'')
    ) returning * into v_row;
    insert into public.audit_logs (action, table_name, detail)
    values ('add_deduction_record', 'deduction_records',
            jsonb_build_object('id', v_row.id, 'member_id', p_member_id, 'item', p_item_code, 'target_dim', p_target_dim_code, 'deduction', p_nominal_deduction));
    return v_row;
end $$;

-- delete_record：仅 cadres / score_records / deduction_records 三表
create or replace function public.delete_record(p_table text, p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
    case p_table
        when 'cadres' then delete from public.cadres where id = p_id;
        when 'score_records' then delete from public.score_records where id = p_id;
        when 'deduction_records' then delete from public.deduction_records where id = p_id;
        else raise exception '不允许操作该表';
    end case;
    if not found then raise exception '记录不存在'; end if;
    insert into public.audit_logs (action, table_name, detail)
    values ('delete_record', p_table, jsonb_build_object('id', p_id));
end $$;

-- save_scoring_rules：存储到 sixDimRules 这个 key（保留 RPC 名以兼容前端调用）
create or replace function public.save_scoring_rules(p_rules jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
    insert into public.settings (key, value)
    values ('sixDimRules', p_rules)
    on conflict (key) do update set value = excluded.value, updated_at = now();
    insert into public.audit_logs (action, table_name, detail)
    values ('save_scoring_rules', 'settings', '{}');
end $$;

-- clear_all_data：清空六维新表 + 图片存档 + 成员
create or replace function public.clear_all_data()
returns void language plpgsql security definer set search_path = public as $$
begin
    delete from public.score_records;
    delete from public.deduction_records;
    delete from public.import_images;
    delete from public.cadres;
    insert into public.audit_logs (action, table_name, detail)
    values ('clear_all_data', 'all', '{}');
end $$;

-- save_import_image：智能导入的图片存档登记
create or replace function public.save_import_image(p_password text default null, p_data jsonb)
returns public.import_images language plpgsql security definer set search_path = public as $$
declare v_row public.import_images;
begin
    if not public.verify_admin_password(p_password) then
        raise exception '管理员密码错误';
    end if;
    insert into public.import_images (cadre_id, description, ai_summary, storage_path, public_url, record_table, record_id)
    values (
        nullif(p_data->>'cadre_id','')::uuid,
        coalesce(p_data->>'description',''),
        coalesce(p_data->>'ai_summary',''),
        coalesce(p_data->>'storage_path',''),
        coalesce(p_data->>'public_url',''),
        coalesce(p_data->>'record_table',''),
        nullif(p_data->>'record_id','')::uuid
    ) returning * into v_row;
    return v_row;
end $$;

-- 6. 执行权限 --------------------------------------------------------------

grant execute on function public.verify_admin_password(text) to anon, authenticated;
grant execute on function public.change_admin_password(text, text) to anon, authenticated;
grant execute on function public.upsert_cadre(text, jsonb) to anon, authenticated;
grant execute on function public.delete_cadre(uuid) to anon, authenticated;
grant execute on function public.add_score_record(text, uuid, char, text, text, date, text, text, text, numeric) to anon, authenticated;
grant execute on function public.add_deduction_record(text, uuid, text, char, date, text, text, date, text, numeric) to anon, authenticated;
grant execute on function public.delete_record(text, uuid) to anon, authenticated;
grant execute on function public.save_scoring_rules(jsonb) to anon, authenticated;
grant execute on function public.clear_all_data() to anon, authenticated;
grant execute on function public.save_import_image(text, jsonb) to anon, authenticated;

-- 7. 图片存储桶 -----------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('import-images', 'import-images', true)
on conflict (id) do nothing;

drop policy if exists "import-images public read" on storage.objects;
create policy "import-images public read" on storage.objects
    for select to anon, authenticated using (bucket_id = 'import-images');

drop policy if exists "import-images anon upload" on storage.objects;
create policy "import-images anon upload" on storage.objects
    for insert to anon, authenticated with check (bucket_id = 'import-images');

-- 8. 实时同步 --------------------------------------------------------------

-- 幂等：已在 publication 中则跳过（ADD TABLE 不支持 IF EXISTS，重复执行会报 42710）
do $$
declare
    t text;
begin
    foreach t in array array['cadres','score_records','deduction_records','import_images'] loop
        if not exists (select 1 from pg_publication_tables
                       where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
            execute format('alter publication supabase_realtime add table public.%I', t);
        end if;
    end loop;
end $$;
