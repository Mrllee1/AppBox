# AppBox Client API

Online page: `/docs/client-api`

Production API base:

```text
https://666999.lol
```

## Public Client Endpoints

| Method | Path | Encryption | Purpose |
| --- | --- | --- | --- |
| GET | `/health` | plain | API entrypoint health probe |
| GET | `/api/v1/appbox/config` | encrypted response | API entrypoints and capabilities |
| GET | `/api/v1/appbox/version` | encrypted response | minimum client version |
| GET | `/api/v1/appbox/catalog` | encrypted response | dynamic categories, groups, and apps |
| POST | `/api/v1/appbox/deeplink/resolve` | encrypted request and response | external app_id mapping |
| POST | `/api/v1/events/batch` | encrypted request and response | client event ingestion |
| GET | `/api/v1/appbox/assets/apps/:id/icon` | encrypted bytes | encrypted app icon download |

## Envelope

JSON APIs use AES-256-GCM envelopes:

```json
{
  "v": 1,
  "k": "v1",
  "n": "base64url_nonce",
  "t": "base64url_auth_tag",
  "d": "base64url_ciphertext"
}
```

Icon resources return `application/octet-stream`; the body is AES-256-CBC/PKCS7 ciphertext. The client decrypts the bytes locally and renders the resulting PNG, JPEG, or WebP image.

## Maintenance

The online document is implemented at:

```text
admin/app/docs/client-api/page.tsx
```
