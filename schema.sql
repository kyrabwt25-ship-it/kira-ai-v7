-- KIRA AI database schema
-- شغّل هذا الملف كاملًا مرة واحدة في Supabase SQL Editor.
-- الملف قابل لإعادة التشغيل ولا يحتوي على أسرار أو بريد مشرف ثابت.

create extension if not exists pgcrypto;

create table if not exists plans(
  id text primary key,
  name text not null,
  model text not null,
  daily_messages int not null,
  daily_images int not null,
  max_tokens int not null,
  style_rule text not null default '',
  sort int not null default 0,
  kind text not null default 's',
  price_weekly numeric default 0,
  price_monthly numeric default 0,
  price_yearly numeric default 0
);

alter table plans add column if not exists kind text not null default 's';
alter table plans add column if not exists price_weekly numeric default 0;
alter table plans add column if not exists price_monthly numeric default 0;
alter table plans add column if not exists price_yearly numeric default 0;

insert into plans(id,name,model,daily_messages,daily_images,max_tokens,style_rule,sort,kind)
values
 ('free','Free','claude-haiku-5-5',20,3,500,'أجب باختصار مفيد، واذكر الخطوات الأساسية بوضوح.',0,'s'),
 ('plus','Plus','claude-sonnet-5-5',100,15,1500,'اشرح بالتفصيل مع خطوات الحل.',1,'s'),
 ('pro','Pro','claude-opus-5-5',300,50,3000,'قدّم تحليلًا عميقًا وحلولًا كاملة للمسائل الصعبة.',2,'s'),
 ('ultra','Ultra','claude-opus-5-5',1000,150,4000,'أعلى جودة: تحليل معمّق وأمثلة وتحقق من الحل.',3,'s'),
 ('tfree','Teacher Free','claude-sonnet-5-5',20,3,800,'أجب بإيجاز مفيد للمعلم مع أبرز النقاط العملية.',10,'t'),
 ('tplus','Teacher Plus','claude-opus-5-5',120,30,3000,'قدّم إجابات احترافية مفصلة مع أمثلة وطرق تدريس وتقويم.',11,'t'),
 ('tpro','Teacher Pro','claude-opus-5-5',300,100,4000,'تحليل عميق ومواد تعليمية كاملة جاهزة للاستخدام في الفصل.',12,'t'),
 ('tultra','Teacher Ultra','claude-opus-5-5',800,300,5000,'أعلى جودة: مواد تعليمية متكاملة وتحقق من الدقة.',13,'t')
on conflict (id) do nothing;

create table if not exists profiles(
  id uuid primary key references auth.users on delete cascade,
  email text,
  plan_id text not null default 'free' references plans(id),
  plan_expires_at timestamptz,
  role text not null default 'user' check (role in ('user','admin')),
  banned boolean not null default false,
  account_type text not null default 'student' check (account_type in ('student','teacher')),
  created_at timestamptz default now()
);
alter table profiles add column if not exists email text;
alter table profiles add column if not exists plan_id text not null default 'free';
alter table profiles add column if not exists plan_expires_at timestamptz;
alter table profiles add column if not exists role text not null default 'user';
alter table profiles add column if not exists banned boolean not null default false;
alter table profiles add column if not exists account_type text not null default 'student';
alter table profiles add column if not exists created_at timestamptz default now();

create table if not exists usage(
  user_id uuid references auth.users on delete cascade,
  day date,
  messages int not null default 0,
  images int not null default 0,
  primary key(user_id, day)
);

create table if not exists settings(
  key text primary key,
  value text not null default ''
);
insert into settings(key,value) values
 ('persona','أنت KIRA AI، مساعد تعليمي للطلبة. تحدث بالعربية افتراضيًا وبأسلوب يناسب العمر، وكن دقيقًا ولا تخترع مراجع أو أرقام صفحات. المحتوى مناسب للأطفال دائمًا.'),
 ('maintenance','')
on conflict (key) do nothing;

create table if not exists payments(
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  plan_id text references plans(id),
  period text check (period in ('weekly','monthly','yearly')),
  amount numeric default 0,
  status text not null default 'pending' check (status in ('pending','paid','failed')),
  method text,
  from_number text,
  tx text,
  created_at timestamptz default now(),
  paid_at timestamptz
);
alter table payments add column if not exists from_number text;
alter table payments add column if not exists tx text;

create table if not exists documents(
  id bigserial primary key,
  title text not null,
  level text,
  subject text,
  created_at timestamptz default now()
);
create table if not exists chunks(
  id bigserial primary key,
  doc_id bigint references documents(id) on delete cascade,
  page int,
  content text not null,
  level text,
  subject text,
  tsv tsvector generated always as (to_tsvector('simple', content)) stored
);
create index if not exists chunks_tsv on chunks using gin(tsv);

create table if not exists announcements(
  id bigserial primary key,
  text text not null,
  created_at timestamptz default now()
);

create table if not exists conversations(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default 'محادثة جديدة',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists conversations_user_updated on conversations(user_id, updated_at desc);

create table if not exists chat_messages(
  id bigserial primary key,
  conversation_id uuid not null references conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('user','assistant')),
  content text not null,
  created_at timestamptz not null default now()
);
create index if not exists chat_messages_conversation_created on chat_messages(conversation_id, created_at);

-- ملف المستخدم ينشأ تلقائيًا مع التسجيل، من دون تثبيت بريد مشرف داخل قاعدة البيانات.
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path=public as $$
begin
  insert into profiles(id,email) values(new.id,new.email)
  on conflict (id) do update set email=excluded.email;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute function handle_new_user();

-- عداد ذري للحدود اليومية، لا يمكن للعميل استدعاؤه مباشرة.
create or replace function bump_usage(p_user uuid, p_images int, p_max_msgs int, p_max_imgs int)
returns text language plpgsql security definer set search_path=public as $$
declare r usage;
begin
  insert into usage(user_id, day) values(p_user, current_date) on conflict do nothing;
  select * into r from usage where user_id=p_user and day=current_date for update;
  if r.messages >= p_max_msgs then return 'messages'; end if;
  if p_images > 0 and r.images + p_images > p_max_imgs then return 'images'; end if;
  update usage set messages=messages+1, images=images+p_images
    where user_id=p_user and day=current_date;
  return 'ok';
end $$;
revoke all on function bump_usage(uuid,int,int,int) from public, anon, authenticated;
grant execute on function bump_usage(uuid,int,int,int) to service_role;

create or replace function search_chunks(p_query text, p_level text, p_subject text, p_n int)
returns table(title text, page int, content text)
language sql stable security definer set search_path=public as $$
  select d.title, c.page, c.content
  from chunks c join documents d on d.id=c.doc_id
  where c.tsv @@ to_tsquery('simple', p_query)
    and (c.level is null or c.level=p_level)
    and (c.subject is null or c.subject=p_subject)
  order by ts_rank(c.tsv, to_tsquery('simple', p_query)) desc
  limit greatest(1, least(coalesce(p_n,4), 20))
$$;
revoke all on function search_chunks(text,text,text,int) from public, anon, authenticated;
grant execute on function search_chunks(text,text,text,int) to service_role;

-- RLS: الخادم يستخدم service_role. السياسات التالية تسمح للمستخدم بقراءة بياناته فقط
-- إذا استُخدمت Supabase مباشرة من عميل آخر مستقبلًا.
alter table plans enable row level security;
alter table profiles enable row level security;
alter table usage enable row level security;
alter table settings enable row level security;
alter table payments enable row level security;
alter table documents enable row level security;
alter table chunks enable row level security;
alter table announcements enable row level security;
alter table conversations enable row level security;
alter table chat_messages enable row level security;

drop policy if exists "plans readable" on plans;
create policy "plans readable" on plans for select using (true);
drop policy if exists "own profile" on profiles;
create policy "own profile" on profiles for select using (auth.uid() = id);
drop policy if exists "own usage" on usage;
create policy "own usage" on usage for select using (auth.uid() = user_id);
drop policy if exists "own conversations" on conversations;
create policy "own conversations" on conversations for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "own chat messages" on chat_messages;
create policy "own chat messages" on chat_messages for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- أنشئ المشرف بعد تسجيل حسابه وتأكيد بريده:
-- update profiles set role='admin' where lower(email)=lower('you@example.com');
