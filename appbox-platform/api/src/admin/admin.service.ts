import { Inject, Injectable, NotFoundException } from "@nestjs/common";
import { randomUUID } from "node:crypto";
import { z } from "zod";
import { FileDataStore } from "../common/file-data-store";
import { AppBoxApp, AppBoxExternalMapping } from "../common/types";
import { AssetsService } from "../assets/assets.service";
import { EventsService } from "../events/events.service";

const AppInputSchema = z.object({
  id: z.string().min(1).optional(),
  name: z.string().min(1),
  englishName: z.string().optional(),
  type: z.enum(["ipa", "web"]),
  categoryId: z.string().min(1),
  groupId: z.string().min(1),
  iconUrl: z.string().url(),
  bundleId: z.string().optional(),
  downloadUrl: z.string().url().optional(),
  entryUrl: z.string().url().optional(),
  version: z.string().optional(),
  sort: z.number().int().default(100),
  enabled: z.boolean().default(true),
  recommended: z.boolean().default(false)
});

const MappingInputSchema = z.object({
  appId: z.string().min(1),
  externalAppId: z.string().min(1),
  channel: z.string().optional(),
  platform: z.enum(["ios", "android", "all"]).default("ios"),
  enabled: z.boolean().default(true)
});

@Injectable()
export class AdminService {
  constructor(
    @Inject(FileDataStore) private readonly store: FileDataStore,
    @Inject(AssetsService) private readonly assets: AssetsService,
    @Inject(EventsService) private readonly events: EventsService
  ) {}

  async summary() {
    const data = await this.store.read();
    const eventSummary = await this.events.summary();
    return {
      apps: data.apps.length,
      enabled_apps: data.apps.filter((app) => app.enabled).length,
      ipa_apps: data.apps.filter((app) => app.type === "ipa").length,
      web_apps: data.apps.filter((app) => app.type === "web").length,
      categories: data.categories.length,
      mappings: data.mappings.length,
      channels: data.channels.length,
      events: eventSummary
    };
  }

  async listApps() {
    const data = await this.store.read();
    return {
      success: true,
      data: data.apps.sort((a, b) => a.sort - b.sort)
    };
  }

  async createApp(rawBody: unknown) {
    const input = AppInputSchema.parse(rawBody);
    this.assertAppTarget(input);
    const now = new Date().toISOString();
    const id = input.id || `app_${randomUUID().replace(/-/g, "").slice(0, 12)}`;
    const app: AppBoxApp = {
      id,
      name: input.name,
      englishName: input.englishName,
      type: input.type,
      categoryId: input.categoryId,
      groupId: input.groupId,
      iconUrl: input.iconUrl,
      iconAssetId: await this.assets.createEncryptedAppIconAsset(id, input.iconUrl),
      bundleId: input.bundleId,
      downloadUrl: input.downloadUrl,
      entryUrl: input.entryUrl,
      version: input.version,
      sort: input.sort,
      enabled: input.enabled,
      recommended: input.recommended,
      createdAt: now,
      updatedAt: now
    };

    await this.store.update((data) => {
      if (data.apps.some((candidate) => candidate.id === app.id)) {
        throw new Error(`App id already exists: ${app.id}`);
      }
      data.apps.push(app);
    });

    return { success: true, data: app };
  }

  async updateApp(id: string, rawBody: unknown) {
    const input = AppInputSchema.partial().parse(rawBody);
    this.assertAppTarget(input);
    const nextIconAssetId = input.iconUrl
      ? await this.assets.createEncryptedAppIconAsset(id, input.iconUrl)
      : undefined;
    let updated: AppBoxApp | undefined;
    await this.store.update((data) => {
      const app = data.apps.find((candidate) => candidate.id === id);
      if (!app) return;
      Object.assign(app, input, {
        ...(nextIconAssetId ? { iconAssetId: nextIconAssetId } : {}),
        updatedAt: new Date().toISOString()
      });
      updated = app;
    });

    if (!updated) throw new NotFoundException("App not found");
    return { success: true, data: updated };
  }

  async deleteApp(id: string) {
    let deleted = false;
    await this.store.update((data) => {
      const app = data.apps.find((candidate) => candidate.id === id);
      if (!app) return;
      app.enabled = false;
      app.updatedAt = new Date().toISOString();
      deleted = true;
    });
    if (!deleted) throw new NotFoundException("App not found");
    return { success: true };
  }

  async listCategories() {
    const data = await this.store.read();
    return {
      success: true,
      data: data.categories
    };
  }

  async listGroups() {
    const data = await this.store.read();
    return {
      success: true,
      data: data.groups
    };
  }

  async listMappings() {
    const data = await this.store.read();
    return {
      success: true,
      data: data.mappings
    };
  }

  async createMapping(rawBody: unknown) {
    const input = MappingInputSchema.parse(rawBody);
    const data = await this.store.read();
    if (!data.apps.some((app) => app.id === input.appId)) {
      throw new NotFoundException("Mapped app not found");
    }

    const now = new Date().toISOString();
    const mapping: AppBoxExternalMapping = {
      id: `map_${randomUUID().replace(/-/g, "").slice(0, 12)}`,
      appId: input.appId,
      externalAppId: input.externalAppId,
      channel: input.channel,
      platform: input.platform,
      enabled: input.enabled,
      createdAt: now,
      updatedAt: now
    };

    await this.store.update((storeData) => {
      storeData.mappings.push(mapping);
    });

    return { success: true, data: mapping };
  }

  async listChannels() {
    const data = await this.store.read();
    return {
      success: true,
      data: data.channels
    };
  }

  private assertAppTarget(input: Partial<z.infer<typeof AppInputSchema>>) {
    if (input.type === "ipa" && !input.downloadUrl) {
      throw new Error("IPA apps require downloadUrl");
    }
    if (input.type === "web" && !input.entryUrl) {
      throw new Error("Web apps require entryUrl");
    }
  }
}
