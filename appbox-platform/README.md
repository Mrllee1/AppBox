# AppBox Platform

Tianya AppBox backend and admin console.

## Local Run

```bash
npm install
npm run dev:api
npm run dev:admin
```

API: `http://127.0.0.1:39110`

Admin: `http://127.0.0.1:39111`

Client API docs:

- local: `http://127.0.0.1:39111/docs/client-api`
- production: `https://666999.lol/docs/client-api`

Default local admin account:

- username: `admin`
- password: `appbox-admin`

## Verification

```bash
npm test
```

The test suite starts the API with an isolated data file, verifies health,
catalog, deeplink resolution, event ingestion, admin CRUD behavior, remote
entrypoint configuration, encrypted config preview, and R2 fallback behavior,
then builds the API and admin console.

## Production

Use environment variables instead of hardcoded credentials:

```bash
node scripts/hash-admin-password.mjs '<strong-password>'
node -e "console.log(require('node:crypto').randomBytes(32).toString('base64'))"
npm ci
npm run build
npm run start:api
npm run start:admin
```

Admin endpoints under `/admin/*` require `Authorization: Bearer <token>`.
Public client endpoints remain unauthenticated but use AES-256-GCM envelopes.
POST bodies must also use the same encrypted envelope shape.

- `GET /health`
- `GET /api/v1/appbox/config`
- `GET /api/v1/appbox/version`
- `GET /api/v1/appbox/catalog`
- `POST /api/v1/appbox/deeplink/resolve`
- `POST /api/v1/events/batch`

Compact encrypted response/request envelope:

```json
{
  "v": 1,
  "k": "v1",
  "n": "base64url nonce",
  "t": "base64url tag",
  "d": "base64url ciphertext"
}
```

Client JSON payloads use compact field names. Image resources are encrypted
when an app is created or updated in the admin console, stored under
`APPBOX_ASSET_DIR`, and served from the returned image URL as
`application/octet-stream`.

The image URL body is raw AES-256-CBC/PKCS7 ciphertext, matching the
`custom_image_widget` pipeline: the client downloads the URL bytes, decrypts
them with `APPBOX_ASSET_AES_KEY` and `APPBOX_ASSET_AES_IV`, then renders the
decrypted image bytes. The API still returns only the image URL in catalog
payloads; it does not inline image bytes.

## Remote Entrypoint Config

The admin console can save API entrypoint domains and publish a compact,
AES-256-GCM encrypted `version.json` to GitHub/CDN. The iOS client reads that
file from raw GitHub and jsDelivr mirrors, decrypts it locally, probes
`/health`, and then requests the fixed API path `/api/v1/appbox/catalog`.

GitHub and R2 credentials entered in the admin console are encrypted before
they are written to `APPBOX_DATA_FILE`. Use `APPBOX_CREDENTIAL_AES_KEY` for a
stable credential encryption key in production.

R2 image upload is optional. When configured, app icon bytes are encrypted
first, then uploaded to R2 as `.enc` objects, and catalog responses return the
public encrypted object URL. When R2 is not configured, the API keeps serving
the same encrypted bytes from the local asset endpoint.
