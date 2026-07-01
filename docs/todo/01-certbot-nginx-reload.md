# Certbot: автоперезагрузка nginx после обновления сертификата

**Priority:** critical (продакшн падает молча раз в 90 дней)

## Проблема

Certbot успешно обновляет сертификат каждые 30 дней до истечения, но nginx **не перезагружается** автоматически и продолжает отдавать старый протухший сертификат.

**Инцидент:** 1 июля 2026 — сертификат `unitkon.app` истёк 30 июня, хотя certbot обновил его ещё 1 июня. nginx держал `cert1.pem` (апрель) вместо `cert2.pem` (июнь) до ручного `nginx -s reload`.

**Причина:** certbot и nginx — разные контейнеры. Entrypoint certbot-контейнера:
```
certbot renew --quiet; sleep 12h
```
Нет post-hook, нет сигнала nginx после успешного обновления.

## Решение

### Вариант A (рекомендуемый): cron-reload в nginx-контейнере

Добавить в `entrypoint.sh` nginx-контейнера фоновый процесс, который раз в 12 часов делает `nginx -s reload`:

```sh
# в entrypoint.sh, перед exec "$@"
( while true; do sleep 12h; nginx -s reload 2>/dev/null || true; done ) &
```

Nginx читает симлинки из `/etc/letsencrypt/live/` при каждом reload — подхватит новый сертификат без рестарта контейнера.

`|| true` — чтобы неудачный reload (например, до полного старта nginx) не всплыл ошибкой; `2>/dev/null` — не засорял логи.

### Безопасность

- `nginx -s reload` — graceful: старые воркеры доживают соединения, даунтайма нет.
- Битый конфиг не уронит прод: nginx проверяет конфиг перед reload, при ошибке отклоняет и продолжает на старом.
- Гонка с certbot безопасна: в худшем случае прочитается старый серт, следующий reload через 12ч подхватит новый.
- После `exec` мастер nginx становится PID 1 и не реапит зомби фонового сабшелла. Лечится `init: true` для сервиса `nginx-s` в `compose.yml`.

### Вариант B: post-hook через общий volume

Certbot пишет файл-флаг в общий volume после обновления, nginx-контейнер проверяет его и делает reload. Сложнее, избыточно для этого кейса.

### Вариант C: одиночный контейнер (nginx + certbot)

Объединить в один образ с cron. Нарушает принцип one-process-per-container, не рекомендуется.

## Что менять

- `entrypoint.sh` — добавить фоновый reload-loop
- `Dockerfile` — убедиться что `nginx` доступен как команда в entrypoint
- Протестировать: после `certbot renew --force-renewal` nginx должен автоматически подхватить новый сертификат в течение 12 часов

## Проверка

```bash
# Дата файлов сертификата до и после
docker exec certbot-c ls -la /etc/letsencrypt/archive/unitkon.app/

# Дата сертификата, который отдаёт nginx прямо сейчас
echo | openssl s_client -connect unitkon.app:443 -servername unitkon.app 2>/dev/null | openssl x509 -noout -dates
```
