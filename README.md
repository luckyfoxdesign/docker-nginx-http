# Secure Nginx Docker Setup

This project provides a secure Nginx setup with Docker, including ModSecurity WAF, rate limiting, security headers, and token-based authentication.

## Features

- **ModSecurity WAF** for application-level protection
- **Rate limiting** to prevent DDoS attacks
- **Security headers** against XSS, clickjacking, and other attacks
- **Token-based authentication** for secure API access
- **Docker containerization** for easy deployment

## Project Structure

```
| - conf/
| -- snippets/
| --- security-headers.conf  # Security header configurations
| -- nginx.conf              # Main Nginx configuration
| - .env                     # Environment variables
| - compose.yml              # Docker Compose configuration
| - Dockerfile               # Nginx with ModSecurity
| - README.md                # This file
```

## Setup

### Prerequisites

- Docker and Docker Compose
- Git (for cloning this repository)

### Installation

1. Clone this repository:
   ```bash
   git clone [repository-url]
   cd [repository-name]
   ```

2. Configure your environment variables:
   ```bash
   # Edit .env file
   AUTH_TOKEN=Bearer your-secret-token-here
   DOMAINS=yourdomain.com www.yourdomain.com
   ```

3. Start the services:
   ```bash
   docker-compose up -d
   ```

4. Verify the installation:
   ```bash
   curl http://localhost/healthz
   # Should return "OK"
   ```

## Configuration

### Adding Domains

Edit the `.env` file and update the `DOMAINS` variable:

```
DOMAINS=example.com www.example.com additional-domain.com
```

### API Authentication

API endpoints are protected with a bearer token. To access them:

```bash
curl -H "Authorization: Bearer your-secret-token-here" http://yourdomain.com/api/signal
```

### Custom Security Headers

Modify `conf/snippets/security-headers.conf` to customize security headers.

### Advanced Configuration

The main Nginx configuration is in `conf/nginx.conf`. Key security features:

- IP-based access control
- Request rate limiting (10 requests/sec per IP)
- Connection limiting
- Request body size limiting (10MB max)
- Protection against suspicious URIs

## Production Considerations

- **SSL/TLS**: Uncomment and configure the SSL sections in nginx.conf
- **Logging**: Logs are stored in the `./logs` directory
- **Monitoring**: The `/healthz` endpoint is available for health checks

## License

MIT License
