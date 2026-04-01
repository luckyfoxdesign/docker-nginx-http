#!/bin/sh
set -e

# Загружаем переменные из .env
if [ ! -f .env ]; then
    echo "Ошибка: файл .env не найден. Скопируй .env.example и заполни переменные."
    exit 1
fi

set -a
. ./.env
set +a

# Проверяем обязательные переменные
for var in PRIMARY_DOMAIN DOMAINS LETSENCRYPT_EMAIL; do
    eval val=\$$var
    if [ -z "$val" ]; then
        echo "Ошибка: переменная $var не задана в .env"
        exit 1
    fi
done

echo "→ Создаём нужные директории..."
mkdir -p html certs logs

echo "→ Запускаем nginx в HTTP-режиме для прохождения ACME-проверки..."
NGINX_CONF=http-nginx.conf docker compose up -d nginx-s

echo "→ Ждём готовности nginx..."
until docker exec nginx-c nginx -t 2>/dev/null; do
    sleep 1
done

echo "→ Получаем сертификат (домены: ${DOMAINS})..."

DOMAIN_FLAGS=""
for domain in $DOMAINS; do
    DOMAIN_FLAGS="$DOMAIN_FLAGS -d $domain"
done

docker compose --profile https run --rm --entrypoint certbot certbot certonly \
    --webroot -w /var/www/certbot \
    --email "${LETSENCRYPT_EMAIL}" \
    $DOMAIN_FLAGS \
    --agree-tos \
    --non-interactive

echo "→ Переключаемся на HTTPS-режим в .env..."
sed -i.bak 's|^NGINX_CONF=.*|NGINX_CONF=https-nginx.conf|' .env && rm -f .env.bak

echo "→ Перезапускаем в HTTPS-режиме..."
docker compose down
docker compose --profile https up -d

echo ""
echo "✓ Готово! Сервисы запущены:"
docker compose --profile https ps
echo ""
echo "  https://${PRIMARY_DOMAIN}"
