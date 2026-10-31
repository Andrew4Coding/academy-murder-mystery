# Deploying the Moonfall cloud host

Target: one Docker host behind nginx at `moonfall.andrewaryo.com`. Nothing here deploys itself.

## 1. DNS and TLS

1. Point an `A` (and `AAAA`) record for `moonfall.andrewaryo.com` at the server.
2. Get a certificate before enabling the 443 block: `certbot certonly --webroot -w /var/www/html -d moonfall.andrewaryo.com` (or `--nginx`). Paths in `nginx-moonfall.conf` assume the Let's Encrypt defaults.

## 2. Server

```bash
git clone <repo> && cd <repo>/cloud
cat > .env <<'ENV'
MOONFALL_PAIRING_SECRET=<long random string, also entered in the Mac Admin app>
MOONFALL_BOOTSTRAP_PIN=<4 digit OC PIN used until the first snapshot arrives>
ENV
docker compose up -d --build
curl -s http://127.0.0.1:8080/health
```

The container listens on 8080, bound to localhost only, and keeps SQLite under the `moonfall-data` volume (`/data/moonfall.sqlite`). `TRUST_PROXY=1` is set in compose so the client IP comes from nginx's `X-Forwarded-For`; never expose port 8080 directly while it is set.

## 3. nginx

```bash
sudo cp deploy/nginx-moonfall.conf /etc/nginx/sites-available/moonfall
sudo ln -s /etc/nginx/sites-available/moonfall /etc/nginx/sites-enabled/moonfall
sudo nginx -t && sudo systemctl reload nginx
```

The `/ws` location upgrades the connection and uses a one hour read timeout; the server pings every 25 seconds so idle phones stay connected.

## 4. Checks

```bash
curl -s https://moonfall.andrewaryo.com/health
curl -s https://moonfall.andrewaryo.com/registry
```

A fresh server answers `{"mode":"local",...}`: phones fall back to Bonjour until the Mac switches to Cloud (`PUT /import`) or the take-over page `https://moonfall.andrewaryo.com/takeover` is used with the OC PIN.

## 5. Operations

- Backup: copy the volume (`docker run --rm -v moonfall-data:/data -v $PWD:/out busybox tar czf /out/moonfall-data.tgz /data`).
- Logs: `docker compose logs -f`.
- Update: `git pull && docker compose up -d --build`. State survives; live sockets reconnect and resume.
- Rotate the pairing secret by editing `.env`, `docker compose up -d`, then updating the Mac app.
