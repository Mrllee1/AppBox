import { Suspense } from "react";
import { LandingRedirect } from "./LandingRedirect";

export default function LandingPage() {
  return (
    <Suspense fallback={<LandingFallback />}>
      <LandingRedirect />
    </Suspense>
  );
}

function LandingFallback() {
  return (
    <main className="landing-shell">
      <section className="landing-card glass">
        <div className="brand-mark">盒</div>
        <h1>正在准备跳转</h1>
        <p>请稍候。</p>
      </section>
    </main>
  );
}
