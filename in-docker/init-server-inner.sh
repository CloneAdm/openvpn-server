#!/bin/bash
set -euo pipefail

: "${SERVER_ADDRESS:?SERVER_ADDRESS is required}"

PORT=1194
PROTO=udp

VPN_NET="192.168.255.0"
VPN_MASK="255.255.255.0"

DNS1="1.1.1.1"
DNS2="8.8.8.8"

VERB=3
SERVER_CERT_NAME="__server__"

TEMPLATE="/etc/openvpn/openvpn.conf.template"
CONF="/etc/openvpn/openvpn.conf"

echo "[*] Generating base OpenVPN config"

if [[ ! -f ovpn_env.sh ]]; then
  ovpn_genconfig \
    -u "${PROTO}://${SERVER_ADDRESS}" \
    -C AES-256-GCM \
    -a SHA512 \
    -c
fi

echo "[*] Initializing PKI"

if [[ ! -d pki ]]; then
  ovpn_initpki
fi

echo "[*] Creating server certificate"

if [[ ! -f "pki/issued/${SERVER_CERT_NAME}.crt" ]]; then
  easyrsa build-server-full "${SERVER_CERT_NAME}" nopass
fi

echo "[*] Generating openvpn.conf from template"

sed \
  -e "s|{{PORT}}|${PORT}|g" \
  -e "s|{{PROTO}}|${PROTO}|g" \
  -e "s|{{VPN_NET}}|${VPN_NET}|g" \
  -e "s|{{VPN_MASK}}|${VPN_MASK}|g" \
  -e "s|{{DNS1}}|${DNS1}|g" \
  -e "s|{{DNS2}}|${DNS2}|g" \
  -e "s|{{VERB}}|${VERB}|g" \
  -e "s|{{SERVER_CERT_NAME}}|${SERVER_CERT_NAME}|g" \
  "$TEMPLATE" > "$CONF"

echo "[OK] Initialization finished"
