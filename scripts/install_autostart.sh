#!/bin/bash
# AlertRox — PC Açılışında Otomatik Başlatma Kurulum Scripti (systemd)

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_EXEC="$PROJECT_DIR/venv/bin/python"
SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$SERVICE_DIR/alertrox.service"

echo "============================================="
echo "  🚨 AlertRox Otomatik Başlatma Kurulumu"
echo "============================================="
echo "Proje Dizini: $PROJECT_DIR"
echo "Python: $PYTHON_EXEC"

if [ ! -f "$PYTHON_EXEC" ]; then
    echo "❌ HATA: venv bulunamadı! Lütfen önce 'python -m venv venv' yapın."
    exit 1
fi

# systemd kullanıcı servis klasörünü oluştur
mkdir -p "$SERVICE_DIR"

# Servis dosyasını yaz
cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=AlertRox PC Agent — Bilgisayar Açılış Gözcüsü
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$PROJECT_DIR
ExecStart=$PYTHON_EXEC -m agent.main
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=default.target
EOF

echo "✅ Servis dosyası oluşturuldu: $SERVICE_FILE"

# systemd'yi yenile ve servisi aktif et
systemctl --user daemon-reload
systemctl --user enable alertrox.service
systemctl --user restart alertrox.service

# Bilgisayar açıldığı an (oturum açılmadan bile) başlamasını sağla
loginctl enable-linger "$USER" 2>/dev/null || true

echo ""
echo "🎉 TEBRİKLER! AlertRox artık bilgisayarın her açılışında arka planda OTOMATİK çalışacak!"
echo ""
echo "Servis durumunu kontrol etmek için:"
echo "  systemctl --user status alertrox.service"
echo ""
echo "Durdurmak için:"
echo "  systemctl --user stop alertrox.service"
echo "============================================="
