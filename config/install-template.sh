#!/bin/bash
# =============================================================================
# ECS Index Template o'rnatish skripti
# Elasticsearch'ga ESQL detection uchun to'g'ri mapping o'rnatadi
# =============================================================================

# Sozlamalar
ES_HOST="${ES_HOST:-http://localhost:9200}"
ES_USER="${ES_USER:-elastic}"
ES_PASSWORD="${ES_PASSWORD:-changeme}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/ecs-index-template.json"

echo "================================================"
echo "  ECS Index Template O'rnatish"
echo "================================================"
echo ""
echo "Elasticsearch: $ES_HOST"
echo "Template fayli: $TEMPLATE_FILE"
echo ""

# Template mavjudligini tekshirish
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "❌ XATO: Template fayl topilmadi: $TEMPLATE_FILE"
    exit 1
fi

# Elasticsearch'ga ulanishni tekshirish
echo "🔍 Elasticsearch'ga ulanish tekshirilmoqda..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -u "$ES_USER:$ES_PASSWORD" "$ES_HOST")

if [ "$HTTP_CODE" != "200" ]; then
    echo "❌ XATO: Elasticsearch'ga ulanib bo'lmadi (HTTP: $HTTP_CODE)"
    echo "   ES_HOST, ES_USER, ES_PASSWORD o'zgaruvchilarini tekshiring"
    exit 1
fi

echo "✅ Elasticsearch'ga ulandi"
echo ""

# Index template o'rnatish
echo "📦 Index template o'rnatilmoqda (updive-*)..."

RESPONSE=$(curl -s -X PUT "$ES_HOST/_index_template/updive-ecs-template" \
    -u "$ES_USER:$ES_PASSWORD" \
    -H "Content-Type: application/json" \
    -d @"$TEMPLATE_FILE")

if echo "$RESPONSE" | grep -q '"acknowledged":true'; then
    echo "✅ Template muvaffaqiyatli o'rnatildi!"
else
    echo "⚠️  Javob: $RESPONSE"
fi

echo ""
echo "================================================"
echo "  Tekshirish"
echo "================================================"

# O'rnatilgan templateni tekshirish
echo ""
echo "📋 O'rnatilgan template:"
curl -s -u "$ES_USER:$ES_PASSWORD" "$ES_HOST/_index_template/updive-ecs-template" | head -c 500
echo "..."

echo ""
echo ""
echo "================================================"
echo "  Keyingi qadamlar"
echo "================================================"
echo ""
echo "1. Mavjud indekslarni yangilash (ixtiyoriy):"
echo "   Agar allaqachon updive-* indekslar bo'lsa, ularni"
echo "   reindex qilish yoki yangi indekslarni kutish kerak."
echo ""
echo "2. Logstash'ni qayta ishga tushiring:"
echo "   docker-compose restart logstash"
echo ""
echo "3. ESQL query test qilish (Kibana Dev Tools):"
echo '   FROM updive-*'
echo '   | WHERE event.category == "process"'
echo '   | LIMIT 10'
echo ""
echo "✅ Tayyor!"
