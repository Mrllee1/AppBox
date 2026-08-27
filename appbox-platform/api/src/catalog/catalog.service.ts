import { Inject, Injectable } from "@nestjs/common";
import {
  AppBoxApp,
  CatalogAppDTO,
  CatalogCategoryDTO,
  CatalogGroupDTO,
  CatalogResponseDTO
} from "../common/types";
import { FileDataStore } from "../common/file-data-store";

@Injectable()
export class CatalogService {
  constructor(@Inject(FileDataStore) private readonly store: FileDataStore) {}

  async getCatalog(): Promise<CatalogResponseDTO> {
    const data = await this.store.read();
    const enabledApps = data.apps
      .filter((app) => app.enabled)
      .sort((a, b) => a.sort - b.sort);

    const categories: CatalogCategoryDTO[] = data.categories
      .filter((category) => category.enabled)
      .sort((a, b) => a.sort - b.sort)
      .map((category) => {
        const groups: CatalogGroupDTO[] = data.groups
          .filter((group) => group.enabled && group.categoryId === category.id)
          .sort((a, b) => a.sort - b.sort)
          .map((group) => ({
            id: group.id,
            n: group.name,
            ...(group.englishName ? { e: group.englishName } : {}),
            a: enabledApps
              .filter((app) => app.categoryId === category.id && app.groupId === group.id)
              .map((app) => this.toCatalogApp(app))
          }))
          .filter((group) => group.a.length > 0);

        return {
          id: category.id,
          n: category.name,
          ...(category.englishName ? { e: category.englishName } : {}),
          g: groups
        };
      })
      .filter((category) => category.g.length > 0);

    return {
      v: data.version,
      ts: new Date().toISOString(),
      c: categories
    };
  }

  toCatalogApp(app: AppBoxApp): CatalogAppDTO {
    return {
      id: app.id,
      n: app.name,
      t: app.type,
      icon: app.iconAssetUrl || `${this.publicBaseUrl()}/api/v1/appbox/assets/apps/${encodeURIComponent(app.id)}/icon`,
      url: app.type === "ipa" ? app.downloadUrl : app.entryUrl,
      ...(app.bundleId ? { b: app.bundleId } : {}),
      ...(app.type === "ipa" && app.downloadSha256 ? { h: app.downloadSha256 } : {}),
      ...(app.type === "ipa" && app.nivmUrl ? { nu: app.nivmUrl } : {}),
      ...(app.type === "ipa" && app.nivmSha256 ? { nh: app.nivmSha256 } : {}),
      ...(app.type === "ipa" && app.version ? { ver: app.version } : {}),
      ...(app.type === "ipa" && app.build ? { build: app.build } : {})
    };
  }

  private publicBaseUrl() {
    return (process.env.PUBLIC_API_BASE_URL || "http://127.0.0.1:39110").replace(/\/+$/, "");
  }
}
