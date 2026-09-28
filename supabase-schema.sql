-- ============================================================
-- 干部考核系统 Supabase 数据库结构（重建版 v2）
-- 依据：云端实际运行结构 + 前端代码反推
-- 可重复执行（幂等）。已在生产库验证过的错误提示保持一致。
-- ============================================================

-- 1. 扩展（密码哈希用）
create extension if not exists pgcrypto with schema extensions;

-- 2. 业务表 --------------------------------------------------

create table if not exists public.cadres (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    department text default '',
    position text default '',
    major text default '',
    class text default '',
    grade text default '',
    equipment_score numeric default 0,
    created_at timestamptz default now()
);

create table if not exists public.competitions (
    id uuid primary key default gen_random_uuid(),
    cadre_id uuid references public.cadres(id) on delete cascade,
    name text not null,
    level text default '',
    award text default '',
    score numeric default 0,
    created_at timestamptz default now()
);

create table if not exists public.contributions (
    id uuid primary key default gen_random_uuid(),
    cadre_id uuid references public.cadres(id) on delete cascade,
    type text not null,
    count int not null default 1,
    total_score numeric not null default 0,
    created_at timestamptz default now()
);

create table if not exists public.trainings (
    id uuid primary key default gen_random_uuid(),
    cadre_id uuid references public.cadres(id) on delete cascade,
    trainee_name text not null,
    hours numeric default 1,
    score numeric default 0,
    created_at timestamptz default now()
);

create table if not exists public.deductions (
    id uuid primary key default gen_random_uuid(),
    cadre_id uuid references public.cadres(id) on delete cascade,
    reason text default '',
    score numeric not null default 0,
    created_at timestamptz default now()
);

create table if not exists public.settings (
    key text primary key,
    value jsonb,
    updated_at timestamptz default now()
);

create table if not exists public.audit_logs (
    id bigserial primary key,
    action text not null,
    table_name text default '',
    detail jsonb,
    created_at timestamptz default now()
);

create table if not exists public.import_images (
    id uuid primary key default gen_random_uuid(),
    description text default '',
    ai_summary text default '',
    storage_path text default '',
    public_url text default '',
    record_table text default '',
    record_id uuid,
    created_at timestamptz default now()
);

-- 3. 设置种子（scoringRules；adminPasswordHash 由前端改密流程生成，勿手填）--
insert into public.settings (key, value) values
('scoringRules', '{"baseDutyScore":1000,"contributionPerCount":0.1,"contributionTypeRates":{"卫生":0.1,"整理设备":0.1,"维护耗材":0.1,"设备培训":0.1,"假期值班":0.1},"trainingPerHour":0.5,"levels":[{"name":"优秀","min":1800},{"name":"良好","min":1400},{"name":"合格","min":1000},{"name":"待改进","min":0}],"competitionBonus":{"国家级":200,"省级":100,"市级":50,"校级":30,"院级":10}}')
on conflict (key) do nothing;

-- 4. RLS：匿名可读，写操作一律走 RPC -------------------------

alter table public.cadres enable row level security;
alter table public.competitions enable row level security;
alter table public.contributions enable row level security;
alter table public.trainings enable row level security;
alter table public.deductions enable row level security;
alter table public.settings enable row level security;
alter table public.audit_logs enable row level security;
alter table public.import_images enable row level security;

drop policy if exists "public read cadres" on public.cadres;
create policy "public read cadres" on public.cadres for select to anon, authenticated using (true);
drop policy if exists "public read competitions" on public.competitions;
create policy "public read competitions" on public.competitions for select to anon, authenticated using (true);
drop policy if exists "public read contributions" on public.contributions;
create policy "public read contributions" on public.contributions for select to anon, authenticated using (true);
drop policy if exists "public read trainings" on public.trainings;
create policy "public read trainings" on public.trainings for select to anon, authenticated using (true);
drop policy if exists "public read deductions" on public.deductions;
create policy "public read deductions" on public.deductions for select to anon, authenticated using (true);
drop policy if exists "public read settings" on public.settings;
create policy "public read settings" on public.settings for select to anon, authenticated using (true);
drop policy if exists "public read audit_logs" on public.audit_logs;
create policy "public read audit_logs" on public.audit_logs for select to anon, authenticated using (true);
drop policy if exists "public read import_images" on public.import_images;
create policy "public read import_images" on public.import_images for select to anon, authenticated using (true);

-- 5. RPC 函数 -------------------------------------------------

create or replace function public.verify_admin_password(p_password text)
returns boolean language plpgsql security definer set search_path = public, extensions as $$
declare v_hash text;
begin
    select value->>'adminPasswordHash' into v_hash from settings where key = 'adminPasswordHash';
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
    select value->>'adminPasswordHash' into v_hash from settings where key = 'adminPasswordHash';
    if v_hash is not null and v_hash <> crypt(p_old_password, v_hash) then
        raise exception '原密码错误';
    end if;
    insert into settings (key, value) values ('adminPasswordHash', jsonb_build_object('adminPasswordHash', crypt(p_new_password, gen_salt('bf'))))
    on conflict (key) do update set value = excluded.value, updated_at = now();
    insert into audit_logs (action, table_name, detail) values ('change_admin_password', 'settings', '{}');
end $$;

create or replace function public.upsert_cadre(p_password text default null, p_cadre jsonb)
returns cadres language plpgsql security definer set search_path = public, extensions as $$
declare v_id uuid; v_row cadres;
begin
    if coalesce(p_cadre->>'name','') = '' then
        raise exception '干部姓名不能为空';
    end if;
    v_id := nullif(p_cadre->>'id','');
    if v_id is not null and not exists (select 1 from cadres where id = v_id) then
        v_id := null;
    end if;
    if v_id is null then
        insert into cadres (name, department, position, major, class, grade, equipment_score)
        values (p_cadre->>'name', coalesce(p_cadre->>'department',''), coalesce(p_cadre->>'position',''),
                coalesce(p_cadre->>'major',''), coalesce(p_cadre->>'class',''), coalesce(p_cadre->>'grade',''),
                least(greatest(coalesce((p_cadre->>'equipment_score')::numeric,0),0),1000))
        returning * into v_row;
    else
        update cadres set
            name = coalesce(p_cadre->>'name', name),
            department = coalesce(p_cadre->>'department', department),
            position = coalesce(p_cadre->>'position', position),
            major = coalesce(p_cadre->>'major', major),
            class = coalesce(p_cadre->>'class', class),
            grade = coalesce(p_cadre->>'grade', grade),
            equipment_score = least(greatest(coalesce((p_cadre->>'equipment_score')::numeric, equipment_score),0),1000)
        where id = v_id returning * into v_row;
    end if;
    insert into audit_logs (action, table_name, detail) values ('upsert_cadre', 'cadres', jsonb_build_object('id', v_row.id, 'name', v_row.name));
    return v_row;
end $$;

create or replace function public.delete_cadre(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
    delete from cadres where id = p_id;
    if not found then raise exception '所选干部不存在'; end if;
    insert into audit_logs (action, table_name, detail) values ('delete_cadre', 'cadres', jsonb_build_object('id', p_id));
end $$;

create or replace function public.add_competition(p_password text default null, p_data jsonb)
returns competitions language plpgsql security definer set search_path = public as $$
declare v_cid uuid; v_row competitions;
begin
    v_cid := nullif(p_data->>'cadre_id','');
    if coalesce(p_data->>'name','') = '' then raise exception '比赛名称不能为空'; end if;
    if v_cid is null or not exists (select 1 from cadres where id = v_cid) then
        raise exception '所选干部不存在';
    end if;
    insert into competitions (cadre_id, name, level, award, score)
    values (v_cid, p_data->>'name', coalesce(p_data->>'level',''), coalesce(p_data->>'award',''),
            least(greatest(coalesce((p_data->>'score')::numeric,0),0),1000))
    returning * into v_row;
    insert into audit_logs (action, table_name, detail) values ('add_competition', 'competitions', jsonb_build_object('id', v_row.id));
    return v_row;
end $$;

create or replace function public.add_contribution(p_password text default null, p_data jsonb)
returns contributions language plpgsql security definer set search_path = public as $$
declare v_cid uuid; v_row contributions;
begin
    v_cid := nullif(p_data->>'cadre_id','');
    if coalesce(p_data->>'type','') = '' then raise exception '贡献类型不能为空'; end if;
    if v_cid is null or not exists (select 1 from cadres where id = v_cid) then
        raise exception '所选干部不存在';
    end if;
    if coalesce((p_data->>'count')::int,0) < 1 then raise exception '贡献次数必须大于0'; end if;
    if coalesce((p_data->>'count')::int,0) > 100 then raise exception '贡献次数不能超过100次'; end if;
    insert into contributions (cadre_id, type, count, total_score)
    values (v_cid, p_data->>'type', (p_data->>'count')::int, (p_data->>'total_score')::numeric)
    returning * into v_row;
    insert into audit_logs (action, table_name, detail) values ('add_contribution', 'contributions', jsonb_build_object('id', v_row.id));
    return v_row;
end $$;

create or replace function public.add_training(p_password text default null, p_data jsonb)
returns trainings language plpgsql security definer set search_path = public as $$
declare v_cid uuid; v_row trainings;
begin
    v_cid := nullif(p_data->>'cadre_id','');
    if coalesce(p_data->>'trainee_name','') = '' then raise exception '新生姓名不能为空'; end if;
    if v_cid is null or not exists (select 1 from cadres where id = v_cid) then
        raise exception '所选干部不存在';
    end if;
    if coalesce((p_data->>'hours')::numeric,0) > 100 then raise exception '培训时长不能超过100小时'; end if;
    insert into trainings (cadre_id, trainee_name, hours, score)
    values (v_cid, p_data->>'trainee_name', (p_data->>'hours')::numeric, (p_data->>'score')::numeric)
    returning * into v_row;
    insert into audit_logs (action, table_name, detail) values ('add_training', 'trainings', jsonb_build_object('id', v_row.id));
    return v_row;
end $$;

create or replace function public.add_deduction(p_password text default null, p_data jsonb)
returns deductions language plpgsql security definer set search_path = public as $$
declare v_cid uuid; v_row deductions; v_score numeric;
begin
    v_cid := nullif(p_data->>'cadre_id','');
    if v_cid is null or not exists (select 1 from cadres where id = v_cid) then
        raise exception '所选干部不存在';
    end if;
    v_score := coalesce((p_data->>'score')::numeric,0);
    if v_score <= 0 then raise exception '扣分必须大于0'; end if;
    if v_score > 1000 then raise exception '单次扣分不能超过1000分'; end if;
    insert into deductions (cadre_id, reason, score)
    values (v_cid, coalesce(p_data->>'reason',''), v_score)
    returning * into v_row;
    insert into audit_logs (action, table_name, detail) values ('add_deduction', 'deductions', jsonb_build_object('id', v_row.id));
    return v_row;
end $$;

create or replace function public.delete_record(p_table text, p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
    case p_table
        when 'cadres' then delete from cadres where id = p_id;
        when 'competitions' then delete from competitions where id = p_id;
        when 'contributions' then delete from contributions where id = p_id;
        when 'trainings' then delete from trainings where id = p_id;
        when 'deductions' then delete from deductions where id = p_id;
        else raise exception '不允许操作该表';
    end case;
    insert into audit_logs (action, table_name, detail) values ('delete_record', p_table, jsonb_build_object('id', p_id));
end $$;

create or replace function public.save_scoring_rules(p_rules jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
    insert into settings (key, value) values ('scoringRules', p_rules)
    on conflict (key) do update set value = excluded.value, updated_at = now();
    insert into audit_logs (action, table_name, detail) values ('save_scoring_rules', 'settings', '{}');
end $$;

create or replace function public.clear_all_data()
returns void language plpgsql security definer set search_path = public as $$
begin
    delete from competitions;
    delete from contributions;
    delete from trainings;
    delete from deductions;
    delete from import_images;
    delete from cadres;
    insert into audit_logs (action, table_name, detail) values ('clear_all_data', 'all', '{}');
end $$;

create or replace function public.save_import_image(p_password text default null, p_data jsonb)
returns import_images language plpgsql security definer set search_path = public as $$
declare v_row import_images;
begin
    insert into import_images (description, ai_summary, storage_path, public_url, record_table, record_id)
    values (coalesce(p_data->>'description',''), coalesce(p_data->>'ai_summary',''),
            coalesce(p_data->>'storage_path',''), coalesce(p_data->>'public_url',''),
            coalesce(p_data->>'record_table',''), nullif(p_data->>'record_id','')::uuid)
    returning * into v_row;
    return v_row;
end $$;

-- 6. 执行权限 -------------------------------------------------

grant execute on function verify_admin_password(text) to anon, authenticated;
grant execute on function change_admin_password(text, text) to anon, authenticated;
grant execute on function upsert_cadre(text, jsonb) to anon, authenticated;
grant execute on function delete_cadre(uuid) to anon, authenticated;
grant execute on function add_competition(text, jsonb) to anon, authenticated;
grant execute on function add_contribution(text, jsonb) to anon, authenticated;
grant execute on function add_training(text, jsonb) to anon, authenticated;
grant execute on function add_deduction(text, jsonb) to anon, authenticated;
grant execute on function delete_record(text, uuid) to anon, authenticated;
grant execute on function save_scoring_rules(jsonb) to anon, authenticated;
grant execute on function clear_all_data() to anon, authenticated;
grant execute on function save_import_image(text, jsonb) to anon, authenticated;

-- 7. 图片存储桶 ----------------------------------------------

insert into storage.buckets (id, name, public)
values ('import-images', 'import-images', true)
on conflict (id) do nothing;

drop policy if exists "import-images public read" on storage.objects;
create policy "import-images public read" on storage.objects
for select to anon, authenticated using (bucket_id = 'import-images');

drop policy if exists "import-images anon upload" on storage.objects;
create policy "import-images anon upload" on storage.objects
for insert to anon, authenticated with check (bucket_id = 'import-images');

-- 8. 实时同步 -------------------------------------------------

alter publication supabase_realtime add table public.cadres;
alter publication supabase_realtime add table public.competitions;
alter publication supabase_realtime add table public.contributions;
alter publication supabase_realtime add table public.trainings;
alter publication supabase_realtime add table public.deductions;
alter publication supabase_realtime add table public.import_images;
