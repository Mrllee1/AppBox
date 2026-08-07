import { mkdir, readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { Inject, Injectable, NotFoundException } from "@nestjs/common";
import { FileDataStore } from "../common/file-data-store";
import { AppBoxApp } from "../common/types";
import { AssetCryptoService } from "./asset-crypto.service";

const fallbackPng = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=",
  "base64"
);

@Injectable()
export class AssetsService {
  private readonly assetDir = resolve(process.cwd(), process.env.APPBOX_ASSET_DIR || "data/assets");

  constructor(
    @Inject(FileDataStore) private readonly store: FileDataStore,
    @Inject(AssetCryptoService) private readonly crypto: AssetCryptoService
  ) {}

  async getAppIconFile(id: string) {
    const data = await this.store.read();
    const app = data.apps.find((candidate) => candidate.id === id && candidate.enabled);
    if (!app) {
      throw new NotFoundException({
        success: false,
        error_code: "ASSET_NOT_FOUND",
        message: "App icon asset is not available"
      });
    }

    const assetId = await this.ensureAppIconAsset(app);
    return readFile(this.assetPath(assetId));
  }

  async createEncryptedAppIconAsset(appId: string, iconUrl: string) {
    const asset = await this.fetchAsset(iconUrl);
    const assetId = this.iconAssetId(appId);
    await mkdir(this.assetDir, { recursive: true });
    await writeFile(
      this.assetPath(assetId),
      this.crypto.encryptImageBytes(asset.data)
    );
    return assetId;
  }

  async materializeMissingAppIconAssets() {
    const data = await this.store.read();
    let materialized = 0;
    for (const app of data.apps) {
      if (app.iconAssetId && (await this.assetExists(app.iconAssetId))) continue;
      const assetId = await this.createEncryptedAppIconAsset(app.id, app.iconUrl);
      await this.store.update((storeData) => {
        const target = storeData.apps.find((candidate) => candidate.id === app.id);
        if (target) target.iconAssetId = assetId;
      });
      materialized += 1;
    }
    return { success: true, materialized };
  }

  private async ensureAppIconAsset(app: AppBoxApp) {
    if (app.iconAssetId && (await this.assetExists(app.iconAssetId))) {
      return app.iconAssetId;
    }

    const assetId = await this.createEncryptedAppIconAsset(app.id, app.iconUrl);
    await this.store.update((data) => {
      const target = data.apps.find((candidate) => candidate.id === app.id);
      if (target) target.iconAssetId = assetId;
    });
    return assetId;
  }

  private async assetExists(assetId: string) {
    try {
      await readFile(this.assetPath(assetId));
      return true;
    } catch {
      return false;
    }
  }

  private iconAssetId(appId: string) {
    return `app-icon-${appId.replace(/[^a-zA-Z0-9_-]/g, "_")}`;
  }

  private assetPath(assetId: string) {
    return resolve(this.assetDir, `${assetId}.enc`);
  }

  private async fetchAsset(url: string) {
    if (url.startsWith("data:")) {
      return this.readDataUrl(url);
    }

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 5000);
    try {
      const response = await fetch(url, { signal: controller.signal });
      if (!response.ok) throw new Error(`Asset fetch failed: ${response.status}`);
      const data = Buffer.from(await response.arrayBuffer());
      return { data };
    } catch {
      return {
        data: fallbackPng
      };
    } finally {
      clearTimeout(timer);
    }
  }

  private readDataUrl(url: string) {
    const match = /^data:([^;,]+);base64,(.+)$/i.exec(url);
    if (!match) {
      return {
        data: fallbackPng
      };
    }
    return {
      data: Buffer.from(match[2], "base64")
    };
  }
}
