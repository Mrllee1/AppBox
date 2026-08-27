import { BadRequestException, Inject, Injectable } from "@nestjs/common";
import { createCipheriv, createHash, randomBytes } from "node:crypto";
import { z } from "zod";
import { FileDataStore } from "../common/file-data-store";
import { AppBoxApiEntrypoint, AppBoxPlatformConfig } from "../common/types";
import { CredentialCryptoService } from "./credential-crypto.service";
import { R2StorageService } from "./r2-storage.service";

const ApiEntrypointSchema = z.object({
  baseUrl: z.string().url(),
  enabled: z.boolean().default(true),
  weight: z.number().int().min(0).max(10000).default(100)
});

const PlatformConfigInputSchema = z.object({
  apiEntrypoints: z.array(ApiEntrypointSchema).min(1),
  github: z.object({
    owner: z.string().min(1),
    repo: z.string().min(1),
    branch: z.string().min(1).default("main"),
    filePath: z.string().min(1).default("version.json"),
    token: z.string().optional()
  }),
  r2: z.object({
    accountId: z.string().optional(),
    bucket: z.string().optional(),
    endpoint: z.string().url().optional().or(z.literal("")),
    publicBaseUrl: z.string().url().optional().or(z.literal("")),
    accessKeyId: z.string().optional(),
    secretAccessKey: z.string().optional(),
    apiToken: z.string().optional()
  }).optional()
});

@Injectable()
export class PlatformConfigService {
  constructor(
    @Inject(FileDataStore) private readonly store: FileDataStore,
    @Inject(CredentialCryptoService) private readonly credentials: CredentialCryptoService,
    @Inject(R2StorageService) private readonly r2: R2StorageService
  ) {}

  async getAdminConfig() {
    const config = await this.readConfig();
    return {
      success: true,
      data: this.sanitizeConfig(config),
      cdnUrls: this.configSourceUrls(config.github)
    };
  }

  async updateAdminConfig(rawBody: unknown) {
    const input = PlatformConfigInputSchema.parse(rawBody);
    const current = await this.readConfig();
    const now = new Date().toISOString();
    const next: AppBoxPlatformConfig = {
      apiEntrypoints: this.normalizeEntrypoints(input.apiEntrypoints),
      github: {
        owner: input.github.owner.trim(),
        repo: input.github.repo.trim(),
        branch: input.github.branch.trim() || "main",
        filePath: input.github.filePath.trim() || "version.json",
        tokenEncrypted: input.github.token
          ? this.credentials.encrypt(input.github.token)
          : current.github.tokenEncrypted,
        tokenUpdatedAt: input.github.token ? now : current.github.tokenUpdatedAt
      },
      r2: input.r2
        ? {
            accountId: input.r2.accountId?.trim() || "",
            bucket: input.r2.bucket?.trim() || "",
            endpoint: input.r2.endpoint?.trim() || undefined,
            publicBaseUrl: input.r2.publicBaseUrl?.trim() || undefined,
            accessKeyIdEncrypted: input.r2.accessKeyId
              ? this.credentials.encrypt(input.r2.accessKeyId)
              : current.r2?.accessKeyIdEncrypted,
            secretAccessKeyEncrypted: input.r2.secretAccessKey
              ? this.credentials.encrypt(input.r2.secretAccessKey)
              : current.r2?.secretAccessKeyEncrypted,
            apiTokenEncrypted: input.r2.apiToken
              ? this.credentials.encrypt(input.r2.apiToken)
              : current.r2?.apiTokenEncrypted,
            updatedAt: now
          }
        : current.r2,
      updatedAt: now
    };

    await this.store.update((data) => {
      data.platformConfig = next;
    });

    return {
      success: true,
      data: this.sanitizeConfig(next),
      cdnUrls: this.configSourceUrls(next.github)
    };
  }

  async previewRemoteConfig() {
    const config = await this.readConfig();
    return {
      success: true,
      data: {
        plain: this.remoteConfigPayload(config),
        encrypted: this.encryptRemoteConfig(config),
        cdnUrls: this.configSourceUrls(config.github)
      }
    };
  }

  async testEntrypoints() {
    const config = await this.readConfig();
    const results = [];
    for (const entry of this.enabledEntrypoints(config)) {
      const started = Date.now();
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 6000);
      try {
        const response = await fetch(`${entry.baseUrl}/health`, {
          signal: controller.signal,
          headers: { "User-Agent": "AppBoxAdmin/1.0" }
        });
        results.push({
          baseUrl: entry.baseUrl,
          ok: response.ok,
          status: response.status,
          elapsedMs: Date.now() - started
        });
      } catch (error) {
        results.push({
          baseUrl: entry.baseUrl,
          ok: false,
          error: error instanceof Error ? error.message : String(error),
          elapsedMs: Date.now() - started
        });
      } finally {
        clearTimeout(timer);
      }
    }
    return { success: true, data: results };
  }

  async testR2() {
    return this.r2.testConnection();
  }

  async publishRemoteConfig() {
    const config = await this.readConfig();
    const token = this.credentials.decrypt(config.github.tokenEncrypted);
    if (!token) {
      throw new BadRequestException("GitHub token is not configured");
    }

    await this.ensureGitHubRepository(config, token);
    const encrypted = this.encryptRemoteConfig(config);
    const commit = await this.putGitHubFile(config, token, encrypted);
    const purged = await this.purgeConfigUrls(config);
    return {
      success: true,
      data: {
        commit,
        purged,
        cdnUrls: this.configSourceUrls(config.github)
      }
    };
  }

  async readConfig(): Promise<AppBoxPlatformConfig> {
    const data = await this.store.read();
    if (data.platformConfig) return data.platformConfig;
    const now = new Date().toISOString();
    return {
      apiEntrypoints: [
        {
          baseUrl: (process.env.PUBLIC_API_BASE_URL || "https://666999.lol").replace(/\/+$/, ""),
          enabled: true,
          weight: 100
        }
      ],
      github: {
        owner: "yasuo185239-beep",
        repo: "appbox-config",
        branch: "main",
        filePath: "version.json"
      },
      updatedAt: now
    };
  }

  private sanitizeConfig(config: AppBoxPlatformConfig) {
    const githubToken = this.credentials.decrypt(config.github.tokenEncrypted);
    const r2AccessKey = this.credentials.decrypt(config.r2?.accessKeyIdEncrypted);
    const r2Secret = this.credentials.decrypt(config.r2?.secretAccessKeyEncrypted);
    const r2Token = this.credentials.decrypt(config.r2?.apiTokenEncrypted);
    return {
      apiEntrypoints: config.apiEntrypoints,
      github: {
        owner: config.github.owner,
        repo: config.github.repo,
        branch: config.github.branch,
        filePath: config.github.filePath,
        tokenConfigured: Boolean(githubToken),
        tokenMasked: this.credentials.maskSecret(githubToken)
      },
      r2: {
        accountId: config.r2?.accountId || "",
        bucket: config.r2?.bucket || "",
        endpoint: config.r2?.endpoint || "",
        publicBaseUrl: config.r2?.publicBaseUrl || "",
        accessKeyIdConfigured: Boolean(r2AccessKey),
        accessKeyIdMasked: this.credentials.maskSecret(r2AccessKey),
        secretAccessKeyConfigured: Boolean(r2Secret),
        secretAccessKeyMasked: this.credentials.maskSecret(r2Secret),
        apiTokenConfigured: Boolean(r2Token),
        apiTokenMasked: this.credentials.maskSecret(r2Token)
      },
      updatedAt: config.updatedAt
    };
  }

  private normalizeEntrypoints(entries: AppBoxApiEntrypoint[]) {
    const seen = new Set<string>();
    return entries
      .map((entry) => ({
        baseUrl: entry.baseUrl.replace(/\/+$/, ""),
        enabled: entry.enabled,
        weight: entry.weight
      }))
      .filter((entry) => {
        if (seen.has(entry.baseUrl)) return false;
        seen.add(entry.baseUrl);
        return true;
      });
  }

  private enabledEntrypoints(config: AppBoxPlatformConfig) {
    return this.normalizeEntrypoints(config.apiEntrypoints)
      .filter((entry) => entry.enabled)
      .sort((a, b) => b.weight - a.weight);
  }

  private remoteConfigPayload(config: AppBoxPlatformConfig) {
    return {
      v: 1,
      api: this.enabledEntrypoints(config).map((entry) => entry.baseUrl),
      updatedAt: new Date().toISOString()
    };
  }

  private encryptRemoteConfig(config: AppBoxPlatformConfig) {
    const iv = randomBytes(12);
    const key = this.loadClientKey();
    const cipher = createCipheriv("aes-256-gcm", key, iv);
    const plaintext = Buffer.from(JSON.stringify(this.remoteConfigPayload(config)), "utf8");
    const encrypted = Buffer.concat([cipher.update(plaintext), cipher.final()]);
    return Buffer.concat([iv, encrypted, cipher.getAuthTag()]).toString("base64");
  }

  private loadClientKey() {
    const configured = process.env.APPBOX_CLIENT_AES_KEY || "6btlrID18OytwUZ0s41atap+4WxlXr1xpebjrE04hnY=";
    const raw = this.decodeConfiguredKey(configured);
    return raw.length === 32 ? raw : createHash("sha256").update(raw).digest();
  }

  private decodeConfiguredKey(value: string) {
    if (/^[a-f0-9]{64}$/i.test(value)) return Buffer.from(value, "hex");
    try {
      const decoded = Buffer.from(value, "base64");
      if (decoded.length > 0) return decoded;
    } catch {
      // Fall through to utf8.
    }
    return Buffer.from(value, "utf8");
  }

  private configSourceUrls(github: AppBoxPlatformConfig["github"]) {
    const owner = encodeURIComponent(github.owner);
    const repo = encodeURIComponent(github.repo);
    const branch = encodeURIComponent(github.branch || "main");
    const filePath = github.filePath.split("/").map(encodeURIComponent).join("/");
    return [
      `https://raw.githubusercontent.com/${owner}/${repo}/${branch}/${filePath}`,
      `https://cdn.jsdelivr.net/gh/${owner}/${repo}@${branch}/${filePath}`,
      `https://fastly.jsdelivr.net/gh/${owner}/${repo}@${branch}/${filePath}`,
      `https://gcore.jsdelivr.net/gh/${owner}/${repo}@${branch}/${filePath}`
    ];
  }

  private async ensureGitHubRepository(config: AppBoxPlatformConfig, token: string) {
    const repoUrl = `https://api.github.com/repos/${config.github.owner}/${config.github.repo}`;
    const existing = await fetch(repoUrl, { headers: this.githubHeaders(token) });
    if (existing.ok) return;
    if (existing.status !== 404) {
      throw new BadRequestException(`GitHub repo check failed: HTTP ${existing.status}`);
    }

    const created = await fetch("https://api.github.com/user/repos", {
      method: "POST",
      headers: this.githubHeaders(token),
      body: JSON.stringify({
        name: config.github.repo,
        private: false,
        auto_init: true,
        description: "Encrypted AppBox client remote configuration"
      })
    });
    if (!created.ok) {
      throw new BadRequestException(`GitHub repo create failed: HTTP ${created.status} ${await created.text()}`);
    }
  }

  private async putGitHubFile(config: AppBoxPlatformConfig, token: string, content: string) {
    const encodedPath = config.github.filePath.split("/").map(encodeURIComponent).join("/");
    const url = `https://api.github.com/repos/${config.github.owner}/${config.github.repo}/contents/${encodedPath}`;
    const branch = config.github.branch || "main";
    const existing = await fetch(`${url}?ref=${encodeURIComponent(branch)}`, {
      headers: this.githubHeaders(token)
    });
    const current = existing.ok ? await existing.json() as { sha?: string } : undefined;
    const put = await fetch(url, {
      method: "PUT",
      headers: this.githubHeaders(token),
      body: JSON.stringify({
        message: "Publish AppBox remote config",
        content: Buffer.from(content, "utf8").toString("base64"),
        branch,
        ...(current?.sha ? { sha: current.sha } : {})
      })
    });
    if (!put.ok) {
      throw new BadRequestException(`GitHub file publish failed: HTTP ${put.status} ${await put.text()}`);
    }
    const payload = await put.json() as { commit?: { sha?: string; html_url?: string } };
    return payload.commit || {};
  }

  private async purgeConfigUrls(config: AppBoxPlatformConfig) {
    const results = [];
    for (const url of this.configSourceUrls(config.github).filter((item) => item.includes("jsdelivr.net"))) {
      const purgeUrl = url.replace("https://cdn.jsdelivr.net/", "https://purge.jsdelivr.net/")
        .replace("https://fastly.jsdelivr.net/", "https://purge.jsdelivr.net/")
        .replace("https://gcore.jsdelivr.net/", "https://purge.jsdelivr.net/");
      try {
        const response = await fetch(purgeUrl);
        results.push({ url: purgeUrl, ok: response.ok, status: response.status });
      } catch (error) {
        results.push({ url: purgeUrl, ok: false, error: error instanceof Error ? error.message : String(error) });
      }
    }
    return results;
  }

  private githubHeaders(token: string) {
    return {
      Accept: "application/vnd.github+json",
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      "User-Agent": "AppBoxConfigPublisher/1.0",
      "X-GitHub-Api-Version": "2022-11-28"
    };
  }
}
