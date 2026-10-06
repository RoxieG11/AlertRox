# AlertRox Güvenlik Politikası (Security Policy)

Bu belge, AlertRox projesinin güvenlik mimarisini, tehdit modelini ve güvenlik açıklarını bildirme prosedürlerini açıklar.

---

## 🛡️ Tehdit Modeli ve Güvenlik İlkeleri

AlertRox, uzaktaki bir bilgisayarı izleme ve kontrol etme yeteneğine sahip olduğundan katı güvenlik ilkelerine göre tasarlanmıştır:

1. **Sıfır Güven & Kimlik Doğrulama (Zero Trust & Auth):**
   - İstemci uygulamaları (Mobil App ve PC Agent) asla tam yetkili `service_role` anahtarını kullanmaz.
   - Tüm erişimler Supabase Auth (`email/password`) üzerinden kimliği doğrulanmış kullanıcı oturumlarıyla gerçekleşir.
   - Veritabanı tabloları (`devices`, `commands`, `activity_log`, `messages`) Row Level Security (RLS) ile korunur. Kullanıcılar yalnızca kendi `owner_id = auth.uid()` kimliklerine ait verilere erişebilir. `anon` rolünün doğrudan yetkisi bulunmaz.

2. **Zaman Duyarlı Komut Kuyruğu (Temporal Guard):**
   - Komutlar oluşturulduktan sonra en fazla **60 saniye** geçerlidir. 60 saniyeden eski bekleyen komutlar çalıştırılmaz, otomatik olarak `expired` durumuna alınır.
   - Bilgisayar ilk açıldığında geçmişten kalan bekleyen komutlar temizlenir.

3. **Girdi Doğrulama ve Kısıtlamalar:**
   - Komut parametreleri (örneğin kapatma süresi `5 <= delay <= 86400`, ses kaydı `1 <= duration <= 120`) hem veritabanı kısıtlamalarıyla hem de Python Agent tarafında doğrulanır ve sınırlandırılır.
   - Bilinmeyen komutlar veya bozuk parametreler çalıştırılmaz.

4. **Kullanıcı Şeffaflığı ve Gizlilik (Transparency):**
   - Web kamerası çekimi, mikrofon kaydı veya ekran görüntüsü alındığında PC masaüstünde görünür bir yerel bildirim gösterilir ve bu eylem kalıcı olarak günlüğe (`activity_log`) kaydedilir.

5. **Depolama ve Cihaz Güvenliği:**
   - Üretilen medya dosyaları (`alertrox-files`) gizli (private) bucket'ta tutulur.
   - İmzalı indirme URL'leri en fazla **10 dakika (600 saniye)** geçerlidir.
   - Mobil uygulamada kimlik bilgileri ve oturum anahtarları Android Keystore tabanlı `flutter_secure_storage` içinde şifrelenir. Android sistem yedeklemeleri (`allowBackup="false"`) engellenmiştir.

---

## 🔒 Güvenli Kurulum Yönergeleri

1. `.env` dosyasını asla GitHub'a veya genel alanlara yüklemeyin.
2. Linux üzerinde `.env` dosyasının izinlerini sınırlandırın:
   ```bash
   chmod 600 .env
   ```
3. Supabase Dashboard üzerinde:
   - *Authentication > Providers > Email:* "Allow new users to sign up" seçeneğini devre dışı bırakın.
   - Yalnızca güvendiğiniz e-posta ve güçlü şifre kombinasyonlarını tanımlayın.
   - Düzenli aralıklarla API anahtarlarınızı ve JWT secret'ınızı yenileyin (rotate).

---

## 🚨 Güvenlik Açığı Bildirimi (Reporting Vulnerabilities)

AlertRox projesinde herhangi bir güvenlik açığı tespit ederseniz:
- Lütfen GitHub Issues üzerinden herkese açık bildirim **oluşturmayın**.
- GitHub deposundaki **Security > Report a vulnerability** bölümünü kullanın veya doğrudan geliştirici ile iletişime geçin.
- Raporunuzda güvenlik açığının tanımı, etkilenen bileşen ve yeniden üretme adımlarını (PoC) belirtiniz. En kısa sürede inceleme yapılıp yama yayınlanacaktır.
