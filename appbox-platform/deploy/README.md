# AppBox server deployment

The production topology is:

- nginx on ports 80 and 443 (HTTP redirects to HTTPS after certificate setup)
- NestJS API on loopback port 39110
- Next.js admin on loopback port 39111
- persistent catalog JSON and encrypted icons under `/var/lib/appbox`
- read-only, byte-range package downloads under `/var/lib/appbox/downloads`

Converted packages are published as
`https://3601.help/downloads/<filename>`. Store only validated artifacts in
that directory and use their exact URLs and SHA-256 values in AppBox Admin.

## First deployment

Place the repository on the server, install Node.js 20+, npm, nginx, and
systemd, then run:

```bash
cd /opt/appbox/appbox-platform
sudo ./deploy/install-server.sh
```

On the first run, the installer creates `/etc/appbox/appbox.env` and stops.
Generate the required values locally or on the server:

```bash
node scripts/hash-admin-password.mjs '<strong-password>'
node -e "console.log(require('node:crypto').randomBytes(32).toString('base64'))"
```

Put the password hash and two independent random values into the environment
file. Do not put a plaintext password in the repository. Run the installer a
second time; it builds, starts, and health-checks both services.

## HTTPS setup

The installer first uses the HTTP bootstrap configuration. After `3601.help`
resolves to the server, issue the certificate and rerun the installer:

```bash
sudo certbot certonly --webroot \
  --webroot-path /var/www/appbox-acme \
  --non-interactive --agree-tos --register-unsafely-without-email \
  --domain 3601.help
sudo ./deploy/install-server.sh
```

When the certificate exists, the installer automatically selects
`nginx-appbox-https.conf`. Certbot's systemd timer renews the certificate using
the same ACME webroot.

For the current Cloudflare zone, keep the apex `A` record pointed at the
AppBox server, select **Full (strict)** under SSL/TLS, and enable the proxy only
after the origin certificate and HTTPS configuration are working. This keeps
traffic encrypted on both the client-to-Cloudflare and Cloudflare-to-origin
legs without creating a redirect loop.

## Verification

```bash
curl --fail http://127.0.0.1/health
curl --fail https://3601.help/health
systemctl --no-pager --full status appbox-api appbox-admin nginx
journalctl -u appbox-api -u appbox-admin --since '10 minutes ago' --no-pager
```

The iOS client should then retrieve
`https://3601.help/api/v1/appbox/catalog`. Add converted applications from the
admin page at `https://3601.help/`.

## Updating

Pull or copy the new repository revision and rerun `deploy/install-server.sh`.
The installer preserves `/etc/appbox/appbox.env` and `/var/lib/appbox`.
