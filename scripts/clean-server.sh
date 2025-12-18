#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_DIR="${ROOT_DIR}/data"
CLIENT_DIR="${ROOT_DIR}/clients"

echo -e "${CYAN}[*] Остановка контейнера...${NC}"
docker compose down || echo -e "${YELLOW}[WARN] Контейнер не запущен или уже остановлен${NC}"

echo -e "${CYAN}[*] Удаление старого контейнера и образа...${NC}"
CONTAINER_NAME="openvpn-server"
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    docker rm -f "${CONTAINER_NAME}" || echo -e "${YELLOW}[WARN] Не удалось удалить контейнер${NC}"
fi

# Опционально: удалить старый образ, если нужно чисто билдить заново
IMAGE_NAME="openvpn-server:local"
if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${IMAGE_NAME}$"; then
    docker rmi -f "${IMAGE_NAME}" || echo -e "${YELLOW}[WARN] Не удалось удалить образ${NC}"
fi

echo -e "${CYAN}[*] Очистка сети, volumes и временных данных...${NC}"
# Удаляем только сеть, связанную с этим docker-compose
docker network prune -f

# Опционально: очистка data (PKI и клиенты) для полностью чистого запуска
read -p "Удалить папку data/ (PKI и клиенты)? [y/N]: " DELETE_DATA
if [[ "${DELETE_DATA,,}" == "y" ]]; then
    sudo rm -rf "${DATA_DIR}"
    echo -e "${GREEN}[OK] Папка data/ удалена${NC}"

    sudo rm -rf "${CLIENT_DIR}"
    echo -e "${GREEN}[OK] Папка clients/ удалена${NC}"
else
    echo -e "${YELLOW}[INFO] Папки data/ и clients/ сохранены${NC}"
fi

echo -e "${PURPLE}[=== Очистка завершена ===]${NC}"
