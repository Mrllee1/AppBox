"use client";

import { useEffect, useMemo } from "react";
import { useSearchParams } from "next/navigation";

export function LandingRedirect() {
  const searchParams = useSearchParams();
  const deepLink = useMemo(() => buildNativeDeepLink(searchParams), [searchParams]);
  const canOpen = deepLink !== "appbox://native";

  useEffect(() => {
    if (!canOpen) return;
    const timer = window.setTimeout(() => {
      window.location.href = deepLink;
    }, 260);
    return () => window.clearTimeout(timer);
  }, [canOpen, deepLink]);

  return (
    <main className="landing-shell">
      <section className="landing-card glass">
        <div className="brand-mark">盒</div>
        <h1>正在打开天涯盒子</h1>
        <p>如果没有自动跳转，请点击下方按钮继续。</p>
        <a className={`landing-button${canOpen ? "" : " disabled"}`} href={canOpen ? deepLink : undefined}>
          打开应用
        </a>
      </section>
    </main>
  );
}

function buildNativeDeepLink(params: URLSearchParams) {
  const nativeParams = new URLSearchParams();
  copyParam(params, nativeParams, "data", "data");
  copyFirstParam(params, nativeParams, ["app_id", "appId"], "app_id");
  copyParam(params, nativeParams, "plat", "plat");
  copyFirstParam(params, nativeParams, ["channel", "p_channel"], "channel");
  copyFirstParam(params, nativeParams, ["appNo", "app_no"], "appNo");
  copyParam(params, nativeParams, "referrer", "referrer");
  return `appbox://native${nativeParams.toString() ? `?${nativeParams.toString()}` : ""}`;
}

function copyParam(source: URLSearchParams, target: URLSearchParams, from: string, to: string) {
  const value = source.get(from);
  if (value) target.set(to, value);
}

function copyFirstParam(source: URLSearchParams, target: URLSearchParams, names: string[], to: string) {
  const value = names.map((name) => source.get(name)).find(Boolean);
  if (value) target.set(to, value);
}
