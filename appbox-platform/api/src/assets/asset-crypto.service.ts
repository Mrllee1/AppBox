import { Injectable } from "@nestjs/common";
import { createCipheriv, createHash } from "node:crypto";

@Injectable()
export class AssetCryptoService {
  private readonly key = this.loadFixedBytes(
    process.env.APPBOX_ASSET_AES_KEY,
    "appbox-asset-image-key-v1",
    32
  );
  private readonly iv = this.loadFixedBytes(
    process.env.APPBOX_ASSET_AES_IV,
    "appbox-asset-image-iv-v1",
    16
  );

  encryptImageBytes(data: Buffer): Buffer {
    const cipher = createCipheriv("aes-256-cbc", this.key, this.iv);
    return Buffer.concat([cipher.update(data), cipher.final()]);
  }

  private loadFixedBytes(value: string | undefined, fallbackMaterial: string, expectedLength: number) {
    if (value) {
      const decoded = this.decodeConfiguredBytes(value);
      if (decoded.length === expectedLength) return decoded;
    }

    const digest = createHash("sha256").update(fallbackMaterial).digest();
    return expectedLength === 32 ? digest : digest.subarray(0, expectedLength);
  }

  private decodeConfiguredBytes(value: string) {
    if (/^[a-f0-9]+$/i.test(value) && value.length % 2 === 0) {
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
