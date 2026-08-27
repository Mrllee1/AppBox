import { AppBoxStoreData } from "./types";

const now = new Date("2026-08-07T00:00:00.000Z").toISOString();

export const seedData: AppBoxStoreData = {
  version: 1,
  platformConfig: {
    apiEntrypoints: [
      {
        baseUrl: "https://3601.help",
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
  categories: [],
  groups: [],
  apps: [],
  mappings: [],
  channels: [],
  events: []
};
