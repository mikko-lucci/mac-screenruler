#!/bin/bash
# Creates a self-signed code signing certificate "ScreenRuler Local Signing" in the
# login keychain. Signing with a stable identity lets macOS keep the Screen Recording
# permission across rebuilds (ad-hoc signatures change on every build).
#
# Remove it later with:
#   security delete-identity -c "ScreenRuler Local Signing" ~/Library/Keychains/login.keychain-db
set -euo pipefail

NAME="ScreenRuler Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-certificate -c "$NAME" "$KEYCHAIN" >/dev/null 2>&1; then
    echo "Varmenne \"$NAME\" on jo olemassa."
    exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CNF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/cert.cnf" 2>/dev/null
openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 \
    -out "$TMP/cert.p12" -passout pass:screenruler -name "$NAME" 2>/dev/null

security import "$TMP/cert.p12" -k "$KEYCHAIN" -P screenruler -T /usr/bin/codesign >/dev/null
echo "Luotu varmenne \"$NAME\"."
