import { Inject, Injectable, NotFoundException } from "@nestjs/common";
import { z } from "zod";
import { FileDataStore } from "../common/file-data-store";
import { CatalogService } from "../catalog/catalog.service";

export const DeeplinkResolveSchema = z.object({
  app_id: z.string().min(1),
  channel: z.string().optional().default(""),
  p_channel: z.string().optional().default(""),
  dir: z.string().optional().default(""),
  plat: z.string().optional().default("ios"),
  jump_link: z.string().optional().default(""),
  client_version: z.string().optional().default("")
});

@Injectable()
export class DeeplinkService {
  constructor(
    @Inject(FileDataStore) private readonly store: FileDataStore,
    @Inject(CatalogService) private readonly catalog: CatalogService
  ) {}

  async resolve(rawBody: unknown) {
    const body = DeeplinkResolveSchema.parse(rawBody);
    const data = await this.store.read();
    const platform = this.normalizePlatform(body.plat);
    const channel = body.p_channel || body.channel;

    const mapping = data.mappings.find((candidate) => {
      if (!candidate.enabled) return false;
      if (candidate.externalAppId !== body.app_id) return false;
      if (candidate.platform !== "all" && candidate.platform !== platform) return false;
      if (candidate.channel && channel && candidate.channel !== channel) return false;
      return true;
    });

    if (!mapping) {
      throw new NotFoundException({
        success: false,
        error_code: "APP_MAPPING_NOT_FOUND",
        message: "No enabled app mapping matches this deeplink"
      });
    }

    const app = data.apps.find((candidate) => candidate.id === mapping.appId && candidate.enabled);
    if (!app) {
      throw new NotFoundException({
        success: false,
        error_code: "APP_NOT_AVAILABLE",
        message: "Mapped app is not available"
      });
    }

    return {
      ok: 1,
      act: app.type === "ipa" ? "install_or_launch" : "open_web",
      app: this.catalog.toCatalogApp(app)
    };
  }

  private normalizePlatform(value: string): "ios" | "android" | "all" {
    const normalized = value.toLowerCase();
    if (normalized === "3" || normalized === "ios") return "ios";
    if (normalized === "2" || normalized === "android") return "android";
    return "all";
  }
}
