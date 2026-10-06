#!/bin/bash
set -e
cd "$(dirname "$0")"

if [ -f "venv/bin/python" ]; then
    PYTHON_BIN="./venv/bin/python"
else
    PYTHON_BIN="python3"
fi

if [ ! -f ".env" ]; then
    echo "⚠️ HATA: .env dosyası bulunamadı!"
    echo "Lütfen .env dosyasını oluşturup Supabase bilgilerinizi girin."
    exit 1
fi

chmod 600 .env 2>/dev/null || true
echo "🚀 AlertRox PC Agent başlatılıyor..."
exec "$PYTHON_BIN" -m agent.main "$@"
