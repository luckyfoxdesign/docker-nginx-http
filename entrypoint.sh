#!/bin/sh
set -e

# Substitute env vars in nginx config template before starting
envsubst '${DOMAINS} ${PRIMARY_DOMAIN} ${AUTH_TOKEN}' \
    < /etc/nginx/nginx.conf.template \
    > /etc/nginx/nginx.conf

# Reload nginx every 12h so it picks up renewed certs from certbot's shared volume.
# certbot renews in a separate container but never signals nginx — without this,
# nginx keeps serving the old cert until a manual reload/restart.
( while true; do sleep 12h; nginx -s reload 2>/dev/null || true; done ) &

exec "$@"
