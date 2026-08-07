export type AppType = "ipa" | "web";

export interface AdminApp {
  id: string;
  name: string;
  englishName?: string;
  type: AppType;
  categoryId: string;
  groupId: string;
  iconUrl: string;
  bundleId?: string;
  downloadUrl?: string;
  entryUrl?: string;
  version?: string;
  sort: number;
  enabled: boolean;
  recommended: boolean;
}

export interface AdminSummary {
  apps: number;
  enabled_apps: number;
  ipa_apps: number;
  web_apps: number;
  categories: number;
  mappings: number;
  channels: number;
  events: Record<string, number>;
}

export interface AdminUser {
  role: "admin";
  username: string;
}

export interface LoginResponse {
  expires_at: string;
  success: true;
  token: string;
  user: AdminUser;
}

const API_BASE =
  process.env.NEXT_PUBLIC_API_BASE_URL ?? (process.env.NODE_ENV === "production" ? "" : "http://127.0.0.1:39110");
let adminToken = "";

export function setAdminToken(token: string) {
  adminToken = token;
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const headers = new Headers(init?.headers);
  headers.set("Content-Type", "application/json");
  if (adminToken) {
    headers.set("Authorization", `Bearer ${adminToken}`);
  }

  const response = await fetch(`${API_BASE}${path}`, {
    ...init,
    headers,
    cache: "no-store"
  });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`${response.status} ${response.statusText}: ${text}`);
  }
  return response.json() as Promise<T>;
}

export const api = {
  baseUrl: API_BASE,
  setToken: setAdminToken,
  login: (body: { password: string; username: string }) =>
    request<LoginResponse>("/admin/auth/login", {
      method: "POST",
      body: JSON.stringify(body)
    }),
  me: () => request<{ success: true; user: AdminUser }>("/admin/auth/me"),
  summary: () => request<AdminSummary>("/admin/summary"),
  apps: () => request<{ success: true; data: AdminApp[] }>("/admin/apps"),
  mappings: () => request<{ success: true; data: unknown[] }>("/admin/mappings"),
  categories: () => request<{ success: true; data: Array<{ id: string; name: string }> }>("/admin/categories"),
  groups: () => request<{ success: true; data: Array<{ id: string; name: string; categoryId: string }> }>("/admin/groups"),
  createApp: (body: Partial<AdminApp>) =>
    request<{ success: true; data: AdminApp }>("/admin/apps", {
      method: "POST",
      body: JSON.stringify(body)
    }),
  resolveDeeplink: (body: Record<string, string>) =>
    request<Record<string, unknown>>("/admin/deeplink/resolve-test", {
      method: "POST",
      body: JSON.stringify(body)
    }),
  trackTestEvent: () =>
    request<{ success: true; accepted: number }>("/admin/events/test", {
      method: "POST"
    })
};
