import { Injectable } from "@nestjs/common";
import { createCipheriv, createDecipheriv, createHash, randomBytes } from "node:crypto";

@Injectable()
export class CredentialCryptoService {
  private readonly key = this.loadKey();

  encrypt(value: string | undefined) {
    if (!value) return undefined;
    const iv = randomBytes(12);
    const cipher = createCipheriv("aes-256-gcm", this.key, iv);
    const encrypted = Buffer.concat([cipher.update(value, "utf8"), cipher.final()]);
    return [
      "v1",
      iv.toString("base64url"),
      cipher.getAuthTag().toString("base64url"),
      encrypted.toString("base64url")
    ].join(".");
  }

  decrypt(value: string | undefined) {
    if (!value) return undefined;
    const [version, iv, tag, data] = value.split(".");
    if (version !== "v1" || !iv || !tag || !data) return undefined;
    const decipher = createDecipheriv("aes-256-gcm", this.key, Buffer.from(iv, "base64url"));
    decipher.setAuthTag(Buffer.from(tag, "base64url"));
    return Buffer.concat([
      decipher.update(Buffer.from(data, "base64url")),
      decipher.final()
    ]).toString("utf8");
  }

  maskSecret(value: string | undefined) {
    if (!value) return "";
    if (value.length <= 8) return "********";
    return `${value.slice(0, 4)}****${value.slice(-4)}`;
  }

  private loadKey() {
    const configured =
      process.env.APPBOX_CREDENTIAL_AES_KEY ||
      process.env.APPBOX_ADMIN_SESSION_SECRET ||
      "appbox-local-credential-key";
    const raw = this.decode(configured);
    return raw.length === 32 ? raw : createHash("sha256").update(raw).digest();
  }

  private decode(value: string) {
    if (/^[a-f0-9]{64}$/i.test(value)) {
      return Buffer.from(value, "hex");
    }
    try {
      const decoded = Buffer.from(value, "base64");
      if (decoded.length > 0) return decoded;
    } catch {
      // Fall through to utf8.
    }
    return Buffer.from(value, "utf8");
  }
}
