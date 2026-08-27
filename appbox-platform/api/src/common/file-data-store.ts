import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { Injectable } from "@nestjs/common";
import { seedData } from "./seed";
import { AppBoxApp, AppBoxStoreData } from "./types";

@Injectable()
export class FileDataStore {
  private readonly filePath = resolve(
    process.cwd(),
    process.env.APPBOX_DATA_FILE || "data/appbox-store.json"
  );
  private initPromise?: Promise<void>;
  private updateQueue: Promise<void> = Promise.resolve();

  async read(): Promise<AppBoxStoreData> {
    await this.ensureInitialized();
    const raw = await readFile(this.filePath, "utf8");
    return JSON.parse(raw) as AppBoxStoreData;
  }

  async write(data: AppBoxStoreData): Promise<void> {
    await this.ensureInitialized();
    await this.writeRaw(data);
  }

  async update(mutator: (data: AppBoxStoreData) => void | Promise<void>): Promise<AppBoxStoreData> {
    let result: AppBoxStoreData | undefined;
    const operation = this.updateQueue.then(async () => {
      const data = await this.read();
      await mutator(data);
      data.version += 1;
      await this.writeRaw(data);
      result = data;
    });
    this.updateQueue = operation.then(
      () => undefined,
      () => undefined
    );
    await operation;
    return result as AppBoxStoreData;
  }

  private async ensureInitialized(): Promise<void> {
    if (!this.initPromise) {
      this.initPromise = this.initialize();
    }
    await this.initPromise;
  }

  private async initialize(): Promise<void> {
    await mkdir(dirname(this.filePath), { recursive: true });
    let raw: string;
    try {
      raw = await readFile(this.filePath, "utf8");
    } catch {
      await this.writeRaw(seedData);
      return;
    }

    const parsed = JSON.parse(raw) as AppBoxStoreData;
    const hasInvalidEnabledIPA = parsed.apps.some(
      (app) => app.type === "ipa" && app.enabled && !this.isNIVMReady(app)
    );
    if (hasInvalidEnabledIPA) {
      const apps = parsed.apps.map((app) => {
        if (app.type === "ipa" && !this.isNIVMReady(app)) {
          return { ...app, enabled: false };
        }
        return app;
      });
      await this.writeRaw({
        ...parsed,
        version: parsed.version + 1,
        apps
      });
    }
  }

  private isNIVMReady(app: AppBoxApp): boolean {
    return Boolean(
      app.bundleId &&
      app.version &&
      app.build &&
      app.downloadUrl &&
      /^[a-fA-F0-9]{64}$/.test(app.downloadSha256 || "") &&
      app.nivmUrl &&
      /^[a-fA-F0-9]{64}$/.test(app.nivmSha256 || "")
    );
  }

  private async writeRaw(data: AppBoxStoreData): Promise<void> {
    await writeFile(this.filePath, JSON.stringify(data, null, 2), "utf8");
  }
}
