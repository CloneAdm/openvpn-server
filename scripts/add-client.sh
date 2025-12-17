#!/usr/bin/env bash
set -euo pipefail

##################################
# Цвета
##################################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'


CONTAINER_NAME="openvpn-server"
CLIENT_NAME="${1:-}"
SERVER_ADDR="${2:-}"

if [[ -z "$CLIENT_NAME" ]]; then
  echo "Использование: $0 CLIENT_NAME [SERVER_ADDR]"
  exit 1
fi

if [[ -z "$SERVER_ADDR" ]]; then
  SERVER_ADDR="$(curl -fsS https://ifconfig.me)"
fi
echo -e "${CYAN}Создаю клиент $CLIENT_NAME...${NC}"

echo "[*] Генерация клиента внутри контейнера..."
docker exec \
  -e CLIENT_NAME="$CLIENT_NAME" \
  -e SERVER_ADDR="$SERVER_ADDR" \
  "$CONTAINER_NAME" \
  /etc/openvpn-scripts/add-client-inner.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLIENT_DIR="${ROOT_DIR}/clients"
if [[ ! -d "$CLIENT_DIR" ]]; then
  echo -e "${CYAN}Создаю $CLIENT_DIR...${NC}"
  mkdir -p "$CLIENT_DIR"
fi
OUT="${CLIENT_DIR}/${CLIENT_NAME}.ovpn"

echo "[*] Копирование файла на хост..."
docker cp \
  "${CONTAINER_NAME}:/etc/openvpn/clients/${CLIENT_NAME}.ovpn" \
  "$OUT"

chmod 600 "$OUT"

echo
echo "  Клиент создан:"
echo "  $OUT"
