#!/usr/bin/env bash
set -euo pipefail

CLIENT_NAME="${CLIENT_NAME:?CLIENT_NAME not set}"
SERVER_ADDR="${SERVER_ADDR:?SERVER_ADDR not set}"
SERVER_PORT="1194"

BASE="/etc/openvpn"
PKI="$BASE/pki"
TEMPLATE="$BASE/client.ovpn.template"
OUT_DIR="$BASE/clients"

mkdir -p "$OUT_DIR"

if [[ -f "$OUT_DIR/$CLIENT_NAME.ovpn" ]]; then
  echo "Клиент уже существует"
  exit 1
fi

echo "[*] Генерация сертификата клиента $CLIENT_NAME"
easyrsa build-client-full "$CLIENT_NAME" nopass

#TMP="$(mktemp)"
#
#sed \
#  -e "s|{{SERVER_ADDR}}|$SERVER_ADDR|g" \
#  -e "s|{{SERVER_PORT}}|$SERVER_PORT|g" \
#  "$TEMPLATE" > "$TMP"
#
#{
#  echo "<ca>"
#  cat "$PKI/ca.crt"
#  echo "</ca>"
#
#  echo "<cert>"
#  sed -ne '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' \
#    "$PKI/issued/$CLIENT_NAME.crt"
#  echo "</cert>"
#
#  echo "<key>"
#  cat "$PKI/private/$CLIENT_NAME.key"
#  echo "</key>"
#
#  echo "<tls-crypt>"
#  cat "$PKI/ta.key"
#  echo "</tls-crypt>"
#} >> "$TMP"
#
#mv "$TMP" "$OUT_DIR/$CLIENT_NAME.ovpn"
#chmod 600 "$OUT_DIR/$CLIENT_NAME.ovpn"
#
#echo "[+] Готово: $OUT_DIR/$CLIENT_NAME.ovpn"

TMP="$(mktemp)"

CA_CERT="$(cat "$PKI/ca.crt")"
CLIENT_CERT="$(sed -ne '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' \
  "$PKI/issued/$CLIENT_NAME.crt")"
CLIENT_KEY="$(cat "$PKI/private/$CLIENT_NAME.key")"
TLS_CRYPT_KEY="$(cat "$PKI/ta.key")"

sed \
  -e "s|{{SERVER_ADDR}}|${SERVER_ADDR}|g" \
  -e "s|{{SERVER_PORT}}|${SERVER_PORT}|g" \
  -e "s|{{CA_CERT}}|${CA_CERT//$'\n'/\\n}|g" \
  -e "s|{{CLIENT_CERT}}|${CLIENT_CERT//$'\n'/\\n}|g" \
  -e "s|{{CLIENT_KEY}}|${CLIENT_KEY//$'\n'/\\n}|g" \
  -e "s|{{TLS_CRYPT_KEY}}|${TLS_CRYPT_KEY//$'\n'/\\n}|g" \
  "$TEMPLATE" > "$TMP"

OUT_FILE="$OUT_DIR/$CLIENT_NAME.ovpn"
mv "$TMP" "$OUT_FILE"
chmod 600 "$OUT_FILE"

echo "[+] Готово: $OUT_FILE"