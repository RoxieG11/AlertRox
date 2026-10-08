-- ══════════════════════════════════════════════════════════════════════════════
-- AlertRox v1.5.0 — Özellik & Güvenlik Genişletme Migrasyonu
-- ══════════════════════════════════════════════════════════════════════════════
-- Bu SQL dosyasını Supabase Dashboard > SQL Editor alanına yapıştırıp çalıştırın (Run).
-- 
-- Yapılan Değişiklikler:
-- 1. commands tablosundaki check_valid_command_type kısıtını tüm yeni komutları (ses, pano, uygulamalar) kapsayacak şekilde genişletir.
-- 2. validate_command_payload tetikleyicisine yeni komutlar için güvenlik ve sınır kontrolleri ekler.
-- 3. Cihaz anlık durumunu (ses, mute, pano hash, yüklü/açık uygulama önbelleği) güvenli saklamak için RLS korumalı device_state tablosunu oluşturur.
-- ══════════════════════════════════════════════════════════════════════════════

-- 1. COMMANDS TABLOSU KISITLAMASINI GÜNCELLE
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
    'mic_record',
    'set_volume',
    'volume_step',
    'toggle_mute',
    'set_mute',
    'get_volume',
    'media_control',
    'set_clipboard',
    'get_clipboard',
    'launch_app',
    'close_app',
    'kill_process',
    'get_installed_apps',
    'get_running_apps',
    'refresh_apps'
  ));

-- 2. KOMUT DOĞRULAMA TETİKLEYİCİSİ (VALIDATE COMMAND PAYLOAD)
create or replace function public.validate_command_payload()
returns trigger as $$
declare
  delay_val int;
  dur_val int;
  vol_val int;
  text_val text;
begin
  -- Otomatik owner_id atama
  if new.owner_id is null then
    new.owner_id := auth.uid();
  end if;

  -- 1. Shutdown kontrolü: delay 5 ile 86400 arasında olmalı
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

  -- 2. mic_record kontrolü: duration 1 ile 120 arasında olmalı
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

  -- 3. Ses kontrolü: volume 0 ile 100 arasında olmalı
  if new.command_type = 'set_volume' and new.payload ? 'volume' then
    begin
      vol_val := (new.payload->>'volume')::int;
      if vol_val < 0 or vol_val > 100 then
        raise exception 'Ses seviyesi 0 ile 100 arasında olmalıdır.';
      end if;
    exception when others then
      raise exception 'Geçersiz set_volume formatı.';
    end;
  end if;

  -- 4. Pano kontrolü: metin boyutu maksimum 100 KB (102400 bayt)
  if new.command_type = 'set_clipboard' and new.payload ? 'text' then
    text_val := new.payload->>'text';
    if length(text_val) > 102400 then
      raise exception 'Pano içeriği 100 KB sınırını aşamaz.';
    end if;
  end if;

  return new;
end;
$$ language plpgsql;

drop trigger if exists trigger_validate_command_payload on public.commands;
create trigger trigger_validate_command_payload
  before insert or update on public.commands
  for each row execute function public.validate_command_payload();


-- 3. DEVICE_STATE TABLOSU & RLS GÜVENLİĞİ
create table if not exists public.device_state (
  device_id text primary key references public.devices(device_id) on delete cascade,
  owner_id uuid references auth.users(id) on delete cascade default auth.uid(),
  volume int default 50 check (volume >= 0 and volume <= 100),
  muted boolean default false,
  clipboard_hash text,
  installed_apps jsonb default '[]'::jsonb,
  running_apps jsonb default '[]'::jsonb,
  live_until timestamptz,
  updated_at timestamptz default now()
);

-- RLS Etkinleştir
alter table public.device_state enable row level security;

-- Güvenlik Politikası: Sadece oturum açmış cihaz sahibi erişebilir
drop policy if exists "Authenticated users can manage own device_state" on public.device_state;
create policy "Authenticated users can manage own device_state"
  on public.device_state
  for all
  to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

-- İzinler
grant select, insert, update, delete on table public.device_state to authenticated;
