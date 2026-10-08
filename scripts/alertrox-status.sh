#!/bin/bash
# AlertRox — Servis ve Sağlık Durumu Görüntüleme Scripti

echo "=========================================================="
echo "  🚨 AlertRox Servis & Sistem Durumu"
echo "=========================================================="

echo ""
echo "--- [1] systemd Kullanıcı Servis Durumu ---"
if systemctl --user is-active --quiet alertrox.service; then
    echo "✅ Servis Durumu: ÇALIŞIYOR (active)"
else
    echo "⚠️ Servis Durumu: ÇALIŞMIYOR veya DURDURULDU"
fi
systemctl --user status alertrox.service --no-pager -l || true

echo ""
echo "--- [2] Kullanıcı Oturum & Linger Durumu ---"
echo "Kullanıcı: $USER (UID: $UID)"
loginctl show-user "$USER" --property=Linger 2>/dev/null || echo "Linger: Bilinmiyor"
echo "XDG_CURRENT_DESKTOP: $XDG_CURRENT_DESKTOP"
echo "XDG_SESSION_TYPE   : $XDG_SESSION_TYPE"
echo "WAYLAND_DISPLAY    : $WAYLAND_DISPLAY"
echo "DISPLAY            : $DISPLAY"

echo ""
echo "--- [3] Çalışan AlertRox Süreçleri (Çift Süreç Denetimi) ---"
PROCS=$(pgrep -a -f "agent\.main" || true)
if [ -n "$PROCS" ]; then
    echo "$PROCS"
    COUNT=$(echo "$PROCS" | wc -l)
    if [ "$COUNT" -gt 1 ]; then
        echo "⚠️ DİKKAT: Birden fazla ($COUNT adet) AlertRox süreci tespit edildi!"
    else
        echo "✅ Tek kopya düzgün çalışıyor."
    fi
else
    echo "❌ Arka planda çalışan agent süreci bulunamadı."
fi

echo ""
echo "--- [4] Kilit Dosyası (Lock File) ---"
LOCK_FILE="/run/user/$UID/alertrox.lock"
if [ -f "$LOCK_FILE" ]; then
    LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "?")
    echo "Kilit dosyası mevcut: $LOCK_FILE (PID: $LOCK_PID)"
else
    echo "Kilit dosyası bulunmuyor (servis kapalı olabilir)."
fi

echo ""
echo "--- [5] Kritik Yardımcı Araçlar ---"
for cmd in wpctl pactl qdbus6 notify-send spectacle gtk-launch gio wl-copy xclip; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "  • $cmd: ✅ Mevcut ($(command -v "$cmd"))"
    else
        echo "  • $cmd: ❌ Eksik"
    fi
done

echo ""
echo "--- [6] Son 20 Journal Günlüğü (systemd logları) ---"
journalctl --user -u alertrox.service -n 20 --no-pager || true

echo ""
echo "=========================================================="
echo "İpuçları:"
echo "  Servisi yeniden başlatmak için : systemctl --user restart alertrox"
echo "  Servisi durdurmak için        : systemctl --user stop alertrox"
echo "  Canlı logları izlemek için    : journalctl --user -u alertrox -f"
echo "=========================================================="
