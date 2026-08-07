import { BadRequestException, Injectable } from "@nestjs/common";
import { createCipheriv, createDecipheriv, createHash, randomBytes } from "node:crypto";
import { z } from "zod";

const compactEnvelopeSchema = z.object({
  v: z.literal(1),
  k: z.string().min(1),
  n: z.string().min(1),
  t: z.string().min(1),
  d: z.string().min(1)
});

const legacyEnvelopeSchema = z.object({
  encrypted: z.literal(true),
  alg: z.literal("AES-256-GCM"),
  kid: z.string().min(1),
  iv: z.string().min(1),
  tag: z.string().min(1),
  data: z.string().min(1),
  encoding: z.enum(["json", "binary"]).optional(),
  content_type: z.string().optional(),
  filename: z.string().optional()
});

export type ClientEncryptedEnvelope = z.infer<typeof compactEnvelopeSchema>;

@Injectable()
export class ClientCryptoService {
  private readonly kid = process.env.APPBOX_CLIENT_AES_KID || "v1";
  private readonly required = process.env.APPBOX_CLIENT_ENCRYPTION_REQUIRED !== "false";
  private readonly key = this.loadKey();

  encryptJson(value: unknown) {
    return this.encryptBytes(Buffer.from(JSON.stringify(value), "utf8"));
  }

  encryptBytes(data: Buffer): ClientEncryptedEnvelope {
    const iv = randomBytes(12);
    const cipher = createCipheriv("aes-256-gcm", this.key, iv);
    const encrypted = Buffer.concat([cipher.update(data), cipher.final()]);
    const tag = cipher.getAuthTag();
    return {
      v: 1,
      k: this.kid,
      n: iv.toString("base64url"),
      t: tag.toString("base64url"),
      d: encrypted.toString("base64url")
    };
  }

  decryptBody(rawBody: unknown): unknown {
    const parsed = this.parseEnvelope(rawBody);
    if (!parsed.success) {
      if (!this.required) return rawBody;
      throw new BadRequestException({
        success: false,
        error_code: "ENCRYPTED_BODY_REQUIRED",
        message: "Encrypted request body is required"
      });
    }

    const envelope = parsed.data;
    if (envelope.k !== this.kid) {
      throw new BadRequestException({
        success: false,
        error_code: "UNKNOWN_AES_KEY",
        message: "Unknown encryption key id"
      });
    }

    const plain = this.decrypt(envelope);
    try {
      return JSON.parse(plain.toString("utf8"));
    } catch {
      throw new BadRequestException({
        success: false,
        error_code: "INVALID_ENCRYPTED_JSON",
        message: "Encrypted JSON body cannot be parsed"
      });
    }
  }

  decryptBytes(envelope: ClientEncryptedEnvelope) {
    return this.decrypt(envelope);
  }

  private decrypt(envelope: ClientEncryptedEnvelope) {
    try {
      const decipher = createDecipheriv(
        "aes-256-gcm",
        this.key,
        Buffer.from(envelope.n, "base64url")
      );
      decipher.setAuthTag(Buffer.from(envelope.t, "base64url"));
      return Buffer.concat([
        decipher.update(Buffer.from(envelope.d, "base64url")),
        decipher.final()
      ]);
    } catch {
      throw new BadRequestException({
        success: false,
        error_code: "DECRYPT_FAILED",
        message: "Encrypted payload cannot be decrypted"
      });
    }
  }

  private parseEnvelope(rawBody: unknown) {
    const compact = compactEnvelopeSchema.safeParse(rawBody);
    if (compact.success) return compact;

    const legacy = legacyEnvelopeSchema.safeParse(rawBody);
    if (!legacy.success) return compact;

    return {
      success: true as const,
      data: {
        v: 1 as const,
        k: legacy.data.kid,
        n: legacy.data.iv,
        t: legacy.data.tag,
        d: legacy.data.data
      }
    };
  }

  private loadKey() {
    const configured = process.env.APPBOX_CLIENT_AES_KEY || "appbox-local-client-aes-key";
    const raw = this.decodeConfiguredKey(configured);
    if (raw.length === 32) return raw;
    return createHash("sha256").update(raw).digest();
  }

  private decodeConfiguredKey(value: string) {
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
