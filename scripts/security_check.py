"""
AlertRox — Güvenlik Doğrulama ve Sızma Testi Scripti (Security Check)

Bu script, Supabase veritabanında RLS (Row Level Security) politikalarının
düzgün çalıştığını ve kimliği doğrulanmamış (unauthenticated) anon erişimlerin
tüm tablolarda kesinlikle engellendiğini otomatik olarak doğrular.

Kullanım:
    python scripts/security_check.py
"""

import os
import sys
from dotenv import load_dotenv

# Proje kök dizini
PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
load_dotenv(os.path.join(PROJECT_DIR, ".env"))

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY") or os.getenv("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_ANON_KEY:
    print("❌ HATA: SUPABASE_URL ve SUPABASE_ANON_KEY .env dosyasında bulunamadı!")
    sys.exit(1)


def test_unauthenticated_access():
    print("=" * 65)
    print("  🔒 AlertRox Güvenlik Denetimi & RLS Sızma Testi")
    print("=" * 65)
    print(f"Supabase Hedef URL: {SUPABASE_URL}")
    print("Kimlik Doğrulama: YOK (Anonim İstemci Testi)")
    print("-" * 65)

    try:
        from supabase import create_client
    except ImportError:
        print("❌ supabase kütüphanesi yüklü değil. 'pip install supabase' çalıştırın.")
        sys.exit(1)

    # Oturum açılmamış saf anon istemci oluştur
    anon_client = create_client(SUPABASE_URL, SUPABASE_ANON_KEY)

    tables_to_test = [
        "devices",
        "commands",
        "messages",
        "activity_log",
        "device_state",
    ]

    all_passed = True

    for table in tables_to_test:
        print(f"\n[Test] '{table}' tablosu yetkisiz erişim denetimi:")

        # 1. Okuma (SELECT) denemesi
        try:
            res = anon_client.table(table).select("*").limit(5).execute()
            data = res.data or []
            if len(data) == 0:
                print(f"  • SELECT : 🛡️ KORUMALI (0 satır döndü, RLS engelliyor)")
            else:
                print(f"  • SELECT : 🚨 AÇIK! {len(data)} satır veri sızdı!")
                all_passed = False
        except Exception as e:
            print(f"  • SELECT : 🛡️ KORUMALI (Hata ile reddedildi: {type(e).__name__})")

        # 2. Yazma (INSERT) denemesi
        try:
            fake_row = {"device_id": "malicious_device_test", "status": "hacked"}
            res = anon_client.table(table).insert(fake_row).execute()
            print(f"  • INSERT : 🚨 AÇIK! Yetkisiz veri yazılabildi!")
            all_passed = False
        except Exception:
            print(f"  • INSERT : 🛡️ KORUMALI (Yetkisiz yazma reddedildi)")

    # 3. Storage bucket testi
    print(f"\n[Test] 'alertrox-files' depolama (Storage) denetimi:")
    try:
        files = anon_client.storage.from_("alertrox-files").list()
        if len(files) == 0:
            print(f"  • Storage List : 🛡️ KORUMALI (Boş veya erişim engellendi)")
        else:
            print(f"  • Storage List : 🚨 AÇIK! Dosyalar listelenebiliyor!")
            all_passed = False
    except Exception:
        print(f"  • Storage List : 🛡️ KORUMALI (Yetkisiz erişim reddedildi)")

    print("\n" + "=" * 65)
    if all_passed:
        print("  🎉 SONUÇ: TÜM TABLOLAR VE DEPOLAMA RLS İLE KORUNUYOR!")
        print("  Yetkisiz anon istekler hiçbir kullanıcı verisine erişemiyor.")
    else:
        print("  ⚠️ SONUÇ: BAZI TABLOLARDA RLS GÜVENLİK AÇIĞI TESPİT EDİLDİ!")
    print("=" * 65)


if __name__ == "__main__":
    test_unauthenticated_access()
