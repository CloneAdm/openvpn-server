#!/bin/bash
set -euo pipefail

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

: "${SERVER_ADDRESS:?${RED}Ошибка:${NC} SERVER_ADDRESS обязателен}"

# Настройки VPN
PORT=1194
PROTO=udp

VPN_NET="192.168.255.0"
VPN_MASK="255.255.255.0"

DNS1="1.1.1.1"
DNS2="8.8.8.8"

VERB=3
SERVER_CERT_NAME="__server__"

TEMPLATE="/etc/openvpn-scripts/openvpn.conf.template"
CONF="/etc/openvpn/openvpn.conf"

# Генерация openvpn.conf из шаблона
echo -e "${CYAN}[*] Генерация openvpn.conf из шаблона...${NC}"

if [[ ! -f "$TEMPLATE" ]]; then
  echo -e "${RED}[ERROR] Шаблон $TEMPLATE не найден${NC}"
  exit 1
fi

# Замена переменных в шаблоне
sed \
  -e "s|{{PORT}}|${PORT}|g" \
  -e "s|{{PROTO}}|${PROTO}|g" \
  -e "s|{{VPN_NET}}|${VPN_NET}|g" \
  -e "s|{{VPN_MASK}}|${VPN_MASK}|g" \
  -e "s|{{DNS1}}|${DNS1}|g" \
  -e "s|{{DNS2}}|${DNS2}|g" \
  -e "s|{{VERB}}|${VERB}|g" \
  -e "s|{{SERVER_CERT_NAME}}|${SERVER_CERT_NAME}|g" \
  "$TEMPLATE" > "$CONF"

echo -e "${GREEN}[OK] Конфигурация openvpn.conf сгенерирована${NC}"
echo -e "${PURPLE}[=== ГОТОВО ===]${NC}"
