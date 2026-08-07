import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { Injectable } from "@nestjs/common";
import { seedData } from "./seed";
import { AppBoxStoreData } from "./types";

@Injectable()
export class FileDataStore {
  private readonly filePath = resolve(
    process.cwd(),
    process.env.APPBOX_DATA_FILE || "data/appbox-store.json"
  );
  private initPromise?: Promise<void>;

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
    const data = await this.read();
    await mutator(data);
    data.version += 1;
    await this.writeRaw(data);
    return data;
  }

  private async ensureInitialized(): Promise<void> {
    if (!this.initPromise) {
      this.initPromise = this.initialize();
    }
    await this.initPromise;
  }

  private async initialize(): Promise<void> {
    await mkdir(dirname(this.filePath), { recursive: true });
    try {
      await readFile(this.filePath, "utf8");
    } catch {
      await this.writeRaw(seedData);
    }
  }

  private async writeRaw(data: AppBoxStoreData): Promise<void> {
    await writeFile(this.filePath, JSON.stringify(data, null, 2), "utf8");
  }
}
