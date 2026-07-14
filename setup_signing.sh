#!/bin/bash
# 一次性：创建本地自签名「代码签名」证书，供 build_app.sh 使用。
# 目的：让 .app 拥有稳定签名身份，重新打包后辅助功能授权不再失效。
set -e

CERT_NAME="HotKeyTrack Self-Signed"
WORK="$(cd "$(dirname "$0")" && pwd)/.signing"
LOGIN_KC="$HOME/Library/Keychains/login.keychain-db"

# 已存在同名可用身份则跳过
if security find-identity -v -p codesigning | grep -q "$CERT_NAME"; then
    echo "=== 已存在证书「$CERT_NAME」，跳过创建 ==="
    security find-identity -v -p codesigning | grep "$CERT_NAME"
    exit 0
fi

mkdir -p "$WORK"
cd "$WORK"

echo "=== 生成密钥与自签名证书（含 codeSigning 用途）==="
cat > cert.conf <<'EOF'
[ req ]
distinguished_name = dn
x509_extensions = ext
prompt = no
[ dn ]
CN = HotKeyTrack Self-Signed
[ ext ]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 3650 -nodes -config cert.conf

echo "=== 导入私钥到登录钥匙串（允许 codesign 使用）==="
security import key.pem -k "$LOGIN_KC" -T /usr/bin/codesign -A

echo "=== 导入证书到登录钥匙串 ==="
security import cert.pem -k "$LOGIN_KC" -T /usr/bin/codesign -A

echo "=== 设为受信任的代码签名根证书 ==="
security add-trusted-cert -r trustRoot -p codeSign -k "$LOGIN_KC" cert.pem || \
security add-trusted-cert -p codeSign -k "$LOGIN_KC" cert.pem || true

echo "=== 当前可用签名身份 ==="
security find-identity -v -p codesigning
