FROM nginx:1.28.0-alpine3.21

RUN apk add --no-cache \
    nginx-mod-http-modsecurity \
    libmodsecurity \
    gettext \
    && mkdir -p /etc/nginx/modsec

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
