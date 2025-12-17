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

SERVICE_NAME="openvpn"
CONTAINER_NAME="openvpn-server"

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

##################################
# Проверки
##################################
need_cmd docker
need_cmd docker-compose

##################################
# Аргументы
##################################
if [[ -z "${1:-}" ]]; then
  die "Использование: $0 ИМЯ_КЛИЕНТА"
fi

CLIENT_NAME="$1"

##################################
# Проверка окружения
##################################
docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$" \
  || die "Контейнер ${CONTAINER_NAME} не запущен"

[[ -d "${PKI_DIR}" ]] || die "PKI не инициализирована"

##################################
# Проверка существования сертификата
##################################
if [[ ! -f "${PKI_DIR}/issued/${CLIENT_NAME}.crt" ]]; then
  die "Сертификат клиента '${CLIENT_NAME}' не найден"
fi

##################################
# Проверка: не отозван ли уже
##################################
if grep -q "^R.*CN=${CLIENT_NAME}\$" "${PKI_DIR}/index.txt"; then
  die "Клиент '${CLIENT_NAME}' уже отозван"
fi

##################################
# Подтверждение
##################################
echo -e "${YELLOW}ВНИМАНИЕ${NC}"
echo -e "Вы собираетесь ОТОЗВАТЬ клиента: ${RED}${CLIENT_NAME}${NC}"
echo -e "Это действие необратимо."
echo ""
read -rp "Продолжить? [yes/no]: " CONFIRM

[[ "${CONFIRM}" == "yes" ]] || die "Отменено пользователем"

##################################
# Отзыв сертификата
##################################
echo -e "${CYAN}Отзыв сертификата клиента...${NC}"
docker-compose exec -T "${SERVICE_NAME}" \
  easyrsa revoke "${CLIENT_NAME}"

##################################
# Генерация CRL
##################################
echo -e "${CYAN}Генерация CRL...${NC}"
docker-compose exec -T "${SERVICE_NAME}" \
  easyrsa gen-crl

##################################
# Проверка CRL
##################################
[[ -f "${PKI_DIR}/crl.pem" ]] || die "crl.pem не создан"

chmod 644 "${PKI_DIR}/crl.pem"

##################################
# Перезапуск OpenVPN
##################################
echo -e "${CYAN}Перезапуск OpenVPN...${NC}"
docker-compose restart openvpn

##################################
# Удаление ovpn (опционально)
##################################
OVPN_FILE="${CLIENTS_DIR}/${CLIENT_NAME}.ovpn"
if [[ -f "${OVPN_FILE}" ]]; then
  echo ""
  read -rp "Удалить клиентский файл ${OVPN_FILE}? [y/N]: " REMOVE
  if [[ "${REMOVE}" == "y" || "${REMOVE}" == "Y" ]]; then
    rm -f "${OVPN_FILE}"
    echo -e "${GREEN}Файл удалён${NC}"
  fi
fi

##################################
# Итог
##################################
echo ""
echo -e "${PURPLE}=== КЛИЕНТ ОТОЗВАН ===${NC}"
echo -e "Имя: ${CLIENT_NAME}"
echo -e "CRL: ${PKI_DIR}/crl.pem"
echo -e "${GREEN}Отзыв вступил в силу${NC}"
