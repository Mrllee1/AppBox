import assert from "node:assert/strict";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawn } from "node:child_process";
import { createServer } from "node:net";
import { createCipheriv, createDecipheriv, createHash, randomBytes } from "node:crypto";
import test from "node:test";

const root = new URL("..", import.meta.url).pathname;
const clientKey = Buffer.from("0123456789abcdef0123456789abcdef");
const assetKey = createHash("sha256").update("appbox-asset-image-key-v1").digest();
const assetIV = createHash("sha256").update("appbox-asset-image-iv-v1").digest().subarray(0, 16);

async function getFreePort() {
  return await new Promise((resolve, reject) => {
    const server = createServer();
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      server.close(() => {
        if (address && typeof address === "object") {
          resolve(address.port);
        } else {
          reject(new Error("Unable to allocate free local port"));
        }
      });
    });
  });
}

async function waitForHealth(baseUrl, timeoutMs = 15000) {
  const started = Date.now();
  let lastError;
  while (Date.now() - started < timeoutMs) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 800);
    try {
      const response = await fetch(`${baseUrl}/health`, { signal: controller.signal });
      if (response.ok) return;
    } catch (error) {
      lastError = error;
    } finally {
      clearTimeout(timer);
    }
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw lastError || new Error("API did not become healthy");
}

async function request(baseUrl, path, init) {
  const response = await fetch(`${baseUrl}${path}`, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(init?.headers || {})
    }
  });
  const text = await response.text();
  const json = text ? JSON.parse(text) : null;
  if (!response.ok) {
    throw new Error(`${response.status} ${response.statusText}: ${text}`);
  }
  return json;
}

async function binaryRequest(baseUrl, path) {
  const response = await fetch(`${baseUrl}${path}`);
  if (!response.ok) {
    throw new Error(`${response.status} ${response.statusText}: ${await response.text()}`);
  }
  return {
    contentType: response.headers.get("content-type") || "",
    format: response.headers.get("x-appbox-asset-format") || "",
    data: Buffer.from(await response.arrayBuffer())
  };
}

function encryptJson(value) {
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", clientKey, iv);
  const plain = Buffer.from(JSON.stringify(value), "utf8");
  const encrypted = Buffer.concat([cipher.update(plain), cipher.final()]);
  return {
    v: 1,
    k: "v1",
    n: iv.toString("base64url"),
    t: cipher.getAuthTag().toString("base64url"),
    d: encrypted.toString("base64url")
  };
}

function decryptEnvelope(envelope) {
  assert.deepEqual(Object.keys(envelope).sort(), ["d", "k", "n", "t", "v"]);
  assert.equal(envelope.v, 1);
  assert.equal(envelope.k, "v1");
  const decipher = createDecipheriv("aes-256-gcm", clientKey, Buffer.from(envelope.n, "base64url"));
  decipher.setAuthTag(Buffer.from(envelope.t, "base64url"));
  const plain = Buffer.concat([
    decipher.update(Buffer.from(envelope.d, "base64url")),
    decipher.final()
  ]);
  return plain;
}

function decryptJson(envelope) {
  return JSON.parse(decryptEnvelope(envelope).toString("utf8"));
}

function decryptPackedRemoteConfig(encrypted) {
  const packed = Buffer.from(encrypted, "base64");
  const iv = packed.subarray(0, 12);
  const tag = packed.subarray(packed.length - 16);
  const cipherText = packed.subarray(12, packed.length - 16);
  const decipher = createDecipheriv("aes-256-gcm", clientKey, iv);
  decipher.setAuthTag(tag);
  return JSON.parse(Buffer.concat([
    decipher.update(cipherText),
    decipher.final()
  ]).toString("utf8"));
}

function decryptAssetFile(file) {
  const decipher = createDecipheriv("aes-256-cbc", assetKey, assetIV);
  return Buffer.concat([decipher.update(file), decipher.final()]);
}

function isLikelyImage(data) {
  if (data.length < 4) return false;
  if (data[0] === 0xff && data[1] === 0xd8 && data[2] === 0xff) return true;
  if (data[0] === 0x89 && data[1] === 0x50 && data[2] === 0x4e && data[3] === 0x47) return true;
  if (data[0] === 0x47 && data[1] === 0x49 && data[2] === 0x46) return true;
  return data.length >= 12 &&
    data[0] === 0x52 &&
    data[1] === 0x49 &&
    data[2] === 0x46 &&
    data[3] === 0x46 &&
    data[8] === 0x57 &&
    data[9] === 0x45 &&
    data[10] === 0x42 &&
    data[11] === 0x50;
}

test("AppBox API, deeplink, events, and admin CRUD", async (t) => {
  const port = await getFreePort();
  const baseUrl = `http://127.0.0.1:${port}`;
  const tempDir = await mkdtemp(join(tmpdir(), "appbox-platform-"));
  const dataFile = join(tempDir, "store.json");
  const child = spawn("npm", ["run", "dev:api"], {
    cwd: root,
    env: {
      ...process.env,
      APPBOX_API_PORT: String(port),
      APPBOX_DATA_FILE: dataFile,
      APPBOX_ADMIN_PASSWORD: "test-password",
      APPBOX_ADMIN_SESSION_SECRET: "test-session-secret",
      APPBOX_ADMIN_USERNAME: "admin",
      APPBOX_CLIENT_AES_KEY: clientKey.toString("base64"),
      APPBOX_CLIENT_AES_KID: "v1",
      APPBOX_CLIENT_ENCRYPTION_REQUIRED: "true",
      APPBOX_ASSET_AES_KEY: assetKey.toString("base64"),
      APPBOX_ASSET_AES_IV: assetIV.toString("base64"),
      APPBOX_ALLOWED_ORIGINS: "http://127.0.0.1:39111"
    },
    stdio: ["ignore", "pipe", "pipe"]
  });

  let output = "";
  child.stdout.on("data", (chunk) => {
    output += chunk.toString();
  });
  child.stderr.on("data", (chunk) => {
    output += chunk.toString();
  });

  t.after(async () => {
    child.kill("SIGTERM");
    await new Promise((resolve) => child.once("exit", resolve));
    await rm(tempDir, { recursive: true, force: true });
  });

  await waitForHealth(baseUrl);
  assert.match(output, /AppBox API listening/);

  const health = await request(baseUrl, "/health");
  assert.equal(health.ok, true);

  const remoteConfig = decryptJson(await request(baseUrl, "/api/v1/appbox/config"));
  assert.deepEqual(Object.keys(remoteConfig).sort(), ["api", "enc", "f", "link", "v"]);
  assert.equal(remoteConfig.enc, "A256GCM");
  assert.ok(remoteConfig.f.includes("assets"));
  assert.ok(remoteConfig.api.length >= 1);

  const catalog = decryptJson(await request(baseUrl, "/api/v1/appbox/catalog"));
  assert.equal(catalog.v, 1);
  assert.ok(catalog.c.length >= 1);
  const flatApps = catalog.c.flatMap((category) =>
    category.g.flatMap((group) => group.a)
  );
  assert.equal(flatApps.some((app) => app.id === "appbox_web_demo"), false);
  const tianyaApp = flatApps.find((app) => app.id === "tianya_selected");
  assert.ok(tianyaApp);
  assert.deepEqual(Object.keys(tianyaApp).sort(), ["b", "icon", "id", "n", "t", "url"]);
  assert.equal(tianyaApp.b, "app.nqyqstm6mu.tianya");
  assert.match(tianyaApp.icon, /\/api\/v1\/appbox\/assets\/apps\/tianya_selected\/icon$/);
  assert.equal(tianyaApp.icon.includes("r2.dev"), false);

  const iconFile = await binaryRequest(baseUrl, "/api/v1/appbox/assets/apps/tianya_selected/icon");
  assert.match(iconFile.contentType, /^application\/octet-stream/);
  assert.equal(iconFile.format, "");
  assert.equal(isLikelyImage(iconFile.data), false);
  assert.ok(isLikelyImage(decryptAssetFile(iconFile.data)));

  await assert.rejects(
    () =>
      request(baseUrl, "/api/v1/appbox/deeplink/resolve", {
        method: "POST",
        body: JSON.stringify({ app_id: "3101" })
      }),
    /400 Bad Request/
  );

  const deeplink = decryptJson(await request(baseUrl, "/api/v1/appbox/deeplink/resolve", {
    method: "POST",
    body: JSON.stringify(encryptJson({
      app_id: "3101",
      channel: "cHVtbXoAAAAAAAAAAAAAAEQCD0wV",
      p_channel: "wc2dc",
      dir: "/wc2dc/pummz/eddd93a1114e3d0f4439073127e51508",
      plat: "3"
    }))
  }));
  assert.equal(deeplink.ok, 1);
  assert.equal(deeplink.act, "install_or_launch");
  assert.equal(deeplink.app.id, "tianya_selected");
  assert.deepEqual(Object.keys(deeplink.app).sort(), ["b", "icon", "id", "n", "t", "url"]);
  assert.match(deeplink.app.icon, /\/api\/v1\/appbox\/assets\/apps\/tianya_selected\/icon$/);

  const events = decryptJson(await request(baseUrl, "/api/v1/events/batch", {
    method: "POST",
    body: JSON.stringify(encryptJson({
      events: [
        {
          event: "deeplink_received",
          external_app_id: "3101",
          channel: "wc2dc",
          platform: "ios",
          success: true
        },
        {
          event: "launch_success",
          app_id: "tianya_selected",
          channel: "wc2dc",
          platform: "ios",
          success: true,
          duration_ms: 138
        }
      ]
    }))
  }));
  assert.equal(events.ok, 1);
  assert.equal(events.n, 2);

  await assert.rejects(
    () => request(baseUrl, "/admin/summary"),
    /401 Unauthorized/
  );

  const login = await request(baseUrl, "/admin/auth/login", {
    method: "POST",
    body: JSON.stringify({
      username: "admin",
      password: "test-password"
    })
  });
  assert.equal(login.success, true);
  assert.equal(login.user.username, "admin");
  assert.ok(login.token);
  const authHeaders = { Authorization: `Bearer ${login.token}` };

  const me = await request(baseUrl, "/admin/auth/me", {
    headers: authHeaders
  });
  assert.equal(me.user.username, "admin");

  const summary = await request(baseUrl, "/admin/summary", {
    headers: authHeaders
  });
  assert.equal(summary.enabled_apps, 1);
  assert.equal(summary.events.total_events, 2);

  const adminDeeplink = await request(baseUrl, "/admin/deeplink/resolve-test", {
    method: "POST",
    headers: authHeaders,
    body: JSON.stringify({
      app_id: "3101",
      p_channel: "wc2dc",
      plat: "3"
    })
  });
  assert.equal(adminDeeplink.app.id, "tianya_selected");

  const adminEvent = await request(baseUrl, "/admin/events/test", {
    method: "POST",
    headers: authHeaders
  });
  assert.equal(adminEvent.accepted, 1);

  const platformConfig = await request(baseUrl, "/admin/platform-config", {
    headers: authHeaders
  });
  assert.equal(platformConfig.success, true);
  assert.equal(platformConfig.data.github.owner, "yasuo185239-beep");
  assert.equal(platformConfig.data.github.repo, "appbox-config");
  assert.equal(platformConfig.data.github.tokenConfigured, false);
  assert.ok(platformConfig.cdnUrls.some((url) => url.includes("cdn.jsdelivr.net")));

  const savedPlatformConfig = await request(baseUrl, "/admin/platform-config", {
    method: "PUT",
    headers: authHeaders,
    body: JSON.stringify({
      apiEntrypoints: [
        {
          baseUrl,
          enabled: true,
          weight: 100
        },
        {
          baseUrl: `${baseUrl}/`,
          enabled: true,
          weight: 50
        }
      ],
      github: {
        owner: "yasuo185239-beep",
        repo: "appbox-config",
        branch: "main",
        filePath: "version.json"
      },
      r2: {
        accountId: "",
        bucket: "",
        endpoint: "",
        publicBaseUrl: "",
        accessKeyId: "",
        secretAccessKey: "",
        apiToken: ""
      }
    })
  });
  assert.equal(savedPlatformConfig.success, true);
  assert.equal(savedPlatformConfig.data.apiEntrypoints.length, 1);
  assert.equal(savedPlatformConfig.data.apiEntrypoints[0].baseUrl, baseUrl);

  const preview = await request(baseUrl, "/admin/platform-config/preview", {
    headers: authHeaders
  });
  assert.equal(preview.success, true);
  assert.deepEqual(Object.keys(preview.data.plain).sort(), ["api", "updatedAt", "v"]);
  assert.deepEqual(preview.data.plain.api, [baseUrl]);
  assert.deepEqual(decryptPackedRemoteConfig(preview.data.encrypted).api, [baseUrl]);

  const entrypointTest = await request(baseUrl, "/admin/platform-config/test-entrypoints", {
    method: "POST",
    headers: authHeaders
  });
  assert.equal(entrypointTest.success, true);
  assert.equal(entrypointTest.data.length, 1);
  assert.equal(entrypointTest.data[0].ok, true);
  assert.equal(entrypointTest.data[0].status, 200);

  const r2Test = await request(baseUrl, "/admin/platform-config/test-r2", {
    method: "POST",
    headers: authHeaders
  });
  assert.equal(r2Test.success, false);
  assert.equal(r2Test.message, "R2 is not configured");

  await assert.rejects(
    () =>
      request(baseUrl, "/admin/platform-config/publish", {
        method: "POST",
        headers: authHeaders
      }),
    /400 Bad Request/
  );

  const materialized = await request(baseUrl, "/admin/assets/materialize-icons", {
    method: "POST",
    headers: authHeaders
  });
  assert.equal(materialized.success, true);

  const createdCategory = await request(baseUrl, "/admin/categories", {
    method: "POST",
    headers: authHeaders,
    body: JSON.stringify({
      id: "qa_category",
      name: "QA 分类",
      englishName: "QA Category",
      sort: 90,
      enabled: true
    })
  });
  assert.equal(createdCategory.success, true);
  assert.equal(createdCategory.data.id, "qa_category");

  const updatedCategory = await request(baseUrl, "/admin/categories/qa_category", {
    method: "PUT",
    headers: authHeaders,
    body: JSON.stringify({
      name: "QA 分类更新",
      englishName: "QA Category Updated",
      sort: 91,
      enabled: true
    })
  });
  assert.equal(updatedCategory.data.name, "QA 分类更新");
  assert.equal(updatedCategory.data.sort, 91);

  const createdGroup = await request(baseUrl, "/admin/groups", {
    method: "POST",
    headers: authHeaders,
    body: JSON.stringify({
      id: "qa_group",
      categoryId: "qa_category",
      name: "QA 分组",
      englishName: "QA Group",
      sort: 10,
      enabled: true
    })
  });
  assert.equal(createdGroup.success, true);
  assert.equal(createdGroup.data.categoryId, "qa_category");

  const updatedGroup = await request(baseUrl, "/admin/groups/qa_group", {
    method: "PUT",
    headers: authHeaders,
    body: JSON.stringify({
      categoryId: "qa_category",
      name: "QA 分组更新",
      englishName: "QA Group Updated",
      sort: 11,
      enabled: true
    })
  });
  assert.equal(updatedGroup.data.name, "QA 分组更新");
  assert.equal(updatedGroup.data.sort, 11);

  const created = await request(baseUrl, "/admin/apps", {
    method: "POST",
    headers: authHeaders,
    body: JSON.stringify({
      id: "qa_web_app",
      name: "QA Web",
      type: "web",
      categoryId: "qa_category",
      groupId: "qa_group",
      iconUrl: "https://example.com/icon.png",
      entryUrl: "https://example.com/app",
      version: "1.0.1",
      sort: 30,
      enabled: true,
      recommended: false
    })
  });
  assert.equal(created.success, true);
  assert.equal(created.data.id, "qa_web_app");

  const updated = await request(baseUrl, "/admin/apps/qa_web_app", {
    method: "PUT",
    headers: authHeaders,
    body: JSON.stringify({
      name: "QA Web Updated",
      type: "web",
      categoryId: "qa_category",
      groupId: "qa_group",
      iconUrl: "https://example.com/icon.png",
      entryUrl: "https://example.com/app",
      sort: 31,
      enabled: true,
      recommended: true
    })
  });
  assert.equal(updated.data.name, "QA Web Updated");
  assert.equal(updated.data.recommended, true);

  const apps = await request(baseUrl, "/admin/apps", {
    headers: authHeaders
  });
  assert.ok(apps.data.some((app) => app.id === "qa_web_app"));

  const deleted = await request(baseUrl, "/admin/apps/qa_web_app", {
    method: "DELETE",
    headers: authHeaders
  });
  assert.equal(deleted.success, true);

  const deletedGroup = await request(baseUrl, "/admin/groups/qa_group", {
    method: "DELETE",
    headers: authHeaders
  });
  assert.equal(deletedGroup.success, true);

  const deletedCategory = await request(baseUrl, "/admin/categories/qa_category", {
    method: "DELETE",
    headers: authHeaders
  });
  assert.equal(deletedCategory.success, true);

  const catalogAfterDelete = decryptJson(await request(baseUrl, "/api/v1/appbox/catalog"));
  const visibleAfterDelete = catalogAfterDelete.c.flatMap((category) =>
    category.g.flatMap((group) => group.a)
  );
  assert.equal(visibleAfterDelete.some((app) => app.id === "qa_web_app"), false);
});
