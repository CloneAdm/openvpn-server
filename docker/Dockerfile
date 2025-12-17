FROM kylemanna/openvpn:latest

# Копируем всю внутреннюю логику
COPY in-docker/ /etc/openvpn/

# Гарантируем права
RUN chmod +x /etc/openvpn/*.sh

WORKDIR /etc/openvpn
