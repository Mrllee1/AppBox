export type AppBoxAppType = "ipa" | "web";

export interface AppBoxCategory {
  id: string;
  name: string;
  englishName?: string;
  sort: number;
  enabled: boolean;
}

export interface AppBoxGroup {
  id: string;
  categoryId: string;
  name: string;
  englishName?: string;
  sort: number;
  enabled: boolean;
}

export interface AppBoxApp {
  id: string;
  name: string;
  englishName?: string;
  type: AppBoxAppType;
  categoryId: string;
  groupId: string;
  iconUrl: string;
  iconAssetId?: string;
  bundleId?: string;
  downloadUrl?: string;
  entryUrl?: string;
  version?: string;
  sort: number;
  enabled: boolean;
  recommended: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface AppBoxExternalMapping {
  id: string;
  appId: string;
  externalAppId: string;
  channel?: string;
  platform: "ios" | "android" | "all";
  enabled: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface AppBoxChannel {
  id: string;
  code: string;
  name: string;
  enabled: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface AppBoxEventLog {
  id: string;
  event: string;
  appId?: string;
  externalAppId?: string;
  channel?: string;
  platform?: string;
  success?: boolean;
  errorCode?: string;
  durationMs?: number;
  deviceId?: string;
  sessionId?: string;
  payload?: Record<string, unknown>;
  createdAt: string;
}

export interface AppBoxStoreData {
  version: number;
  categories: AppBoxCategory[];
  groups: AppBoxGroup[];
  apps: AppBoxApp[];
  mappings: AppBoxExternalMapping[];
  channels: AppBoxChannel[];
  events: AppBoxEventLog[];
}

export interface CatalogAppDTO {
  id: string;
  n: string;
  t: AppBoxAppType;
  icon: string;
  url?: string;
}

export interface CatalogGroupDTO {
  id: string;
  n: string;
  a: CatalogAppDTO[];
}

export interface CatalogCategoryDTO {
  id: string;
  n: string;
  g: CatalogGroupDTO[];
}

export interface CatalogResponseDTO {
  v: number;
  ts: string;
  c: CatalogCategoryDTO[];
}
