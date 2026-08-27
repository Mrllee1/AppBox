import { BadRequestException, Inject, Injectable, NotFoundException } from "@nestjs/common";
import { randomUUID } from "node:crypto";
import { z } from "zod";
import { FileDataStore } from "../common/file-data-store";
import { AppBoxApp, AppBoxCategory, AppBoxExternalMapping, AppBoxGroup, AppBoxStoreData } from "../common/types";
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
  downloadSha256: z.string().regex(/^[a-fA-F0-9]{64}$/).optional(),
  nivmUrl: z.string().url().optional(),
  nivmSha256: z.string().regex(/^[a-fA-F0-9]{64}$/).optional(),
  entryUrl: z.string().url().optional(),
  version: z.string().optional(),
  build: z.string().optional(),
  sort: z.number().int().default(100),
  enabled: z.boolean().default(true),
  recommended: z.boolean().default(false)
}).strict();

// Zod preserves defaults through partial(), which makes an omitted field look
// present during PATCH-style updates. Override every defaulted property so a
// URL-only update cannot silently reset ordering or visibility.
const AppUpdateSchema = AppInputSchema.partial().extend({
  sort: z.number().int().optional(),
  enabled: z.boolean().optional(),
  recommended: z.boolean().optional()
});

const CategoryInputSchema = z.object({
  id: z.string().min(1).optional(),
  name: z.string().min(1),
  englishName: z.string().optional(),
  sort: z.number().int().default(100),
  enabled: z.boolean().default(true)
});

const GroupInputSchema = z.object({
  id: z.string().min(1).optional(),
  categoryId: z.string().min(1),
  name: z.string().min(1),
  englishName: z.string().optional(),
  sort: z.number().int().default(100),
  enabled: z.boolean().default(true)
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
    const input = this.parseAppInput(rawBody);
    const existing = await this.store.read();
    this.assertAppTarget(input);
    this.assertCategoryGroup(existing, input.categoryId, input.groupId);
    const now = new Date().toISOString();
    const id = input.id || `app_${randomUUID().replace(/-/g, "").slice(0, 12)}`;
    if (existing.apps.some((candidate) => candidate.id === id)) {
      throw new Error(`App id already exists: ${id}`);
    }
    const iconAsset = await this.assets.createEncryptedAppIconAsset(id, input.iconUrl);
    const app: AppBoxApp = {
      id,
      name: input.name,
      englishName: input.englishName,
      type: input.type,
      categoryId: input.categoryId,
      groupId: input.groupId,
      iconUrl: input.iconUrl,
      iconAssetId: iconAsset.assetId,
      iconAssetUrl: iconAsset.assetUrl,
      bundleId: input.bundleId,
      downloadUrl: input.downloadUrl,
      downloadSha256: input.downloadSha256?.toLowerCase(),
      nivmUrl: input.nivmUrl,
      nivmSha256: input.nivmSha256?.toLowerCase(),
      entryUrl: input.entryUrl,
      version: input.version,
      build: input.build,
      sort: input.sort,
      enabled: input.enabled,
      recommended: input.recommended,
      createdAt: now,
      updatedAt: now
    };

    await this.store.update((data) => {
      data.apps.push(app);
    });

    return { success: true, data: app };
  }

  async updateApp(id: string, rawBody: unknown) {
    const parsedInput = this.parseAppUpdate(rawBody);
    const input = {
      ...parsedInput,
      ...(parsedInput.downloadSha256
        ? { downloadSha256: parsedInput.downloadSha256.toLowerCase() }
        : {}),
      ...(parsedInput.nivmSha256
        ? { nivmSha256: parsedInput.nivmSha256.toLowerCase() }
        : {})
    };
    const existing = await this.store.read();
    const current = existing.apps.find((candidate) => candidate.id === id);
    if (!current) throw new NotFoundException("App not found");
    this.assertAppTarget({ ...current, ...input });
    this.assertCategoryGroup(
      existing,
      input.categoryId ?? current.categoryId,
      input.groupId ?? current.groupId
    );
    const nextIconAsset = input.iconUrl
      ? await this.assets.createEncryptedAppIconAsset(id, input.iconUrl)
      : undefined;
    let updated: AppBoxApp | undefined;
    await this.store.update((data) => {
      const app = data.apps.find((candidate) => candidate.id === id);
      if (!app) return;
      Object.assign(app, input, {
        ...(nextIconAsset
          ? {
              iconAssetId: nextIconAsset.assetId,
              ...(nextIconAsset.assetUrl ? { iconAssetUrl: nextIconAsset.assetUrl } : {})
            }
          : {}),
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
      data: data.categories.sort((a, b) => a.sort - b.sort)
    };
  }

  async createCategory(rawBody: unknown) {
    const input = CategoryInputSchema.parse(rawBody);
    const now = new Date().toISOString();
    const id = input.id || `cat_${randomUUID().replace(/-/g, "").slice(0, 12)}`;
    const category: AppBoxCategory = {
      id,
      name: input.name,
      englishName: input.englishName,
      sort: input.sort,
      enabled: input.enabled,
      createdAt: now,
      updatedAt: now
    };

    await this.store.update((data) => {
      if (data.categories.some((candidate) => candidate.id === category.id)) {
        throw new Error(`Category id already exists: ${category.id}`);
      }
      data.categories.push(category);
    });

    return { success: true, data: category };
  }

  async updateCategory(id: string, rawBody: unknown) {
    const { id: _ignoredId, ...input } = CategoryInputSchema.partial().parse(rawBody);
    let updated: AppBoxCategory | undefined;
    await this.store.update((data) => {
      const category = data.categories.find((candidate) => candidate.id === id);
      if (!category) return;
      Object.assign(category, input, { updatedAt: new Date().toISOString() });
      updated = category;
    });

    if (!updated) throw new NotFoundException("Category not found");
    return { success: true, data: updated };
  }

  async deleteCategory(id: string) {
    let deleted = false;
    await this.store.update((data) => {
      const category = data.categories.find((candidate) => candidate.id === id);
      if (!category) return;
      const now = new Date().toISOString();
      category.enabled = false;
      category.updatedAt = now;
      for (const group of data.groups.filter((candidate) => candidate.categoryId === id)) {
        group.enabled = false;
        group.updatedAt = now;
      }
      deleted = true;
    });
    if (!deleted) throw new NotFoundException("Category not found");
    return { success: true };
  }

  async listGroups() {
    const data = await this.store.read();
    return {
      success: true,
      data: data.groups.sort((a, b) => a.sort - b.sort)
    };
  }

  async createGroup(rawBody: unknown) {
    const input = GroupInputSchema.parse(rawBody);
    const existing = await this.store.read();
    this.assertCategory(existing, input.categoryId);
    const now = new Date().toISOString();
    const id = input.id || `grp_${randomUUID().replace(/-/g, "").slice(0, 12)}`;
    const group: AppBoxGroup = {
      id,
      categoryId: input.categoryId,
      name: input.name,
      englishName: input.englishName,
      sort: input.sort,
      enabled: input.enabled,
      createdAt: now,
      updatedAt: now
    };

    await this.store.update((data) => {
      if (data.groups.some((candidate) => candidate.id === group.id)) {
        throw new Error(`Group id already exists: ${group.id}`);
      }
      data.groups.push(group);
    });

    return { success: true, data: group };
  }

  async updateGroup(id: string, rawBody: unknown) {
    const { id: _ignoredId, ...input } = GroupInputSchema.partial().parse(rawBody);
    const existing = await this.store.read();
    if (input.categoryId) this.assertCategory(existing, input.categoryId);
    let updated: AppBoxGroup | undefined;
    await this.store.update((data) => {
      const group = data.groups.find((candidate) => candidate.id === id);
      if (!group) return;
      Object.assign(group, input, { updatedAt: new Date().toISOString() });
      updated = group;
    });

    if (!updated) throw new NotFoundException("Group not found");
    return { success: true, data: updated };
  }

  async deleteGroup(id: string) {
    let deleted = false;
    await this.store.update((data) => {
      const group = data.groups.find((candidate) => candidate.id === id);
      if (!group) return;
      group.enabled = false;
      group.updatedAt = new Date().toISOString();
      deleted = true;
    });
    if (!deleted) throw new NotFoundException("Group not found");
    return { success: true };
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
      throw new BadRequestException("IPA apps require downloadUrl");
    }
    if (input.type === "ipa") {
      if (!input.bundleId || !input.version || !input.build) {
        throw new BadRequestException("NIVM apps require bundleId, version and build");
      }
      if (!input.downloadSha256 || !input.nivmUrl || !input.nivmSha256) {
        throw new BadRequestException("NIVM apps require downloadSha256, nivmUrl and nivmSha256");
      }
    }
    if (input.type === "web" && !input.entryUrl) {
      throw new BadRequestException("Web apps require entryUrl");
    }
  }

  private parseAppInput(rawBody: unknown): z.infer<typeof AppInputSchema> {
    const result = AppInputSchema.safeParse(rawBody);
    if (!result.success) {
      throw new BadRequestException({
        success: false,
        error_code: "INVALID_APP_PAYLOAD",
        details: result.error.issues
      });
    }
    return result.data;
  }

  private parseAppUpdate(rawBody: unknown): z.infer<typeof AppUpdateSchema> {
    const result = AppUpdateSchema.safeParse(rawBody);
    if (!result.success) {
      throw new BadRequestException({
        success: false,
        error_code: "INVALID_APP_PAYLOAD",
        details: result.error.issues
      });
    }
    return result.data;
  }

  private assertCategory(data: AppBoxStoreData, categoryId: string) {
    const category = data.categories.find((candidate) => candidate.id === categoryId);
    if (!category || !category.enabled) {
      throw new NotFoundException("Category not found");
    }
  }

  private assertCategoryGroup(data: AppBoxStoreData, categoryId: string, groupId: string) {
    this.assertCategory(data, categoryId);
    const group = data.groups.find((candidate) => candidate.id === groupId);
    if (!group || !group.enabled || group.categoryId !== categoryId) {
      throw new NotFoundException("Group not found for selected category");
    }
  }
}
