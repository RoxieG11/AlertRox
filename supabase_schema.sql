-- ============================================
-- AlertRox — Supabase Veritabanı Şeması
-- ============================================
-- Bu SQL'i Supabase Dashboard → SQL Editor → New Query
-- alanına yapıştırıp "Run" butonuna tıklayın.
-- İstediğiniz kadar tekrar çalıştırabilirsiniz (hata vermez).
-- ============================================


-- ──────────────────────────────────────────────
-- 1) devices — Cihaz bilgileri ve canlı durum
-- ──────────────────────────────────────────────
create table if not exists devices (
  id          uuid default gen_random_uuid() primary key,
  device_id   text unique not null,            -- Makine benzersiz ID'si
  owner_id    uuid default auth.uid() references auth.users(id),
  name        text not null default 'My-PC',   -- Kullanıcının verdiği isim
  status      text not null default 'offline', -- 'online' / 'offline'
  last_boot   timestamptz,                     -- Son açılış zamanı
  last_heartbeat timestamptz,                  -- Son kalp atışı (canlı gösterge için)
  ip_address  text,                            -- Yerel IP adresi
  os_info     text,                            -- İşletim sistemi bilgisi
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);


-- ──────────────────────────────────────────────
-- 2) commands — Komut kuyruğu
-- ──────────────────────────────────────────────
create table if not exists commands (
  id            uuid default gen_random_uuid() primary key,
  device_id     text not null,                      -- Hedef cihaz ID'si
  owner_id      uuid default auth.uid() references auth.users(id),
  command_type  text not null,                      -- 'shutdown' / 'lock' / 'screenshot' / 'webcam' / 'mic_record'
  status        text not null default 'pending',    -- 'pending' / 'executing' / 'completed' / 'failed'
  payload       jsonb default '{}'::jsonb,          -- Ek parametreler
  result_url    text,                               -- Sonuç dosyasının Storage URL'i
  error_message text,                               -- Hata durumunda açıklama
  created_at    timestamptz default now(),           -- Komut oluşturulma zamanı
  executed_at   timestamptz                          -- Komut çalıştırılma zamanı
);


-- ──────────────────────────────────────────────
-- 3) activity_log — Olay geçmişi
-- ──────────────────────────────────────────────
create table if not exists activity_log (
  id          uuid default gen_random_uuid() primary key,
  device_id   text not null,
  owner_id    uuid default auth.uid() references auth.users(id),
  event_type  text not null,
  message     text,
  created_at  timestamptz default now()
);


-- ──────────────────────────────────────────────
-- 4) updated_at otomatik tetikleyici (Trigger)
-- ──────────────────────────────────────────────
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Önceden varsa silip yeniden oluştur (hata vermemesi için)
drop trigger if exists devices_updated_at on devices;
create trigger devices_updated_at
  before update on devices
  for each row execute function update_updated_at();


-- ──────────────────────────────────────────────
-- 5) İndeksler
-- ──────────────────────────────────────────────
create index if not exists idx_commands_device_status
  on commands (device_id, status);

create index if not exists idx_commands_pending
  on commands (status) where status = 'pending';

create index if not exists idx_activity_log_device
  on activity_log (device_id, created_at desc);


-- ──────────────────────────────────────────────
-- 6) Row Level Security (RLS) ve Politikalar
-- ──────────────────────────────────────────────
alter table devices enable row level security;
alter table commands enable row level security;
alter table activity_log enable row level security;

-- Varsa eski politikaları temizle
drop policy if exists "Service role full access on devices" on devices;
drop policy if exists "Service role full access on commands" on commands;
drop policy if exists "Service role full access on activity_log" on activity_log;

drop policy if exists "Authenticated owner access on devices" on devices;
create policy "Authenticated owner access on devices"
  on devices for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists "Authenticated owner access on commands" on commands;
create policy "Authenticated owner access on commands"
  on commands for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists "Authenticated owner access on activity_log" on activity_log;
create policy "Authenticated owner access on activity_log"
  on activity_log for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

revoke all on table devices, commands, activity_log from anon;
grant select, insert, update, delete on table devices, commands, activity_log to authenticated;


-- ──────────────────────────────────────────────
-- 7) Realtime (Canlı Dinleme)
-- ──────────────────────────────────────────────
do $$ 
begin 
  alter publication supabase_realtime add table devices; 
exception when others then null; 
end $$;

do $$ 
begin 
  alter publication supabase_realtime add table commands; 
exception when others then null; 
end $$;


-- ──────────────────────────────────────────────
-- 8) messages — İki yönlü canlı chat tablosu
-- ──────────────────────────────────────────────
create table if not exists messages (
  id          uuid default gen_random_uuid() primary key,
  device_id   text not null,
  owner_id    uuid default auth.uid() references auth.users(id),
  sender      text not null, -- 'mobile' veya 'pc'
  text        text not null,
  created_at  timestamptz default now()
);

create index if not exists idx_messages_device
  on messages (device_id, created_at asc);

alter table messages enable row level security;

drop policy if exists "Service role full access on messages" on messages;
drop policy if exists "Authenticated owner access on messages" on messages;
create policy "Authenticated owner access on messages"
  on messages for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

revoke all on table messages from anon;
grant select, insert, update, delete on table messages to authenticated;

do $$ 
begin 
  alter publication supabase_realtime add table messages; 
exception when others then null; 
end $$;

