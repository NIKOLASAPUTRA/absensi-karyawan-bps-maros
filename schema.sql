create extension if not exists "pgcrypto";

-- Safe custom enum type creation
do $$
begin
  if not exists (select 1 from pg_type where typname = 'app_role') then
    create type public.app_role as enum ('admin', 'hr', 'employee');
  end if;
  if not exists (select 1 from pg_type where typname = 'employee_status') then
    create type public.employee_status as enum ('active', 'inactive');
  end if;
  if not exists (select 1 from pg_type where typname = 'attendance_status') then
    create type public.attendance_status as enum ('present', 'absent', 'half_day', 'paid_leave', 'late_arrival');
  end if;
  if not exists (select 1 from pg_type where typname = 'leave_status') then
    create type public.leave_status as enum ('pending', 'approved', 'rejected');
  end if;
end$$;

-- Table creations with "if not exists"
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text not null,
  role public.app_role not null default 'employee',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.departments (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  manager_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.shifts (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  start_time time not null,
  end_time time not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.employees (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references public.profiles(id) on delete set null,
  employee_code text unique not null,
  full_name text not null,
  email text,
  designation text,
  joining_date date not null default current_date,
  base_salary numeric(12, 2) not null default 0,
  allowances numeric(12, 2) not null default 0,
  deductions numeric(12, 2) not null default 0,
  status public.employee_status not null default 'active',
  photo_url text,
  department_id uuid references public.departments(id) on delete set null,
  shift_id uuid references public.shifts(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id) on delete cascade,
  attendance_date date not null,
  check_in timestamptz,
  check_out timestamptz,
  status public.attendance_status not null default 'present',
  notes text,
  working_hours numeric(5, 2) not null default 0,
  overtime_hours numeric(5, 2) not null default 0,
  latitude numeric(10, 8),
  longitude numeric(11, 8),
  late_arrival boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (employee_id, attendance_date)
);

create table if not exists public.leave_requests (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id) on delete cascade,
  leave_type text not null,
  start_date date not null,
  end_date date not null,
  reason text,
  status public.leave_status not null default 'pending',
  approved_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.leave_balances (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id) on delete cascade,
  casual_leave_bal integer not null default 12,
  sick_leave_bal integer not null default 10,
  paid_leave_bal integer not null default 15,
  unpaid_leave_bal integer not null default 30,
  year integer not null default 2026,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (employee_id, year)
);

create table if not exists public.salary_slips (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id) on delete cascade,
  salary_month text not null,
  base_salary numeric(12, 2) not null default 0,
  allowances numeric(12, 2) not null default 0,
  deductions numeric(12, 2) not null default 0,
  net_salary numeric(12, 2) not null default 0,
  generated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (employee_id, salary_month)
);

create table if not exists public.employee_documents (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id) on delete cascade,
  document_type text not null,
  file_path text not null,
  file_name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.fcm_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  title text not null,
  body text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  table_name text not null,
  action text not null,
  record_id text,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.holidays (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  holiday_date date not null unique,
  holiday_type text not null default 'public',
  created_at timestamptz not null default now()
);

-- Alter table migration helper DO block (in case tables already existed and missed new columns)
do $$
begin
  if exists (select 1 from information_schema.tables where table_name='employees' and table_schema='public') then
    if not exists (select 1 from information_schema.columns where table_name='employees' and column_name='photo_url') then
      alter table public.employees add column photo_url text;
    end if;
    if not exists (select 1 from information_schema.columns where table_name='employees' and column_name='department_id') then
      alter table public.employees add column department_id uuid references public.departments(id) on delete set null;
    end if;
    if not exists (select 1 from information_schema.columns where table_name='employees' and column_name='shift_id') then
      alter table public.employees add column shift_id uuid references public.shifts(id) on delete set null;
    end if;
  end if;

  if exists (select 1 from information_schema.tables where table_name='attendance' and table_schema='public') then
    if not exists (select 1 from information_schema.columns where table_name='attendance' and column_name='working_hours') then
      alter table public.attendance add column working_hours numeric(5, 2) not null default 0;
    end if;
    if not exists (select 1 from information_schema.columns where table_name='attendance' and column_name='overtime_hours') then
      alter table public.attendance add column overtime_hours numeric(5, 2) not null default 0;
    end if;
    if not exists (select 1 from information_schema.columns where table_name='attendance' and column_name='latitude') then
      alter table public.attendance add column latitude numeric(10, 8);
    end if;
    if not exists (select 1 from information_schema.columns where table_name='attendance' and column_name='longitude') then
      alter table public.attendance add column longitude numeric(11, 8);
    end if;
    if not exists (select 1 from information_schema.columns where table_name='attendance' and column_name='late_arrival') then
      alter table public.attendance add column late_arrival boolean not null default false;
    end if;
  end if;
end$$;

-- Functions & Helpers

create or replace function public.current_user_role()
returns public.app_role
language sql
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid()
$$;

create or replace function public.is_manager()
returns boolean
language sql
security definer
set search_path = public
as $$
  select coalesce(public.current_user_role() in ('admin', 'hr'), false)
$$;

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select coalesce(public.current_user_role() = 'admin', false)
$$;

create or replace function public.owns_employee(target_employee_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.employees
    where id = target_employee_id and user_id = auth.uid()
  )
$$;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_morning_shift_id uuid;
  v_existing_employee_id uuid;
begin
  insert into public.profiles (id, email, full_name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    coalesce((new.raw_user_meta_data->>'role')::public.app_role, 'employee')
  );

  -- Check if an employee record was already created with this email
  select id into v_existing_employee_id 
  from public.employees 
  where email = new.email 
  limit 1;

  if v_existing_employee_id is not null then
    -- Link the existing employee record to the new profile
    update public.employees 
    set user_id = new.id 
    where id = v_existing_employee_id;
  else
    -- Create a new employee record
    select id into v_morning_shift_id from public.shifts where name = 'Morning Shift' limit 1;

    insert into public.employees (user_id, employee_code, full_name, email, shift_id)
    values (
      new.id,
      'EMP-' || upper(substr(new.id::text, 1, 8)),
      coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
      new.email,
      v_morning_shift_id
    );
  end if;

  return new;
end;
$$;

create or replace function public.write_audit_log()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.audit_logs (actor_id, table_name, action, record_id, old_data, new_data)
  values (
    auth.uid(),
    tg_table_name,
    tg_op,
    coalesce(new.id::text, old.id::text),
    case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) else null end,
    case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) else null end
  );
  return coalesce(new, old);
end;
$$;

create or replace function public.protect_role_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return new;
  end if;

  if new.role <> old.role and not public.is_admin() then
    raise exception 'Only admins can change roles';
  end if;
  return new;
end;
$$;

create or replace function public.handle_new_employee_leave_balance()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.leave_balances (employee_id, year)
  values (new.id, extract(year from new.joining_date)::integer)
  on conflict (employee_id, year) do nothing;
  return new;
end;
$$;

create or replace function public.calculate_attendance_metrics()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shift_start time;
  v_shift_end time;
  v_check_in_time time;
  v_working_hours numeric(5, 2) := 0;
  v_overtime_hours numeric(5, 2) := 0;
  v_late_arrival boolean := false;
  v_duration numeric;
  v_shift_hours numeric;
begin
  -- Get employee's shift details
  select s.start_time, s.end_time into v_shift_start, v_shift_end
  from public.employees e
  join public.shifts s on e.shift_id = s.id
  where e.id = new.employee_id;

  if v_shift_start is null then
    -- fallback default shift 09:00 - 17:00
    v_shift_start := '09:00:00'::time;
    v_shift_end := '17:00:00'::time;
  end if;

  if new.check_in is not null then
    v_check_in_time := new.check_in::time;
    -- If checked in more than 15 mins after shift start, it's late arrival
    if v_check_in_time > (v_shift_start + interval '15 minutes') then
      v_late_arrival := true;
    end if;
  end if;

  if new.check_in is not null and new.check_out is not null then
    -- calculate actual working hours (in hours)
    v_duration := extract(epoch from (new.check_out - new.check_in)) / 3600.0;
    v_working_hours := round(v_duration::numeric, 2);

    -- overtime calculation: if working hours exceeds shift hours
    v_shift_hours := extract(epoch from (case when v_shift_end > v_shift_start then v_shift_end - v_shift_start else (v_shift_end + interval '24 hours') - v_shift_start end)) / 3600.0;
    if v_working_hours > v_shift_hours then
      v_overtime_hours := round((v_working_hours - v_shift_hours)::numeric, 2);
    end if;
  end if;

  new.working_hours := v_working_hours;
  new.overtime_hours := v_overtime_hours;
  new.late_arrival := v_late_arrival;

  -- set status to 'late_arrival' if late_arrival is true and status is 'present'
  if v_late_arrival and new.status = 'present' then
    new.status := 'late_arrival';
  end if;

  return new;
end;
$$;

-- Triggers configuration (with drop-before-create to ensure idempotency)

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

drop trigger if exists profiles_touch on public.profiles;
create trigger profiles_touch before update on public.profiles for each row execute procedure public.touch_updated_at();

drop trigger if exists profiles_protect_role on public.profiles;
create trigger profiles_protect_role before update on public.profiles for each row execute procedure public.protect_role_change();

drop trigger if exists departments_touch on public.departments;
create trigger departments_touch before update on public.departments for each row execute procedure public.touch_updated_at();

drop trigger if exists shifts_touch on public.shifts;
create trigger shifts_touch before update on public.shifts for each row execute procedure public.touch_updated_at();

drop trigger if exists employees_touch on public.employees;
create trigger employees_touch before update on public.employees for each row execute procedure public.touch_updated_at();

drop trigger if exists attendance_touch on public.attendance;
create trigger attendance_touch before update on public.attendance for each row execute procedure public.touch_updated_at();

drop trigger if exists leaves_touch on public.leave_requests;
create trigger leaves_touch before update on public.leave_requests for each row execute procedure public.touch_updated_at();

drop trigger if exists leave_balances_touch on public.leave_balances;
create trigger leave_balances_touch before update on public.leave_balances for each row execute procedure public.touch_updated_at();

drop trigger if exists fcm_touch on public.fcm_tokens;
create trigger fcm_touch before update on public.fcm_tokens for each row execute procedure public.touch_updated_at();

drop trigger if exists on_employee_created on public.employees;
create trigger on_employee_created
after insert on public.employees
for each row execute procedure public.handle_new_employee_leave_balance();

drop trigger if exists attendance_calc_metrics on public.attendance;
create trigger attendance_calc_metrics
before insert or update on public.attendance
for each row execute procedure public.calculate_attendance_metrics();

drop trigger if exists employees_audit on public.employees;
create trigger employees_audit after insert or update or delete on public.employees for each row execute procedure public.write_audit_log();

drop trigger if exists departments_audit on public.departments;
create trigger departments_audit after insert or update or delete on public.departments for each row execute procedure public.write_audit_log();

drop trigger if exists shifts_audit on public.shifts;
create trigger shifts_audit after insert or update or delete on public.shifts for each row execute procedure public.write_audit_log();

drop trigger if exists attendance_audit on public.attendance;
create trigger attendance_audit after insert or update or delete on public.attendance for each row execute procedure public.write_audit_log();

drop trigger if exists leaves_audit on public.leave_requests;
create trigger leaves_audit after insert or update or delete on public.leave_requests for each row execute procedure public.write_audit_log();

drop trigger if exists salary_audit on public.salary_slips;
create trigger salary_audit after insert or update or delete on public.salary_slips for each row execute procedure public.write_audit_log();

drop trigger if exists documents_audit on public.employee_documents;
create trigger documents_audit after insert or update or delete on public.employee_documents for each row execute procedure public.write_audit_log();

-- Row Level Security (RLS) Enablement

alter table public.profiles enable row level security;
alter table public.departments enable row level security;
alter table public.shifts enable row level security;
alter table public.holidays enable row level security;
alter table public.employees enable row level security;
alter table public.attendance enable row level security;
alter table public.leave_requests enable row level security;
alter table public.leave_balances enable row level security;
alter table public.salary_slips enable row level security;
alter table public.employee_documents enable row level security;
alter table public.fcm_tokens enable row level security;
alter table public.notifications enable row level security;
alter table public.audit_logs enable row level security;

-- Policies Definition (with drop-before-create to ensure idempotency)

-- Profiles
drop policy if exists "profiles read own or manager" on public.profiles;
create policy "profiles read own or manager" on public.profiles
for select to authenticated using (id = auth.uid() or public.is_manager());

drop policy if exists "profiles update own basic data" on public.profiles;
create policy "profiles update own basic data" on public.profiles
for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- Departments
drop policy if exists "departments read authenticated" on public.departments;
create policy "departments read authenticated" on public.departments
for select to authenticated using (true);

drop policy if exists "departments manager manage" on public.departments;
create policy "departments manager manage" on public.departments
for all to authenticated using (public.is_manager()) with check (public.is_manager());

-- Shifts
drop policy if exists "shifts read authenticated" on public.shifts;
create policy "shifts read authenticated" on public.shifts
for select to authenticated using (true);

drop policy if exists "shifts manager manage" on public.shifts;
create policy "shifts manager manage" on public.shifts
for all to authenticated using (public.is_manager()) with check (public.is_manager());

-- Holidays
drop policy if exists "holidays read authenticated" on public.holidays;
create policy "holidays read authenticated" on public.holidays
for select to authenticated using (true);

drop policy if exists "holidays manager manage" on public.holidays;
create policy "holidays manager manage" on public.holidays
for all to authenticated using (public.is_manager()) with check (public.is_manager());

-- Employees
drop policy if exists "employees read scoped" on public.employees;
create policy "employees read scoped" on public.employees
for select to authenticated using (public.is_manager() or user_id = auth.uid());

drop policy if exists "employees manage by manager" on public.employees;
create policy "employees manage by manager" on public.employees
for all to authenticated using (public.is_manager()) with check (public.is_manager());

drop policy if exists "employees update own record" on public.employees;
create policy "employees update own record" on public.employees
for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Attendance
drop policy if exists "attendance read scoped" on public.attendance;
create policy "attendance read scoped" on public.attendance
for select to authenticated using (public.is_manager() or public.owns_employee(employee_id));

drop policy if exists "attendance employee insert own" on public.attendance;
create policy "attendance employee insert own" on public.attendance
for insert to authenticated with check (public.is_manager() or public.owns_employee(employee_id));

drop policy if exists "attendance update scoped" on public.attendance;
create policy "attendance update scoped" on public.attendance
for update to authenticated using (public.is_manager() or public.owns_employee(employee_id)) with check (public.is_manager() or public.owns_employee(employee_id));

-- Leave Requests
drop policy if exists "leaves read scoped" on public.leave_requests;
create policy "leaves read scoped" on public.leave_requests
for select to authenticated using (public.is_manager() or public.owns_employee(employee_id));

drop policy if exists "leaves employee create own" on public.leave_requests;
create policy "leaves employee create own" on public.leave_requests
for insert to authenticated with check (public.owns_employee(employee_id));

drop policy if exists "leaves manager update" on public.leave_requests;
create policy "leaves manager update" on public.leave_requests
for update to authenticated using (public.is_manager()) with check (public.is_manager());

-- Leave Balances
drop policy if exists "balances read scoped" on public.leave_balances;
create policy "balances read scoped" on public.leave_balances
for select to authenticated using (public.is_manager() or public.owns_employee(employee_id));

drop policy if exists "balances manager manage" on public.leave_balances;
create policy "balances manager manage" on public.leave_balances
for all to authenticated using (public.is_manager()) with check (public.is_manager());

-- Salary Slips
drop policy if exists "salary read scoped" on public.salary_slips;
create policy "salary read scoped" on public.salary_slips
for select to authenticated using (public.is_manager() or public.owns_employee(employee_id));

drop policy if exists "salary manager manage" on public.salary_slips;
create policy "salary manager manage" on public.salary_slips
for all to authenticated using (public.is_manager()) with check (public.is_manager());

-- Employee Documents
drop policy if exists "documents read scoped" on public.employee_documents;
create policy "documents read scoped" on public.employee_documents
for select to authenticated using (public.is_manager() or public.owns_employee(employee_id));

drop policy if exists "documents employee upload own" on public.employee_documents;
create policy "documents employee upload own" on public.employee_documents
for insert to authenticated with check (public.owns_employee(employee_id));

drop policy if exists "documents manager manage" on public.employee_documents;
create policy "documents manager manage" on public.employee_documents
for all to authenticated using (public.is_manager()) with check (public.is_manager());

-- FCM Tokens
drop policy if exists "fcm own tokens" on public.fcm_tokens;
create policy "fcm own tokens" on public.fcm_tokens
for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Notifications
drop policy if exists "notifications read own or broadcast" on public.notifications;
create policy "notifications read own or broadcast" on public.notifications
for select to authenticated using (user_id = auth.uid() or user_id is null or public.is_manager());

drop policy if exists "notifications manager create" on public.notifications;
create policy "notifications manager create" on public.notifications
for insert to authenticated with check (public.is_manager());

-- Audit Logs
drop policy if exists "audit admin read" on public.audit_logs;
create policy "audit admin read" on public.audit_logs
for select to authenticated using (public.is_admin());

-- Storage Bucket Configuration and Policies

insert into storage.buckets (id, name, public)
values ('employee-documents', 'employee-documents', false)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('employee-photos', 'employee-photos', true)
on conflict (id) do nothing;

-- Document objects policies
drop policy if exists "document objects read scoped" on storage.objects;
create policy "document objects read scoped" on storage.objects
for select to authenticated
using (
  bucket_id = 'employee-documents'
  and (
    public.is_manager()
    or exists (
      select 1 from public.employees
      where id::text = (storage.foldername(name))[1]
      and user_id = auth.uid()
    )
  )
);

drop policy if exists "document objects upload own" on storage.objects;
create policy "document objects upload own" on storage.objects
for insert to authenticated
with check (
  bucket_id = 'employee-documents'
  and exists (
    select 1 from public.employees
    where id::text = (storage.foldername(name))[1]
    and user_id = auth.uid()
  )
);

drop policy if exists "document objects delete manager" on storage.objects;
create policy "document objects delete manager" on storage.objects
for delete to authenticated
using (
  bucket_id = 'employee-documents'
  and public.is_manager()
);

-- Photo objects policies
drop policy if exists "photo objects read public" on storage.objects;
create policy "photo objects read public" on storage.objects
for select to authenticated
using (bucket_id = 'employee-photos');

drop policy if exists "photo objects upload own" on storage.objects;
create policy "photo objects upload own" on storage.objects
for insert to authenticated
with check (
  bucket_id = 'employee-photos'
  and (
    public.is_manager()
    or exists (
      select 1 from public.employees
      where id::text = (storage.foldername(name))[1]
      and user_id = auth.uid()
    )
  )
);

drop policy if exists "photo objects update own" on storage.objects;
create policy "photo objects update own" on storage.objects
for update to authenticated
using (
  bucket_id = 'employee-photos'
  and (
    public.is_manager()
    or exists (
      select 1 from public.employees
      where id::text = (storage.foldername(name))[1]
      and user_id = auth.uid()
    )
  )
);

drop policy if exists "photo objects delete own" on storage.objects;
create policy "photo objects delete own" on storage.objects
for delete to authenticated
using (
  bucket_id = 'employee-photos'
  and (
    public.is_manager()
    or exists (
      select 1 from public.employees
      where id::text = (storage.foldername(name))[1]
      and user_id = auth.uid()
    )
  )
);

-- SEED DATA

-- Shifts Seeding
insert into public.shifts (name, start_time, end_time)
values 
  ('Morning Shift', '09:00:00', '17:00:00'),
  ('Evening Shift', '17:00:00', '01:00:00'),
  ('Night Shift', '01:00:00', '09:00:00')
on conflict (name) do nothing;

-- Departments Seeding
insert into public.departments (name)
values 
  ('Engineering'),
  ('Human Resources'),
  ('Finance'),
  ('Operations'),
  ('Sales')
on conflict (name) do nothing;

-- Holidays Seeding
insert into public.holidays (name, holiday_date, holiday_type)
values 
  ('New Year''s Day', '2026-01-01', 'public'),
  ('Republic Day (India)', '2026-01-26', 'public'),
  ('Independence Day (India)', '2026-08-15', 'public'),
  ('Christmas Day', '2026-12-25', 'public')
on conflict (holiday_date) do nothing;
