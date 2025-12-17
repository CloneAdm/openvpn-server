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
DOCKER_IMAGE="openvpn-server:local"
PROTO="udp"
SERVER_CERT_NAME="__server__"


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
  curl -fs https://ifconfig.me || die "Не удалось определить публичный IP"
}

##################################
# Проверки зависимостей
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
# Сборка образа
##################################
echo -e "${CYAN}Сборка Docker-образа...${NC}"
docker build -t "$DOCKER_IMAGE" .
echo -e "${GREEN}OK${NC}\n"

##################################
# Генерация конфигов и PKI
##################################
echo -e "${CYAN}Генерация конфигов и PKI внутри временного контейнера...${NC}"

# Генерация базового конфига
docker run --rm \
    -e EASYRSA_BATCH=1 \
    -e EASYRSA_REQ_CN="MyVPN CA" \
    -v "$DATA_DIR:/etc/openvpn" \
    "$DOCKER_IMAGE" ovpn_genconfig -u "${PROTO}://${SERVER_ADDRESS}" -C AES-256-GCM -a SHA512 -c -e "verb 3"

# Инициализация PKI без интерактива
docker run --rm \
    -e EASYRSA_BATCH=1 \
    -e EASYRSA_REQ_CN="MyVPN CA" \
    -v "$DATA_DIR:/etc/openvpn" \
    "$DOCKER_IMAGE" ovpn_initpki nopass

# Создание серверного сертификата nopass
docker run --rm \
    -e EASYRSA_BATCH=1 \
    -v "$DATA_DIR:/etc/openvpn" \
    "$DOCKER_IMAGE" easyrsa build-server-full "$SERVER_CERT_NAME" nopass


echo -e "${GREEN}PKI и конфиги готовы, файлы сохранены в ${DATA_DIR}${NC}\n"

docker run --rm \
  -e SERVER_ADDRESS="$SERVER_ADDRESS" \
  -v "$DATA_DIR:/etc/openvpn" \
  "$DOCKER_IMAGE" /etc/openvpn-scripts/init-server-inner.sh

echo -e "${GREEN}[OK] Конфигурация обновлена из шаблона${NC}\n"

##################################
# Поднятие OpenVPN контейнера
##################################
echo -e "${CYAN}Запуск OpenVPN контейнера...${NC}"
docker compose up -d

echo -e "${PURPLE}=== ГОТОВО ===${NC}"
