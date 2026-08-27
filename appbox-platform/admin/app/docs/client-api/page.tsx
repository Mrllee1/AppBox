import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "AppBox Client API Docs",
  description: "天涯盒子客户端公开接口对接文档"
};

const apiBase = "https://666999.lol";

const endpoints = [
  {
    method: "GET",
    path: "/health",
    auth: "无",
    crypto: "明文",
    purpose: "入口探活，用于客户端选择可用 API 域名。"
  },
  {
    method: "GET",
    path: "/api/v1/appbox/config",
    auth: "无",
    crypto: "响应加密",
    purpose: "返回 API 入口、能力开关和加密协议版本。"
  },
  {
    method: "GET",
    path: "/api/v1/appbox/version",
    auth: "无",
    crypto: "响应加密",
    purpose: "返回客户端最低版本和强制更新标记。"
  },
  {
    method: "GET",
    path: "/api/v1/appbox/catalog",
    auth: "无",
    crypto: "响应加密",
    purpose: "返回动态分类、分组、IPA/H5 应用列表和图标链接。"
  },
  {
    method: "POST",
    path: "/api/v1/appbox/deeplink/resolve",
    auth: "无",
    crypto: "请求/响应加密",
    purpose: "把外部落地页参数解析为指定 App 的打开动作。"
  },
  {
    method: "POST",
    path: "/api/v1/events/batch",
    auth: "无",
    crypto: "请求/响应加密",
    purpose: "批量上报安装、启动、下载、错误等客户端事件。"
  },
  {
    method: "GET",
    path: "/api/v1/appbox/assets/apps/:id/icon",
    auth: "无",
    crypto: "文件内容加密",
    purpose: "下载加密后的 App 图标 bytes，客户端本地解密后渲染。"
  }
];

const catalogFields = [
  ["v", "number", "目录版本号，用于客户端判断是否刷新缓存。"],
  ["ts", "string", "服务端生成时间，ISO 8601。"],
  ["c", "array", "分类列表。"],
  ["c[].id", "string", "分类 ID。"],
  ["c[].n", "string", "分类中文名称。"],
  ["c[].e", "string?", "分类英文名称。"],
  ["c[].g", "array", "当前分类下的分组列表。"],
  ["g[].id", "string", "分组 ID。"],
  ["g[].n", "string", "分组中文名称。"],
  ["g[].a", "array", "当前分组下启用的 App 列表。"],
  ["a[].id", "string", "内部 App ID。"],
  ["a[].n", "string", "App 展示名称。"],
  ["a[].t", "ipa | web", "App 类型。ipa 表示下载安装到盒子内运行，web 表示打开 H5。"],
  ["a[].icon", "string", "加密图标资源 URL。"],
  ["a[].url", "string?", "ipa 的下载 URL 或 web 的入口 URL。"],
  ["a[].b", "string?", "iOS bundle id，仅 ipa 类型常用。"]
];

const deeplinkFields = [
  ["app_id", "string", "外部系统的 App ID，例如落地页参数 app_id=3101。"],
  ["plat", "string", "平台。3 或 ios 表示 iOS，2 或 android 表示 Android。"],
  ["channel", "string?", "一级渠道。"],
  ["p_channel", "string?", "优先渠道。存在时优先用于匹配后台映射。"],
  ["dir", "string?", "落地页目录或投放路径，服务端可用于统计和追踪。"],
  ["jump_link", "string?", "外部跳转链接，按业务需要透传。"],
  ["client_version", "string?", "客户端版本。"]
];

const eventFields = [
  ["event", "string", "事件名，例如 catalog_loaded、app_download_start、app_launch_success。"],
  ["appId", "string?", "内部 App ID。"],
  ["externalAppId", "string?", "外部 App ID。"],
  ["channel", "string?", "渠道。"],
  ["platform", "string?", "平台。"],
  ["success", "boolean?", "动作是否成功。"],
  ["errorCode", "string?", "失败错误码。"],
  ["durationMs", "number?", "耗时，单位毫秒。"],
  ["deviceId", "string?", "设备匿名 ID。"],
  ["sessionId", "string?", "会话 ID。"],
  ["payload", "object?", "补充字段。"]
];

const flow = [
  "客户端从 CDN version.json 获取加密入口配置。",
  "本地解密入口配置，按权重或顺序探测 /health。",
  "选择可用 API Base 后请求 /api/v1/appbox/catalog。",
  "解密 catalog，按分类和分组渲染 App 列表。",
  "图标 URL 返回的是加密 bytes，客户端下载后本地解密显示。",
  "外部链接进入时调用 deeplink/resolve，得到 install_or_launch 或 open_web。",
  "下载、安装、启动、失败等动作批量上报到 /api/v1/events/batch。"
];

const envelopeExample = `{
  "v": 1,
  "k": "v1",
  "n": "base64url_nonce",
  "t": "base64url_auth_tag",
  "d": "base64url_ciphertext"
}`;

const catalogExample = `{
  "v": 12,
  "ts": "2026-08-11T10:00:00.000Z",
  "c": [
    {
      "id": "entertainment",
      "n": "娱乐系列",
      "g": [
        {
          "id": "chess",
          "n": "棋牌娱乐",
          "a": [
            {
              "id": "tianya_selected",
              "n": "天涯精选",
              "t": "ipa",
              "icon": "https://666999.lol/api/v1/appbox/assets/apps/tianya_selected/icon",
              "url": "https://cdn.example.com/app.ipa",
              "b": "app.example.tianya"
            }
          ]
        }
      ]
    }
  ]
}`;

const deeplinkRequest = `{
  "app_id": "3101",
  "plat": "3",
  "channel": "cHVtbXoAAAAAAAAAAAAAAEQCD0wV",
  "p_channel": "wc2dc",
  "dir": "/wc2dc/pummz/eddd93a1114e3d0f4439073127e51508",
  "jump_link": ""
}`;

const deeplinkResponse = `{
  "ok": 1,
  "act": "install_or_launch",
  "app": {
    "id": "tianya_selected",
    "n": "天涯精选",
    "t": "ipa",
    "icon": "https://666999.lol/api/v1/appbox/assets/apps/tianya_selected/icon",
    "url": "https://cdn.example.com/ty1.ipa",
    "b": "app.example.tianya"
  }
}`;

const eventsRequest = `{
  "events": [
    {
      "event": "app_launch_success",
      "appId": "tianya_selected",
      "externalAppId": "3101",
      "channel": "wc2dc",
      "platform": "ios",
      "success": true,
      "durationMs": 1280,
      "deviceId": "anonymous-device-id",
      "sessionId": "session-id",
      "payload": {
        "source": "deeplink"
      }
    }
  ]
}`;

const swiftGcmExample = `// 示例只展示协议形态，真实项目请使用本地配置的 32 字节 AES Key。
struct AppBoxEnvelope: Decodable {
    let v: Int
    let k: String
    let n: String
    let t: String
    let d: String
}

// 解密流程：
// 1. base64url decode n/t/d
// 2. AES-256-GCM open(ciphertext: d, nonce: n, tag: t)
// 3. UTF-8 JSON decode 明文业务对象`;

const iconDecryptExample = `// 图标接口返回 application/octet-stream。
// body 是 AES-256-CBC/PKCS7 密文，不是图片原文。
// 客户端流程：
// 1. GET icon URL
// 2. 使用 APPBOX_ASSET_AES_KEY + APPBOX_ASSET_AES_IV 解密
// 3. 用解密后的 PNG/JPEG/WebP bytes 创建 UIImage`;

export default function ClientApiDocsPage() {
  return (
    <main className="docs-shell">
      <section className="docs-hero">
        <div>
          <span className="docs-kicker">AppBox Client API</span>
          <h1>天涯盒子客户端公开接口对接文档</h1>
          <p>
            面向 iOS 客户端、落地页和 H5 对接方。本文只描述公开协议、字段和调用流程，不包含真实 AES Key、R2 Key 或后台凭证。
          </p>
        </div>
        <div className="docs-status-card">
          <span>Production API</span>
          <strong>{apiBase}</strong>
          <code>Updated 2026-08-11</code>
        </div>
      </section>

      <nav className="docs-nav glass">
        <a href="#quick-start">快速接入</a>
        <a href="#crypto">加密协议</a>
        <a href="#endpoints">接口清单</a>
        <a href="#catalog">目录接口</a>
        <a href="#deeplink">深链接解析</a>
        <a href="#events">事件统计</a>
        <a href="#assets">加密图标</a>
        <a href="#errors">错误处理</a>
      </nav>

      <section id="quick-start" className="docs-section glass">
        <div className="docs-section-head">
          <span>01</span>
          <div>
            <h2>快速接入</h2>
            <p>客户端只需要固定接口路径，API 域名可从 CDN 加密配置中获取，也可以在测试阶段直接使用生产域名。</p>
          </div>
        </div>
        <div className="docs-flow">
          {flow.map((item, index) => (
            <div className="docs-flow-item" key={item}>
              <b>{String(index + 1).padStart(2, "0")}</b>
              <span>{item}</span>
            </div>
          ))}
        </div>
      </section>

      <section id="crypto" className="docs-section glass">
        <div className="docs-section-head">
          <span>02</span>
          <div>
            <h2>统一加密协议</h2>
            <p>公开 JSON 响应统一使用 AES-256-GCM envelope。POST 业务 body 也使用相同 envelope，服务端解密后再处理。</p>
          </div>
        </div>
        <div className="docs-grid">
          <div>
            <h3>Envelope 字段</h3>
            <table className="docs-table">
              <tbody>
                <tr><td>v</td><td>协议版本，当前为 1。</td></tr>
                <tr><td>k</td><td>Key ID，当前默认 v1。</td></tr>
                <tr><td>n</td><td>AES-GCM nonce，base64url。</td></tr>
                <tr><td>t</td><td>AES-GCM auth tag，base64url。</td></tr>
                <tr><td>d</td><td>密文数据，base64url。</td></tr>
              </tbody>
            </table>
          </div>
          <CodeBlock title="Envelope 示例" code={envelopeExample} />
        </div>
      </section>

      <section id="endpoints" className="docs-section glass">
        <div className="docs-section-head">
          <span>03</span>
          <div>
            <h2>接口清单</h2>
            <p>后台管理接口不在本文范围内。以下接口均可由客户端直接调用。</p>
          </div>
        </div>
        <div className="docs-endpoint-list">
          {endpoints.map((item) => (
            <article className="docs-endpoint" key={`${item.method}-${item.path}`}>
              <div>
                <span className={`docs-method docs-method-${item.method.toLowerCase()}`}>{item.method}</span>
                <code>{item.path}</code>
              </div>
              <p>{item.purpose}</p>
              <small>鉴权：{item.auth} · 加密：{item.crypto}</small>
            </article>
          ))}
        </div>
      </section>

      <section id="catalog" className="docs-section glass">
        <div className="docs-section-head">
          <span>04</span>
          <div>
            <h2>目录接口</h2>
            <p>分类、分组和 App 列表全部由后台配置动态生成，客户端不要写死“工具系列、娱乐系列”等名称。</p>
          </div>
        </div>
        <EndpointTitle method="GET" path="/api/v1/appbox/catalog" />
        <FieldTable fields={catalogFields} />
        <CodeBlock title="解密后的 catalog 明文示例" code={catalogExample} />
      </section>

      <section id="deeplink" className="docs-section glass">
        <div className="docs-section-head">
          <span>05</span>
          <div>
            <h2>深链接解析</h2>
            <p>落地页或外部系统只需要传外部 app_id 和渠道参数，服务端会映射到内部 App。</p>
          </div>
        </div>
        <EndpointTitle method="POST" path="/api/v1/appbox/deeplink/resolve" />
        <FieldTable fields={deeplinkFields} />
        <div className="docs-grid">
          <CodeBlock title="加密前请求明文" code={deeplinkRequest} />
          <CodeBlock title="解密后响应明文" code={deeplinkResponse} />
        </div>
        <div className="docs-note">
          <b>动作说明</b>
          <span><code>install_or_launch</code> 表示 IPA App，客户端应进入下载、安装或启动流程。</span>
          <span><code>open_web</code> 表示 H5 App，客户端直接打开 <code>app.url</code>。</span>
        </div>
      </section>

      <section id="events" className="docs-section glass">
        <div className="docs-section-head">
          <span>06</span>
          <div>
            <h2>事件统计</h2>
            <p>建议客户端批量上报，失败时本地缓存并重试。事件字段保持可扩展，不影响主流程。</p>
          </div>
        </div>
        <EndpointTitle method="POST" path="/api/v1/events/batch" />
        <FieldTable fields={eventFields} />
        <CodeBlock title="加密前请求明文" code={eventsRequest} />
      </section>

      <section id="assets" className="docs-section glass">
        <div className="docs-section-head">
          <span>07</span>
          <div>
            <h2>加密图标资源</h2>
            <p>catalog 中的 icon 字段是资源 URL，但 URL 返回的不是原始图片，而是加密后的二进制内容。</p>
          </div>
        </div>
        <EndpointTitle method="GET" path="/api/v1/appbox/assets/apps/:id/icon" />
        <div className="docs-grid">
          <CodeBlock title="客户端解密流程" code={iconDecryptExample} />
          <div className="docs-note">
            <b>响应头</b>
            <span><code>Content-Type: application/octet-stream</code></span>
            <span><code>Cache-Control: public, max-age=31536000, immutable</code></span>
            <span>解密后的 bytes 才是 PNG、JPEG 或 WebP 图片。</span>
          </div>
        </div>
      </section>

      <section id="examples" className="docs-section glass">
        <div className="docs-section-head">
          <span>08</span>
          <div>
            <h2>客户端示例</h2>
            <p>以下是协议级示例，真实密钥应由客户端配置或安全配置模块提供，不应写在对外文档里。</p>
          </div>
        </div>
        <div className="docs-grid">
          <CodeBlock title="Swift AES-GCM 解密轮廓" code={swiftGcmExample} />
          <CodeBlock
            title="Health 探活"
            code={`curl -fsS ${apiBase}/health`}
          />
        </div>
      </section>

      <section id="errors" className="docs-section glass">
        <div className="docs-section-head">
          <span>09</span>
          <div>
            <h2>错误处理</h2>
            <p>非 2xx 响应按 HTTP 状态处理。客户端应记录 error_code，并上报到 events/batch。</p>
          </div>
        </div>
        <table className="docs-table">
          <thead>
            <tr>
              <th>错误码</th>
              <th>含义</th>
              <th>建议处理</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>ENCRYPTED_BODY_REQUIRED</td>
              <td>POST body 未使用 envelope。</td>
              <td>检查请求加密流程。</td>
            </tr>
            <tr>
              <td>UNKNOWN_AES_KEY</td>
              <td>Key ID 不匹配。</td>
              <td>刷新 CDN 配置或更新客户端密钥版本。</td>
            </tr>
            <tr>
              <td>DECRYPT_FAILED</td>
              <td>密文无法解密或 tag 校验失败。</td>
              <td>检查 AES Key、nonce、tag、base64url 编码。</td>
            </tr>
            <tr>
              <td>APP_MAPPING_NOT_FOUND</td>
              <td>外部 app_id 没有匹配到启用映射。</td>
              <td>检查后台深链映射配置。</td>
            </tr>
            <tr>
              <td>APP_NOT_AVAILABLE</td>
              <td>映射 App 已禁用或不存在。</td>
              <td>检查后台 App 状态。</td>
            </tr>
          </tbody>
        </table>
      </section>
    </main>
  );
}

function EndpointTitle({ method, path }: { method: string; path: string }) {
  return (
    <div className="docs-endpoint-title">
      <span className={`docs-method docs-method-${method.toLowerCase()}`}>{method}</span>
      <code>{path}</code>
    </div>
  );
}

function FieldTable({ fields }: { fields: string[][] }) {
  return (
    <table className="docs-table">
      <thead>
        <tr>
          <th>字段</th>
          <th>类型</th>
          <th>说明</th>
        </tr>
      </thead>
      <tbody>
        {fields.map(([field, type, description]) => (
          <tr key={field}>
            <td><code>{field}</code></td>
            <td>{type}</td>
            <td>{description}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

function CodeBlock({ title, code }: { title: string; code: string }) {
  return (
    <div className="docs-code">
      <div>{title}</div>
      <pre><code>{code}</code></pre>
    </div>
  );
}
