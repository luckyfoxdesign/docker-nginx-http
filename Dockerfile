FROM nginx:1.28.0-alpine3.21

RUN apk add --no-cache \
    nginx-mod-http-modsecurity \
    libmodsecurity \
    && mkdir -p /etc/nginx/modsec
