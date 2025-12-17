FROM kylemanna/openvpn:latest

# Копируем внутренние скрипты и шаблоны
COPY in-docker/ /etc/openvpn-scripts/

# Делаем их исполняемыми
RUN chmod +x /etc/openvpn-scripts/*.sh

WORKDIR /etc/openvpn
