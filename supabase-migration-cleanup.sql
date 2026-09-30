-- ============================================================
-- 六维考核系统 破坏性清理脚本 v3.0
-- 用途：在确认六维新前端 + 新 RPC 工作正常后，删除旧 4 表 + 旧 RPC + 旧 RLS + 旧 publication。
-- 执行前提：supabase-migration-sixdim.sql 已跑过，新前端已切换到 score_records/deduction_records。
-- 注意：本脚本不可逆，执行前请先在 Supabase Dashboard 备份数据库。
-- ============================================================

-- ============================================================
-- 1. 删除旧 4 张业务表（数据 + 表 + RLS + 索引一并清除）
-- ============================================================
drop table if exists public.competitions cascade;
drop table if exists public.contributions cascade;
drop table if exists public.trainings cascade;
drop table if exists public.deductions cascade;

-- ============================================================
-- 2. 删除旧 4 个加分/扣分 RPC
-- ============================================================
drop function if exists public.add_competition(text, jsonb);
drop function if exists public.add_contribution(text, jsonb);
drop function if exists public.add_training(text, jsonb);
drop function if exists public.add_deduction(text, jsonb);

-- ============================================================
-- 3. 重新定义 delete_record：移除旧 4 表分支，只保留 cadres / score_records / deduction_records
-- ============================================================
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

-- ============================================================
-- 4. 重新定义 clear_all_data：清六维新表，不再清旧表
-- ============================================================
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

-- ============================================================
-- 5. 清理 Realtime publication 中的旧表订阅
-- ============================================================
alter publication supabase_realtime drop table if exists public.competitions;
alter publication supabase_realtime drop table if exists public.contributions;
alter publication supabase_realtime drop table if exists public.trainings;
alter publication supabase_realtime drop table if exists public.deductions;

-- 确保新表订阅 Realtime（幂等）
-- 幂等：已在 publication 中则跳过（ADD TABLE 不支持 IF EXISTS）
do $$
declare
    t text;
begin
    foreach t in array array['score_records','deduction_records'] loop
        if not exists (select 1 from pg_publication_tables
                       where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
            execute format('alter publication supabase_realtime add table public.%I', t);
        end if;
    end loop;
end $$;

-- ============================================================
-- 6. 清理 settings 中无用的旧 scoringRules key（保留 sixDimRules / adminPasswordHash）
--    可选操作：旧前端已不再加载 scoringRules，留着也不影响新系统。
-- ============================================================
delete from public.settings where key = 'scoringRules';

-- ============================================================
-- 7. 收回旧 RPC 的执行权限（已被 drop，这里只是兜底）
-- ============================================================
revoke execute on function public.add_competition(text, jsonb) from anon, authenticated;
revoke execute on function public.add_contribution(text, jsonb) from anon, authenticated;
revoke execute on function public.add_training(text, jsonb) from anon, authenticated;
revoke execute on function public.add_deduction(text, jsonb) from anon, authenticated;

-- 完成
