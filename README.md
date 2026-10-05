# 🚨 AlertRox

> **AlertRox**, bilgisayarınız açıldığında sizi anında bilgilendiren ve telefonunuzdan uzaktan kapatmanızı/kilitlemenizi sağlayan **%100 Python** tabanlı açık kaynaklı bir güvenlik aracıdır.

---

## ✨ Özellikler

* 🔔 **Açılış Uyarısı:** Bilgisayar açıldığı anda Supabase üzerinden anlık bildirim.
* 🛑 **Uzaktan Kapatma:** Dışarıdayken tek tıkla evdeki bilgisayarı güvenle kapatma.
* 🔒 **Ekran Kilitleme:** Bilgisayarı anında kilit moduna geçirme.
* 📱 **Mobil Uygulama:** KivyMD ile hazırlanmış, Android'de çalışan şık mobil arayüz.
* ☁️ **Sıfır Maliyet:** Ücretsiz Supabase katmanı ile modem portu açmadan çalışır.
* 🛡️ **Gizlilik Odaklı:** API anahtarlarınız yalnızca kendi cihazlarınızda saklanır.

---

## 🏗️ Mimari

```
Linux PC (Arka Plan Servisi)  <───>  Supabase (Bulut Köprüsü)  <───>  Android Cihaz (KivyMD APK)
```

---

## 🚀 Kurulum

### 1. Supabase Kurulumu
1. [supabase.com](https://supabase.com) adresinden ücretsiz bir proje oluşturun.
2. SQL Editöründen `devices` tablosunu oluşturun:
   ```sql
   create table devices (
     id text primary key,
     name text not null,
     status text default 'offline',
     last_boot timestamptz,
     command text default 'none',
     updated_at timestamptz default now()
   );
   ```

### 2. PC Ajanının Kurulması
```bash
git clone https://github.com/KULLANICI_ADINIZ/AlertRox.git
cd AlertRox
pip install -r requirements.txt
cp .env.example .env
# .env dosyasını Supabase bilgilerinize göre doldurun
python3 -m agent.main
```

### 3. Mobil Uygulama (Buildozer ile APK Derleme)
```bash
cd mobile
buildozer android debug
```

---

## 📄 Lisans
MIT License
