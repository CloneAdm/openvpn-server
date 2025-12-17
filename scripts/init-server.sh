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
TEMPLATE_DIR="${ROOT_DIR}/templates"

CONF_TEMPLATE="${TEMPLATE_DIR}/openvpn.conf.template"
CONF_FILE="${DATA_DIR}/openvpn.conf"

##################################
# Константы
##################################
PORT="1194"
PROTO="udp"

VPN_NET="192.168.255.0"
VPN_MASK="255.255.255.0"

DNS1="1.1.1.1"
DNS2="8.8.8.8"

VERB="3"

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
    curl -s https://api.ipify.org || die "Не удалось определить публичный IP. Передайте его вручную"
}

##################################
# Проверки
##################################
echo -e "${CYAN}Проверка зависимостей...${NC}"
need_cmd docker
need_cmd docker-compose
need_cmd sed
need_cmd curl
echo -e "${GREEN}OK!${NC}\n"

##################################
# Определение публичного IP сервера
##################################
SERVER_ADDRESS="${1:-}"
if [ -z "$SERVER_ADDRESS" ]; then
    echo -e "${CYAN}Определяю публичный IP сервера...${NC}"
    SERVER_ADDRESS=$(get_public_ip)
fi
echo -e "${GREEN}Публичный IP сервера: $SERVER_ADDRESS${NC}\n"

##################################
# Подготовка каталогов
##################################
if [ ! -d "$DATA_DIR" ]; then
    echo -e "${CYAN}Создаю директорию data...${NC}"
    mkdir -p "$DATA_DIR"
    echo -e "${GREEN}OK!${NC}\n"
fi

##################################
# Генерация конфигурации сервера
##################################
if [ ! -f "${DATA_DIR}/ovpn_env.sh" ]; then
    echo -e "${CYAN}Генерируем конфигурацию сервера...${NC}"
    docker-compose run --rm openvpn ovpn_genconfig \
        -u udp://${SERVER_ADDRESS} \
        -C 'AES-256-GCM' \
        -a 'SHA512' \
        -c
    echo -e "${GREEN}Конфигурация сгенерирована${NC}\n"
else
    echo -e "${YELLOW}Конфигурация сервера уже существует — пропускаю${NC}\n"
fi

##################################
# Проверка и исправление прав на data/
##################################
DATA_UID="$(stat -c '%u' "${DATA_DIR}")"
DATA_GID="$(stat -c '%g' "${DATA_DIR}")"

CUR_UID="$(id -u)"
CUR_GID="$(id -g)"

if [[ "${DATA_UID}" != "${CUR_UID}" || "${DATA_GID}" != "${CUR_GID}" ]]; then
    echo -e "${YELLOW}Каталог data/ принадлежит другому пользователю${NC}"
    echo -e "${CYAN}Исправляю права на data/...${NC}"

    sudo chown -R "${CUR_UID}:${CUR_GID}" "${DATA_DIR}"

    echo -e "${GREEN}Права исправлены${NC}\n"
else
    echo -e "${GREEN}Права на data/ корректны — пропускаю${NC}\n"
fi

##################################
# Инициализация PKI
##################################
if [ ! -d "${DATA_DIR}/pki" ]; then
    echo -e "${CYAN}Инициализация PKI...${NC}"
    echo -e "${YELLOW}Будет создан CA — сохраните пароль!${NC}"
    docker-compose run --rm openvpn ovpn_initpki
    echo -e "${GREEN}PKI инициализирована${NC}\n"
else
    echo -e "${YELLOW}PKI уже существует — пропускаю${NC}\n"
fi

##################################
# Генерация серверного сертификата
##################################
if [ ! -f "${DATA_DIR}/pki/issued/${SERVER_CERT_NAME}.crt" ]; then
    echo -e "${CYAN}Создание серверного сертификата (${SERVER_CERT_NAME})...${NC}"
    docker-compose run --rm openvpn easyrsa build-server-full "${SERVER_CERT_NAME}" nopass
    echo -e "${GREEN}Серверный сертификат создан${NC}\n"
else
    echo -e "${YELLOW}Серверный сертификат уже существует — пропускаю${NC}\n"
fi

##################################
# Генерация openvpn.conf
##################################
echo -e "${CYAN}Генерация openvpn.conf...${NC}"
[[ -f "${CONF_TEMPLATE}" ]] || die "Шаблон не найден: ${CONF_TEMPLATE}"

sed \
  -e "s|{{PORT}}|${PORT}|g" \
  -e "s|{{PROTO}}|${PROTO}|g" \
  -e "s|{{VPN_NET}}|${VPN_NET}|g" \
  -e "s|{{VPN_MASK}}|${VPN_MASK}|g" \
  -e "s|{{DNS1}}|${DNS1}|g" \
  -e "s|{{DNS2}}|${DNS2}|g" \
  -e "s|{{VERB}}|${VERB}|g" \
  -e "s|{{SERVER_CERT_NAME}}|${SERVER_CERT_NAME}|g" \
  "${CONF_TEMPLATE}" > "${CONF_FILE}"

echo -e "${GREEN}openvpn.conf создан${NC}\n"

##################################
# Запуск сервера
##################################
echo -e "${CYAN}Запуск OpenVPN...${NC}"
docker-compose up -d
echo -e "${GREEN}OpenVPN запущен${NC}\n"

##################################
# Финал
##################################
echo -e "${PURPLE}=== ГОТОВО ===${NC}"
echo -e "Конфигурация: ${CONF_FILE}"
echo -e "Сертификат сервера: ${SERVER_CERT_NAME}\n"
echo -e "${CYAN}Дальнейшие шаги:${NC}"
echo "  1. Создать клиента: ./scripts/add-client.sh client1"
echo "  2. Посмотреть логи: docker-compose logs -f openvpn"
