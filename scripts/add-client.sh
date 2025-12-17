#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="openvpn-server"
CLIENT_NAME="${1:-}"
SERVER_ADDR="${2:-}"

if [[ -z "$CLIENT_NAME" ]]; then
  echo "Использование: $0 CLIENT_NAME [SERVER_ADDR]"
  exit 1
fi

if [[ -z "$SERVER_ADDR" ]]; then
  SERVER_ADDR="$(curl -fsS https://api.ipify.org)"
fi

echo "[*] Генерация клиента внутри контейнера..."
docker exec \
  -e CLIENT_NAME="$CLIENT_NAME" \
  -e SERVER_ADDR="$SERVER_ADDR" \
  "$CONTAINER_NAME" \
  /etc/openvpn/add-client-inner.sh

OUT="./clients/${CLIENT_NAME}.ovpn"

echo "[*] Копирование файла на хост..."
docker cp \
  "${CONTAINER_NAME}:/etc/openvpn/clients/${CLIENT_NAME}.ovpn" \
  "$OUT"

chmod 600 "$OUT"

echo
echo "✔ Клиент создан:"
echo "  $OUT"
