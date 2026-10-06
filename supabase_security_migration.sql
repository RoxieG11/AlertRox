-- ==============================================================================
-- AlertRox — Güvenlik Sıkılaştırma Migrasyonu (Security Hardening Migration)
-- ==============================================================================
-- ⚠️ DİKKAT: Bu SQL scriptini Supabase Dashboard → SQL Editor → New Query 
-- bölümüne yapıştırıp "RUN" butonuna basarak çalıştırın.
--
-- ------------------------------------------------------------------------------
-- 📌 DASHBOARD ÜZERİNDE YAPILMASI GEREKEN ELLE ADIMLAR:
-- ------------------------------------------------------------------------------
-- 1. YENİ KULLANICI KAYDINI KAPATIN:
--    Dashboard → Authentication → Providers → Email bölümüne gidin.
--    "Allow new users to sign up" seçeneğini KAPATIN (Toggle OFF).
--    Böylece dışarıdan yabancı kişilerin veritabanınıza üye olması engellenir.
--
-- 2. KULLANICINIZI OLUŞTURUN:
--    Dashboard → Authentication → Users bölümüne gidin.
--    "Add User" butonuna tıklayıp Mobil App ve PC Agent'ta kullanacağınız 
--    kendi E-Posta adresinizi ve güçlü bir Şifrenizi belirleyin.
--
-- 3. TEHLİKEYE GİRMİŞ ANAHTARLARI YENİLEYİN (ROTATE KEYS):
--    Dashboard → Project Settings → API bölümüne gidin.
--    "JWT Settings" altında "Generate a new JWT secret" (Rotate secret) yapın.
--    Bu işlem eski sızmış tüm anon ve service_role anahtarlarını anında hükümsüz kılar.
--    Ardından yeni "anon / public" anahtarınızı kopyalayın.
-- ==============================================================================

-- ──────────────────────────────────────────────────────────────────────────────
-- 1. TABLOLARA owner_id ALANI EKLEME VE İLİŞKİLENDİRME
-- ──────────────────────────────────────────────────────────────────────────────

-- devices tablosu
alter table public.devices 
  add column if not exists owner_id uuid references auth.users(id) default auth.uid();

-- commands tablosu
alter table public.commands 
  add column if not exists owner_id uuid references auth.users(id) default auth.uid();

-- activity_log tablosu
alter table public.activity_log 
  add column if not exists owner_id uuid references auth.users(id) default auth.uid();

-- messages tablosu
alter table public.messages 
  add column if not exists owner_id uuid references auth.users(id) default auth.uid();

-- Varsa mevcut sahipsiz kayıtları oturum açmış kullanıcıya ata (auth.uid() mevcutsa)
do $$
declare
  first_user_id uuid;
begin
  select id into first_user_id from auth.users order by created_at asc limit 1;
  if first_user_id is not null then
    update public.devices set owner_id = first_user_id where owner_id is null;
    update public.commands set owner_id = first_user_id where owner_id is null;
    update public.activity_log set owner_id = first_user_id where owner_id is null;
    update public.messages set owner_id = first_user_id where owner_id is null;
  end if;
end $$;

-- owner_id alanlarını indeksle (RLS sorgu performansı için)
create index if not exists idx_devices_owner on public.devices (owner_id);
create index if not exists idx_commands_owner on public.commands (owner_id);
create index if not exists idx_activity_log_owner on public.activity_log (owner_id);
create index if not exists idx_messages_owner on public.messages (owner_id);


-- ──────────────────────────────────────────────────────────────────────────────
-- 2. ESKİ 'USING (TRUE)' POLİTİKALARINI SİLME VE RLS SIKILAŞTIRMA
-- ──────────────────────────────────────────────────────────────────────────────

-- RLS'nin aktif olduğundan emin ol
alter table public.devices enable row level security;
alter table public.commands enable row level security;
alter table public.activity_log enable row level security;
alter table public.messages enable row level security;

-- Eski genel politiları temizle
drop policy if exists "Service role full access on devices" on public.devices;
drop policy if exists "Service role full access on commands" on public.commands;
drop policy if exists "Service role full access on activity_log" on public.activity_log;
drop policy if exists "Service role full access on messages" on public.messages;

drop policy if exists "Authenticated owner access on devices" on public.devices;
drop policy if exists "Authenticated owner access on commands" on public.commands;
drop policy if exists "Authenticated owner access on activity_log" on public.activity_log;
drop policy if exists "Authenticated owner access on messages" on public.messages;

-- Yalnızca kimliği doğrulanmış (authenticated) ve owner_id eşleşen kullanıcıya tam hak ver:
create policy "Authenticated owner access on devices"
  on public.devices
  for all
  to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy "Authenticated owner access on commands"
  on public.commands
  for all
  to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy "Authenticated owner access on activity_log"
  on public.activity_log
  for all
  to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy "Authenticated owner access on messages"
  on public.messages
  for all
  to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());


-- ──────────────────────────────────────────────────────────────────────────────
-- 3. 'ANON' ROLÜNÜN TABLOLARDAKİ TÜM YETKİLERİNİ KALDIRMA (REVOKE)
-- ──────────────────────────────────────────────────────────────────────────────
revoke all on table public.devices from anon;
revoke all on table public.commands from anon;
revoke all on table public.activity_log from anon;
revoke all on table public.messages from anon;

grant select, insert, update, delete on table public.devices to authenticated;
grant select, insert, update, delete on table public.commands to authenticated;
grant select, insert, update, delete on table public.activity_log to authenticated;
grant select, insert, update, delete on table public.messages to authenticated;


-- ──────────────────────────────────────────────────────────────────────────────
-- 4. COMMANDS TABLOSU İÇİN KISITLAMALAR VE PAYLOAD DOĞRULAMA (VALIDATION)
-- ──────────────────────────────────────────────────────────────────────────────

-- command_type kısıtı
alter table public.commands drop constraint if exists check_valid_command_type;
alter table public.commands add constraint check_valid_command_type
  check (command_type in (
    'open_chat',
    'shutdown',
    'cancel_shutdown',
    'lock',
    'logout',
    'screenshot',
    'webcam',
    'mic_record'
  ));

-- Payload doğrulama tetikleyicisi (Trigger Function)
create or replace function public.validate_command_payload()
returns trigger as $$
declare
  delay_val int;
  dur_val int;
begin
  -- Otomatik owner_id atama
  if new.owner_id is null then
    new.owner_id := auth.uid();
  end if;

  -- Shutdown kontrolü: delay 5 ile 86400 arasında olmalı
  if new.command_type = 'shutdown' and new.payload ? 'delay' then
    begin
      delay_val := (new.payload->>'delay')::int;
      if delay_val < 5 or delay_val > 86400 then
        raise exception 'Shutdown delay süresi 5 ile 86400 saniye arasında olmalıdır.';
      end if;
    exception when others then
      raise exception 'Geçersiz shutdown delay formatı.';
    end;
  end if;

  -- mic_record kontrolü: duration 1 ile 120 arasında olmalı
  if new.command_type = 'mic_record' and new.payload ? 'duration' then
    begin
      dur_val := (new.payload->>'duration')::int;
      if dur_val < 1 or dur_val > 120 then
        raise exception 'Mikrofon kayıt süresi 1 ile 120 saniye arasında olmalıdır.';
      end if;
    exception when others then
      raise exception 'Geçersiz mic_record duration formatı.';
    end;
  end if;

  return new;
end;
$$ language plpgsql;

drop trigger if exists trigger_validate_command_payload on public.commands;
create trigger trigger_validate_command_payload
  before insert or update on public.commands
  for each row execute function public.validate_command_payload();


-- ──────────────────────────────────────────────────────────────────────────────
-- 5. STORAGE GÜVENLİĞİ: 'alertrox-files' BUCKET'INI GİZLİ YAPMA & RLS
-- ──────────────────────────────────────────────────────────────────────────────

-- 1. Bucket'ı private yap (dışarıdan rastgele URL ile dosya çekilemez)
update storage.buckets
  set public = false
  where id = 'alertrox-files';

-- 2. Storage Objects politikaları: Yalnızca kendi cihazlarına dosya yükleyebilir/okuyabilir
drop policy if exists "Authenticated users can access their device files" on storage.objects;
create policy "Authenticated users can access their device files"
  on storage.objects
  for all
  to authenticated
  using (
    bucket_id = 'alertrox-files'
    and (storage.foldername(name))[1] in (
      select device_id from public.devices where owner_id = auth.uid()
    )
  )
  with check (
    bucket_id = 'alertrox-files'
    and (storage.foldername(name))[1] in (
      select device_id from public.devices where owner_id = auth.uid()
    )
  );

-- Bitti bildirimi
select 'AlertRox güvenlik migrasyonu başarıyla tamamlandı!' as status;
