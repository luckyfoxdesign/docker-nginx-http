# Nginx Docker — HTTP / HTTPS

🇬🇧 English | 🇷🇺 [Русский](README.ru.md)

Production-ready nginx in Docker with built-in protection: rate limiting, security headers (including HSTS), token authorization.

Supports two modes:
- **HTTP** — for local development or a server without SSL
- **HTTPS** — for production, Let's Encrypt certificates via Certbot

---

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (includes Docker Compose)
- Git

Check that everything is installed:
```bash
docker --version
docker compose version
```

---

## Project structure

```
conf/
  http-nginx.conf       # nginx config for HTTP mode
  https-nginx.conf      # nginx config for HTTPS mode
  snippets/
    security-headers.conf  # Security headers
.env                    # Your settings (do not commit!)
.env.example            # Settings template
compose.yml             # Docker Compose
Dockerfile              # nginx Alpine image
entrypoint.sh           # Env var substitution on startup
init-ssl.sh             # First-run script for HTTPS
```

---

## Mode 1 — HTTP (local or server without SSL)

### Step 1 — Clone the repository

```bash
git clone git@github.com:luckyfoxdesign/docker-nginx-http.git
cd docker-nginx-http
```

### Step 2 — Create the settings file

```bash
cp .env.example .env
```

Open `.env` and fill it in:

```env
NGINX_CONF=http-nginx.conf       # HTTP mode
DOMAINS=example.com              # Your domain (or localhost)
PRIMARY_DOMAIN=example.com       # Primary domain (same one)
LETSENCRYPT_EMAIL=               # Can be left empty
AUTH_TOKEN=Bearer change-this    # Secret token for the API
```

> To generate a strong token: `openssl rand -hex 32`

### Step 3 — Start it

```bash
docker compose up -d
```

### Step 4 — Verify it works

```bash
curl http://localhost/healthz
# Should return: OK
```

---

## Mode 2 — HTTPS (production on a real server)

> The domain must already point to the server's IP, otherwise Let's Encrypt won't issue a certificate.

### Step 1 — Clone the repository

```bash
git clone git@github.com:luckyfoxdesign/docker-nginx-http.git
cd docker-nginx-http
```

### Step 2 — Create the settings file

```bash
cp .env.example .env
```

Open `.env` and fill it in:

```env
NGINX_CONF=http-nginx.conf           # The script will switch to https itself
DOMAINS=example.com www.example.com  # All domains separated by spaces
PRIMARY_DOMAIN=example.com           # Primary domain (first in the list)
LETSENCRYPT_EMAIL=you@email.com      # Email for Let's Encrypt notifications
AUTH_TOKEN=Bearer change-this        # Secret token for the API
```

> To generate a strong token: `openssl rand -hex 32`

### Step 3 — Run the init script

```bash
./init-ssl.sh
```

The script does everything for you:
1. Brings up nginx on HTTP for domain validation
2. Obtains an SSL certificate from Let's Encrypt
3. Switches nginx to HTTPS
4. Starts automatic certificate renewal (certbot renews the files, nginx picks them up itself via reload every 12 hours — no manual steps, no downtime)

### Step 4 — Verify it works

```bash
curl https://example.com/healthz
# Should return: OK
```

---

## Connecting your own container

Say you have an app container running on port 8080.

### Step 1 — Add it to `compose.yml`

Uncomment and edit the block at the end of the file:

```yaml
my-app:
  image: my-app:latest
  container_name: my-app-c
  restart: always
  networks:
    - internal_net   # Internal network only — not reachable from outside
  # Do NOT add ports: — access only through nginx
```

### Step 2 — Add a route to the nginx config

Open `conf/http-nginx.conf` (or `https-nginx.conf`) and add a `location` inside the relevant `server {}`:

```nginx
location /api/ {
    proxy_pass http://my-app-c:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

> The name `my-app-c` is the `container_name` from compose.yml. Docker uses it as DNS inside the network.

### Step 3 — Restart

```bash
# HTTP mode
docker compose up -d

# HTTPS mode
docker compose --profile https up -d
```

---

## Useful commands

```bash
# Check container status
docker compose ps

# View nginx logs
docker compose logs -f nginx-s

# Reload nginx without downtime (after changing the config)
# New certificates are picked up automatically every 12h — manual reload is only needed after config edits
docker exec nginx-c nginx -s reload

# Force-renew the certificate
docker compose --profile https run --rm certbot renew --force-renewal

# Stop everything
docker compose down
```

---

## Setting up token authorization for the API

The `/api/*` endpoints are protected by a Bearer token. Generate a strong token:

```bash
openssl rand -hex 32
```

Put the result into `.env`:

```env
AUTH_TOKEN=Bearer <generated-token>
```

To call the API:

```bash
curl -H "Authorization: Bearer <your-token>" https://example.com/api/signal
```

---

## License

MIT
