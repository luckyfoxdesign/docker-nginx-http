# Nginx Docker — HTTP / HTTPS

Готовый nginx в Docker с защитой: rate limiting, security headers (включая HSTS), токен-авторизация, ModSecurity WAF (опционально).

Поддерживает два режима:
- **HTTP** — для локальной разработки или сервера без SSL
- **HTTPS** — для продакшена, сертификаты Let's Encrypt через Certbot

---

## Что нужно перед началом

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (включает Docker Compose)
- Git

Проверь что всё установлено:
```bash
docker --version
docker compose version
```

---

## Структура проекта

```
conf/
  http-nginx.conf       # Конфиг nginx для HTTP-режима
  https-nginx.conf      # Конфиг nginx для HTTPS-режима
  snippets/
    security-headers.conf  # Заголовки безопасности
.env                    # Твои настройки (не коммитить!)
.env.example            # Шаблон настроек
compose.yml             # Docker Compose
Dockerfile              # Образ nginx + ModSecurity
entrypoint.sh           # Подстановка переменных при старте
init-ssl.sh             # Скрипт первого запуска с HTTPS
```

---

## Режим 1 — HTTP (локально или сервер без SSL)

### Шаг 1 — Клонируй репозиторий

```bash
git clone git@github.com:luckyfoxdesign/docker-nginx-http.git
cd docker-nginx-http
```

### Шаг 2 — Создай файл настроек

```bash
cp .env.example .env
```

Открой `.env` и заполни:

```env
NGINX_CONF=http-nginx.conf       # HTTP-режим
DOMAINS=example.com              # Твой домен (или localhost)
PRIMARY_DOMAIN=example.com       # Главный домен (тот же)
LETSENCRYPT_EMAIL=               # Можно оставить пустым
AUTH_TOKEN=Bearer замени-это     # Секретный токен для API
```

> Для генерации сильного токена: `openssl rand -hex 32`

### Шаг 3 — Запусти

```bash
docker compose up -d
```

### Шаг 4 — Проверь что работает

```bash
curl http://localhost/healthz
# Должно вернуть: OK
```

---

## Режим 2 — HTTPS (продакшен на реальном сервере)

> Домен должен уже указывать на IP сервера, иначе Let's Encrypt не выдаст сертификат.

### Шаг 1 — Клонируй репозиторий

```bash
git clone git@github.com:luckyfoxdesign/docker-nginx-http.git
cd docker-nginx-http
```

### Шаг 2 — Создай файл настроек

```bash
cp .env.example .env
```

Открой `.env` и заполни:

```env
NGINX_CONF=http-nginx.conf           # Скрипт сам переключит на https
DOMAINS=example.com www.example.com  # Все домены через пробел
PRIMARY_DOMAIN=example.com           # Главный домен (первый из списка)
LETSENCRYPT_EMAIL=you@email.com      # Email для уведомлений Let's Encrypt
AUTH_TOKEN=Bearer замени-это         # Секретный токен для API
```

> Для генерации сильного токена: `openssl rand -hex 32`

### Шаг 3 — Запусти скрипт инициализации

```bash
./init-ssl.sh
```

Скрипт сделает всё сам:
1. Поднимет nginx на HTTP для проверки домена
2. Получит SSL-сертификат от Let's Encrypt
3. Переключит nginx на HTTPS
4. Запустит автообновление сертификата

### Шаг 4 — Проверь что работает

```bash
curl https://example.com/healthz
# Должно вернуть: OK
```

---

## Подключить свой контейнер

Допустим, у тебя есть контейнер с приложением на порту 8080.

### Шаг 1 — Добавь его в `compose.yml`

Раскомментируй и отредактируй блок в конце файла:

```yaml
my-app:
  image: my-app:latest
  container_name: my-app-c
  restart: always
  networks:
    - internal_net   # Только внутренняя сеть — снаружи недоступен
  # НЕ добавляй ports: — доступ только через nginx
```

### Шаг 2 — Добавь маршрут в nginx конфиг

Открой `conf/http-nginx.conf` (или `https-nginx.conf`) и добавь `location` внутрь нужного `server {}`:

```nginx
location /api/ {
    proxy_pass http://my-app-c:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

> Имя `my-app-c` — это `container_name` из compose.yml. Docker использует его как DNS внутри сети.

### Шаг 3 — Перезапусти

```bash
# HTTP-режим
docker compose up -d

# HTTPS-режим
docker compose --profile https up -d
```

---

## Полезные команды

```bash
# Посмотреть статус контейнеров
docker compose ps

# Посмотреть логи nginx
docker compose logs -f nginx-s

# Перезагрузить nginx без остановки (после изменения конфига)
docker exec nginx-c nginx -s reload

# Принудительно обновить сертификат
docker compose --profile https run --rm certbot renew --force-renewal

# Остановить всё
docker compose down
```

---

## Настройка токен-авторизации для API

Эндпоинты `/api/*` защищены Bearer-токеном. Сгенерируй сильный токен:

```bash
openssl rand -hex 32
```

Вставь результат в `.env`:

```env
AUTH_TOKEN=Bearer <сгенерированный-токен>
```

Чтобы обратиться к API:

```bash
curl -H "Authorization: Bearer <твой-токен>" https://example.com/api/signal
```

---

## Включить ModSecurity (WAF)

ModSecurity установлен, но по умолчанию выключен. Чтобы включить для конкретного сайта:

1. Добавь правила (например, [OWASP CRS](https://coreruleset.org/)) в папку `conf/modsec/`
2. Добавь в нужный `server {}` блок:
   ```nginx
   modsecurity on;
   modsecurity_rules_file /etc/nginx/modsec/modsecurity.conf;
   ```

---

## License

MIT
