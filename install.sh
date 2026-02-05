#!/bin/bash
# =============================================================================
# UpDive Logstash Konfiguratsiyasini O'rnatish Skripti
# =============================================================================

set -e

# Ranglar
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      UpDive Logstash Konfiguratsiyasini O'rnatish             ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Root tekshiruvi
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Xato: Bu skriptni root yoki sudo orqali ishga tushirishingiz kerak${NC}"
    exit 1
fi

# Logstash o'rnatilganligini tekshirish
if ! command -v logstash &> /dev/null && [ ! -f /etc/logstash/logstash.yml ] && [ ! -f /usr/share/logstash/bin/logstash ]; then
    echo -e "${RED}Xato: Logstash topilmadi. Avval logstash o'rnating.${NC}"
    exit 1
fi

# Logstash konfiguratsiya papkasini aniqlash
LOGSTASH_CONFIG_DIR=""
LOGSTASH_PIPELINE_DIR=""

if [ -d "/etc/logstash" ]; then
    LOGSTASH_CONFIG_DIR="/etc/logstash"
    LOGSTASH_PIPELINE_DIR="/etc/logstash/conf.d"
elif [ -d "/usr/share/logstash/config" ]; then
    LOGSTASH_CONFIG_DIR="/usr/share/logstash/config"
    LOGSTASH_PIPELINE_DIR="/usr/share/logstash/pipeline"
else
    echo -e "${YELLOW}Logstash konfiguratsiya papkasi topilmadi.${NC}"
    read -p "Logstash konfiguratsiya papkasining to'liq yo'lini kiriting: " LOGSTASH_CONFIG_DIR
    LOGSTASH_PIPELINE_DIR="$LOGSTASH_CONFIG_DIR/conf.d"
fi

echo -e "${GREEN}Logstash konfiguratsiya papkasi: ${LOGSTASH_CONFIG_DIR}${NC}"
echo -e "${GREEN}Pipeline papkasi: ${LOGSTASH_PIPELINE_DIR}${NC}"
echo ""

# Backup olish
echo -e "${YELLOW}[1/7] Mavjud konfiguratsiyalarni backup qilish...${NC}"
if [ -d "$LOGSTASH_PIPELINE_DIR" ] && [ "$(ls -A $LOGSTASH_PIPELINE_DIR/*.conf 2>/dev/null)" ]; then
    BACKUP_DIR="${LOGSTASH_PIPELINE_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    cp -r "$LOGSTASH_PIPELINE_DIR"/*.conf "$BACKUP_DIR/" 2>/dev/null || true
    echo -e "${GREEN}Backup yaratildi: $BACKUP_DIR${NC}"
else
    echo -e "${YELLOW}Mavjud konfiguratsiyalar topilmadi, backup o'tkazildi.${NC}"
fi

# Pipeline papkasini yaratish
echo -e "${YELLOW}[2/7] Pipeline papkasini yaratish...${NC}"
mkdir -p "$LOGSTASH_PIPELINE_DIR"
echo -e "${GREEN}Pipeline papkasi tayyor ✓${NC}"

# Konfiguratsiya fayllarini ko'chirish
echo -e "${YELLOW}[3/7] Konfiguratsiya fayllarini ko'chirish...${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_SOURCE_DIR="$SCRIPT_DIR/conf.d"

if [ ! -d "$CONF_SOURCE_DIR" ]; then
    echo -e "${RED}Xato: conf.d papkasi topilmadi: $CONF_SOURCE_DIR${NC}"
    exit 1
fi

# .conf fayllarini ko'chirish
cp "$CONF_SOURCE_DIR"/*.conf "$LOGSTASH_PIPELINE_DIR/" 2>/dev/null || {
    echo -e "${RED}Xato: Konfiguratsiya fayllarini ko'chirib bo'lmadi${NC}"
    exit 1
}

echo -e "${GREEN}Konfiguratsiya fayllari ko'chirildi ✓${NC}"

# Fayl huquqlarini o'rnatish
echo -e "${YELLOW}[4/7] Fayl huquqlarini o'rnatish...${NC}"

# Logstash foydalanuvchisini aniqlash
LOGSTASH_USER="logstash"
if ! id "$LOGSTASH_USER" &>/dev/null; then
    LOGSTASH_USER="root"
    echo -e "${YELLOW}Logstash foydalanuvchisi topilmadi, root ishlatilmoqda${NC}"
fi

chown -R "$LOGSTASH_USER:$LOGSTASH_USER" "$LOGSTASH_PIPELINE_DIR"
chmod 644 "$LOGSTASH_PIPELINE_DIR"/*.conf

echo -e "${GREEN}Fayl huquqlari o'rnatildi ✓${NC}"

# Elasticsearch sozlamalarini so'rash
echo -e "${YELLOW}[5/7] Elasticsearch sozlamalari...${NC}"
read -p "Elasticsearch host (default: http://localhost:9908): " ES_HOST
ES_HOST=${ES_HOST:-"http://localhost:9908"}

read -p "Elasticsearch user (bo'sh qoldirish - autentifikatsiya yo'q): " ES_USER
read -sp "Elasticsearch password (agar user kiritilgan bo'lsa): " ES_PASS
echo ""

# 99-output.conf faylini yangilash
OUTPUT_CONF="$LOGSTASH_PIPELINE_DIR/99-output.conf"
if [ -f "$OUTPUT_CONF" ]; then
    # hosts ni yangilash
    sed -i "s|hosts => \[.*\]|hosts => [\"$ES_HOST\"]|g" "$OUTPUT_CONF"
    
    # User va password qo'shish (agar ikkalasi ham kiritilgan bo'lsa)
    if [ -n "$ES_USER" ] && [ -n "$ES_PASS" ]; then
        # Agar user/password qatorlari izohda bo'lsa, izohni olib tashlash
        sed -i "s|# user =>|user =>|g" "$OUTPUT_CONF"
        sed -i "s|# password =>|password =>|g" "$OUTPUT_CONF"
        # Qiymatlarni yangilash
    sed -i "s|^[[:space:]]*user => \".*\"|    user => \"$ES_USER\"|g" "$OUTPUT_CONF"
    sed -i "s|^[[:space:]]*password => \".*\"|    password => \"$ES_PASS\"|g" "$OUTPUT_CONF"
  else
    # Agar user yoki password bo'sh bo'lsa, ularni izohda qoldirish
    sed -i "s|^[[:space:]]*user =>|    # user =>|g" "$OUTPUT_CONF"
    sed -i "s|^[[:space:]]*password =>|    # password =>|g" "$OUTPUT_CONF"
  fi
    
    echo -e "${GREEN}Elasticsearch sozlamalari yangilandi ✓${NC}"
fi

# Port tekshiruvi
echo -e "${YELLOW}[6/7] Port 5044 tekshiruvi...${NC}"
if netstat -tlnp 2>/dev/null | grep -q ":5044 " || ss -tlnp 2>/dev/null | grep -q ":5044 "; then
    echo -e "${GREEN}Port 5044 ochiq ✓${NC}"
else
    echo -e "${YELLOW}Port 5044 yopiq. Firewall qoidasini qo'shishni xohlaysizmi? (y/n)${NC}"
    read -p "> " ADD_FIREWALL
    if [ "$ADD_FIREWALL" = "y" ] || [ "$ADD_FIREWALL" = "Y" ]; then
        if command -v firewall-cmd &> /dev/null; then
            firewall-cmd --permanent --add-port=5044/tcp
            firewall-cmd --reload
            echo -e "${GREEN}Firewall qoidasi qo'shildi ✓${NC}"
        elif command -v ufw &> /dev/null; then
            ufw allow 5044/tcp
            echo -e "${GREEN}UFW qoidasi qo'shildi ✓${NC}"
        else
            echo -e "${YELLOW}Firewall topilmadi, qo'lda qo'shing${NC}"
        fi
    fi
fi

# Konfiguratsiyani tekshirish
echo -e "${YELLOW}[7/7] Konfiguratsiyani tekshirish...${NC}"

# Logstash binary topish
LOGSTASH_BIN=""
if [ -f "/usr/share/logstash/bin/logstash" ]; then
    LOGSTASH_BIN="/usr/share/logstash/bin/logstash"
elif command -v logstash &> /dev/null; then
    LOGSTASH_BIN=$(which logstash)
else
    echo -e "${YELLOW}Logstash binary topilmadi, tekshiruv o'tkazildi${NC}"
fi

if [ -n "$LOGSTASH_BIN" ]; then
    if sudo -u "$LOGSTASH_USER" "$LOGSTASH_BIN" --config.test_and_exit --path.config="$LOGSTASH_PIPELINE_DIR" 2>&1 | grep -q "Configuration OK"; then
        echo -e "${GREEN}Konfiguratsiya to'g'ri ✓${NC}"
    else
        echo -e "${RED}Konfiguratsiyada xatolar bor!${NC}"
        echo -e "${YELLOW}Loglarni ko'rish uchun:${NC}"
        echo "sudo $LOGSTASH_BIN --config.test_and_exit --path.config=$LOGSTASH_PIPELINE_DIR"
        read -p "Davom etishni xohlaysizmi? (y/n): " CONTINUE
        if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
            exit 1
        fi
    fi
fi

# Logstash xizmatini qayta ishga tushirish
echo ""
echo -e "${YELLOW}Logstash xizmatini qayta ishga tushirishni xohlaysizmi? (y/n)${NC}"
read -p "> " RESTART
if [ "$RESTART" = "y" ] || [ "$RESTART" = "Y" ]; then
    if systemctl is-active --quiet logstash 2>/dev/null; then
        systemctl restart logstash
        echo -e "${GREEN}Logstash qayta ishga tushirildi ✓${NC}"
        sleep 3
        systemctl status logstash --no-pager
    elif systemctl is-active --quiet logstash.service 2>/dev/null; then
        systemctl restart logstash.service
        echo -e "${GREEN}Logstash qayta ishga tushirildi ✓${NC}"
        sleep 3
        systemctl status logstash.service --no-pager
    else
        echo -e "${YELLOW}Logstash xizmati topilmadi, qo'lda qayta ishga tushiring${NC}"
    fi
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                 O'rnatish yakunlandi!                         ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Konfiguratsiya papkasi: ${BLUE}$LOGSTASH_PIPELINE_DIR${NC}"
echo -e "Logstash holati:        ${BLUE}sudo systemctl status logstash${NC}"
echo -e "Loglarni ko'rish:       ${BLUE}sudo journalctl -u logstash -f${NC}"
echo -e "API tekshirish:         ${BLUE}curl http://localhost:9600${NC}"
echo -e "Port tekshirish:        ${BLUE}netstat -tlnp | grep 5044${NC}"
echo ""

