import { AppBoxStoreData } from "./types";

const now = new Date("2026-08-07T00:00:00.000Z").toISOString();

export const seedData: AppBoxStoreData = {
  version: 1,
  platformConfig: {
    apiEntrypoints: [
      {
        baseUrl: "https://666999.lol",
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
  },
  categories: [
    {
      id: "tools",
      name: "工具系列",
      englishName: "Tools",
      sort: 10,
      enabled: true
    }
  ],
  groups: [
    {
      id: "wallet",
      categoryId: "tools",
      name: "钱包",
      englishName: "Wallet",
      sort: 10,
      enabled: true
    }
  ],
  apps: [
    {
      id: "tianya_selected",
      name: "天涯精选",
      englishName: "Tianya Select",
      type: "ipa",
      categoryId: "tools",
      groupId: "wallet",
      iconUrl: "https://pub-d768a0879cb24ceaa4a0cfe8b73ee372.r2.dev/icons/tianya-selected.png",
      bundleId: "app.nqyqstm6mu.tianya",
      downloadUrl: "https://pub-d768a0879cb24ceaa4a0cfe8b73ee372.r2.dev/ty1.ipa",
      downloadSha256: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      nivmUrl: "https://pub-d768a0879cb24ceaa4a0cfe8b73ee372.r2.dev/ty1.nivm",
      nivmSha256: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      version: "1.0.0",
      build: "1",
      sort: 10,
      enabled: true,
      recommended: true,
      createdAt: now,
      updatedAt: now
    }
  ],
  mappings: [
    {
      id: "map_3101_ios",
      appId: "tianya_selected",
      externalAppId: "3101",
      channel: "wc2dc",
      platform: "ios",
      enabled: true,
      createdAt: now,
      updatedAt: now
    },
    {
      id: "map_3101_all",
      appId: "tianya_selected",
      externalAppId: "3101",
      platform: "all",
      enabled: true,
      createdAt: now,
      updatedAt: now
    }
  ],
  channels: [
    {
      id: "channel_wc2dc",
      code: "wc2dc",
      name: "默认落地页渠道",
      enabled: true,
      createdAt: now,
      updatedAt: now
    }
  ],
  events: []
};
