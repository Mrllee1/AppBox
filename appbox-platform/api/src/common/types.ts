export type AppBoxAppType = "ipa" | "web";

export interface AppBoxCategory {
  id: string;
  name: string;
  englishName?: string;
  sort: number;
  enabled: boolean;
  createdAt?: string;
  updatedAt?: string;
}

export interface AppBoxGroup {
  id: string;
  categoryId: string;
  name: string;
  englishName?: string;
  sort: number;
  enabled: boolean;
  createdAt?: string;
  updatedAt?: string;
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
  iconAssetUrl?: string;
  bundleId?: string;
  downloadUrl?: string;
  downloadSha256?: string;
  nivmUrl?: string;
  nivmSha256?: string;
  entryUrl?: string;
  version?: string;
  build?: string;
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

export interface AppBoxInternalUnlockCode {
  id: string;
  codeHash: string;
  createdAt: string;
  expiresAt: string;
  consumedAt?: string;
  consumedByHash?: string;
}

export interface AppBoxApiEntrypoint {
  baseUrl: string;
  enabled: boolean;
  weight: number;
}

export interface AppBoxGitHubConfig {
  owner: string;
  repo: string;
  branch: string;
  filePath: string;
  tokenEncrypted?: string;
  tokenUpdatedAt?: string;
}

export interface AppBoxR2Config {
  accountId: string;
  bucket: string;
  endpoint?: string;
  publicBaseUrl?: string;
  accessKeyIdEncrypted?: string;
  secretAccessKeyEncrypted?: string;
  apiTokenEncrypted?: string;
  updatedAt?: string;
}

export interface AppBoxPlatformConfig {
  apiEntrypoints: AppBoxApiEntrypoint[];
  github: AppBoxGitHubConfig;
  r2?: AppBoxR2Config;
  updatedAt: string;
}

export interface AppBoxStoreData {
  version: number;
  platformConfig?: AppBoxPlatformConfig;
  categories: AppBoxCategory[];
  groups: AppBoxGroup[];
  apps: AppBoxApp[];
  mappings: AppBoxExternalMapping[];
  channels: AppBoxChannel[];
  events: AppBoxEventLog[];
  internalUnlockCodes?: AppBoxInternalUnlockCode[];
}

export interface CatalogAppDTO {
  id: string;
  n: string;
  t: AppBoxAppType;
  icon: string;
  url?: string;
  b?: string;
  h?: string;
  nu?: string;
  nh?: string;
  ver?: string;
  build?: string;
}

export interface CatalogGroupDTO {
  id: string;
  n: string;
  e?: string;
  a: CatalogAppDTO[];
}

export interface CatalogCategoryDTO {
  id: string;
  n: string;
  e?: string;
  g: CatalogGroupDTO[];
}

export interface CatalogResponseDTO {
  v: number;
  ts: string;
  c: CatalogCategoryDTO[];
}
