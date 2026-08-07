import { Inject, Injectable } from "@nestjs/common";
import { DeleteObjectCommand, PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import { FileDataStore } from "../common/file-data-store";
import { CredentialCryptoService } from "./credential-crypto.service";

interface R2RuntimeConfig {
  accountId: string;
  accessKeyId: string;
  bucket: string;
  endpoint: string;
  publicBaseUrl?: string;
  secretAccessKey: string;
}

@Injectable()
export class R2StorageService {
  constructor(
    @Inject(FileDataStore) private readonly store: FileDataStore,
    @Inject(CredentialCryptoService) private readonly credentials: CredentialCryptoService
  ) {}

  async isConfigured() {
    return Boolean(await this.runtimeConfig());
  }

  async uploadEncryptedObject(key: string, data: Buffer, contentType = "application/octet-stream") {
    const config = await this.runtimeConfig();
    if (!config?.publicBaseUrl) return undefined;

    await this.client(config).send(
      new PutObjectCommand({
        Bucket: config.bucket,
        Key: key,
        Body: data,
        ContentType: contentType,
        CacheControl: "public, max-age=31536000, immutable"
      })
    );

    return `${config.publicBaseUrl.replace(/\/+$/, "")}/${key.split("/").map(encodeURIComponent).join("/")}`;
  }

  async testConnection() {
    const config = await this.runtimeConfig();
    if (!config) {
      return {
        success: false,
        message: "R2 is not configured"
      };
    }

    const key = `_health/appbox-${Date.now()}.txt`;
    const client = this.client(config);
    await client.send(
      new PutObjectCommand({
        Bucket: config.bucket,
        Key: key,
        Body: Buffer.from("ok", "utf8"),
        ContentType: "text/plain"
      })
    );
    await client.send(new DeleteObjectCommand({ Bucket: config.bucket, Key: key }));
    return {
      success: true,
      bucket: config.bucket,
      endpoint: config.endpoint,
      publicBaseUrl: config.publicBaseUrl
    };
  }

  private client(config: R2RuntimeConfig) {
    return new S3Client({
      region: "auto",
      endpoint: config.endpoint,
      credentials: {
        accessKeyId: config.accessKeyId,
        secretAccessKey: config.secretAccessKey
      }
    });
  }

  private async runtimeConfig(): Promise<R2RuntimeConfig | undefined> {
    const data = await this.store.read();
    const r2 = data.platformConfig?.r2;
    if (!r2?.accountId || !r2.bucket || !r2.accessKeyIdEncrypted || !r2.secretAccessKeyEncrypted) {
      return undefined;
    }

    const accessKeyId = this.credentials.decrypt(r2.accessKeyIdEncrypted);
    const secretAccessKey = this.credentials.decrypt(r2.secretAccessKeyEncrypted);
    if (!accessKeyId || !secretAccessKey) return undefined;

    return {
      accountId: r2.accountId,
      accessKeyId,
      bucket: r2.bucket,
      endpoint: r2.endpoint || `https://${r2.accountId}.r2.cloudflarestorage.com`,
      publicBaseUrl: r2.publicBaseUrl,
      secretAccessKey
    };
  }
}
