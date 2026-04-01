#!/bin/sh
set -e

# Substitute env vars in nginx config template before starting
envsubst '${DOMAINS} ${PRIMARY_DOMAIN} ${AUTH_TOKEN}' \
    < /etc/nginx/nginx.conf.template \
    > /etc/nginx/nginx.conf

exec "$@"
