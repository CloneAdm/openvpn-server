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

get_public_ip() {
  curl -fs https://api.ipify.org || die "Не удалось определить публичный IP"
}

##################################
# Проверки
##################################
echo -e "${CYAN}Проверка зависимостей...${NC}"
need_cmd docker
need_cmd docker-compose
need_cmd curl
echo -e "${GREEN}OK${NC}\n"

##################################
# IP сервера
##################################
SERVER_ADDRESS="${1:-}"
if [[ -z "$SERVER_ADDRESS" ]]; then
  echo -e "${CYAN}Определяю публичный IP сервера...${NC}"
  SERVER_ADDRESS="$(get_public_ip)"
fi
echo -e "${GREEN}IP сервера: ${SERVER_ADDRESS}${NC}\n"

##################################
# Подготовка data/
##################################
if [[ ! -d "$DATA_DIR" ]]; then
  echo -e "${CYAN}Создаю data/...${NC}"
  mkdir -p "$DATA_DIR"
fi

##################################
# Проверка прав
##################################
DATA_UID="$(stat -c '%u' "$DATA_DIR")"
CUR_UID="$(id -u)"

if [[ "$DATA_UID" != "$CUR_UID" ]]; then
  echo -e "${YELLOW}Исправляю права на data/...${NC}"
  sudo chown -R "$CUR_UID:$CUR_UID" "$DATA_DIR"
fi

##################################
# Инициализация внутри контейнера
##################################
echo -e "${CYAN}Инициализация OpenVPN внутри контейнера...${NC}"

export SERVER_ADDRESS
docker-compose run --rm \
  -e SERVER_ADDRESS \
  openvpn \
  /etc/openvpn/init-server-inner.sh

##################################
# Запуск
##################################
docker-compose up -d

echo -e "${PURPLE}=== ГОТОВО ===${NC}"
