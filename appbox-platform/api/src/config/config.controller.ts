import { Controller, Get, Inject } from "@nestjs/common";
import { ClientCryptoService } from "../client-crypto/client-crypto.service";

@Controller()
export class ConfigController {
  constructor(@Inject(ClientCryptoService) private readonly crypto: ClientCryptoService) {}

  @Get("/health")
  health() {
    return {
      ok: true,
      service: "appbox-api",
      time: new Date().toISOString()
    };
  }

  @Get("/api/v1/appbox/config")
  config() {
    const apiBase = process.env.PUBLIC_API_BASE_URL || "http://127.0.0.1:39110";
    return this.crypto.encryptJson({
      v: 1,
      api: [apiBase],
      link: [process.env.PUBLIC_LINK_BASE_URL || "http://127.0.0.1:39110"],
      enc: "A256GCM",
      f: ["deeplink", "events", "assets", "h5", "ipa"]
    });
  }

  @Get("/api/v1/appbox/version")
  version() {
    return this.crypto.encryptJson({
      v: 1,
      min: "1.0.0",
      force: 0
    });
  }
}
