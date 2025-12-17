#!/bin/bash
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

##################################
# Пути
##################################
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DATA_DIR="${ROOT_DIR}/data"
PKI_DIR="${DATA_DIR}/pki"

CLIENTS_DIR="${ROOT_DIR}/clients"
TEMPLATE="${ROOT_DIR}/templates/client.ovpn.template"

SERVICE_NAME="openvpn"
CONTAINER_NAME="openvpn-server"

SERVER_PORT="1194"

##################################
# Утилиты
##################################
die() {
  echo -e "${RED}Ошибка:${NC} $1"
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "$1 не найден"
}

detect_public_ip() {
  curl -fsS https://ifconfig.me || \
  die "Не удалось определить публичный IP"
}

##################################
# Проверки
##################################
need_cmd docker
need_cmd docker-compose
need_cmd sed
need_cmd curl

##################################
# Аргументы
##################################
if [[ -z "${1:-}" ]]; then
  die "Использование: $0 ИМЯ_КЛИЕНТА [IP_ИЛИ_DNS_СЕРВЕРА]"
fi

CLIENT_NAME="$1"

if [[ -n "${2:-}" ]]; then
  SERVER_ADDR="$2"
else
  echo -e "${CYAN}Определяю адрес сервера...${NC}"
  SERVER_ADDR="$(detect_public_ip)"
fi

##################################
# Проверка окружения
##################################
docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$" \
  || die "Контейнер ${CONTAINER_NAME} не запущен"

[[ -d "${PKI_DIR}" ]] || die "PKI не инициализирована"

[[ -f "${TEMPLATE}" ]] || die "Шаблон клиента не найден: ${TEMPLATE}"

if [ ! -d "$CLIENTS_DIR" ]; then
    echo -e "${CYAN}Создаю директорию clients...${NC}/"
    mkdir -p "${CLIENTS_DIR}"
    echo -e "${GREEN}OK!${NC}\n"
fi

##################################
# Проверка существования клиента
##################################
if [[ -f "${CLIENTS_DIR}/${CLIENT_NAME}.ovpn" ]]; then
  die "Клиент ${CLIENT_NAME} уже существует (${CLIENTS_DIR}/${CLIENT_NAME}.ovpn)"
fi

##################################
# Генерация сертификата
##################################
echo -e "${CYAN}Создание сертификата клиента:${NC} ${CLIENT_NAME}"
docker-compose exec -T "${SERVICE_NAME}" \
  easyrsa build-client-full "${CLIENT_NAME}" nopass

##################################
# Генерация ovpn
##################################
echo -e "${CYAN}Формирование .ovpn файла...${NC}"

TMP_OVPN="$(mktemp)"

sed \
  -e "s|{{SERVER_ADDR}}|${SERVER_ADDR}|g" \
  -e "s|{{SERVER_PORT}}|${SERVER_PORT}|g" \
  "${TEMPLATE}" > "${TMP_OVPN}"

##################################
# Вставка ключей
##################################
sed -i "/<ca>/r ${PKI_DIR}/ca.crt" "${TMP_OVPN}"
sed -i "/<cert>/r ${PKI_DIR}/issued/${CLIENT_NAME}.crt" "${TMP_OVPN}"
sed -i "/<key>/r ${PKI_DIR}/private/${CLIENT_NAME}.key" "${TMP_OVPN}"
sed -i "/<tls-crypt>/r ${PKI_DIR}/ta.key" "${TMP_OVPN}"

##################################
# Финализация
##################################
OUT_FILE="${CLIENTS_DIR}/${CLIENT_NAME}.ovpn"
mv "${TMP_OVPN}" "${OUT_FILE}"

chmod 600 "${OUT_FILE}"
chown "$(id -u):$(id -g)" "${OUT_FILE}"

##################################
# Результат
##################################
echo ""
echo -e "${GREEN}=== КЛИЕНТ СОЗДАН ===${NC}"
echo -e "Имя: ${CLIENT_NAME}"
echo -e "Сервер: ${SERVER_ADDR}:${SERVER_PORT}"
echo -e "Файл: ${OUT_FILE}"
echo ""

if command -v qrencode >/dev/null 2>&1; then
  echo -e "${CYAN}QR-код:${NC}"
  qrencode -t ANSIUTF8 < "${OUT_FILE}"
fi
