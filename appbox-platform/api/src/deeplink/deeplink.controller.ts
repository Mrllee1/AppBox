import { Body, Controller, Inject, Post } from "@nestjs/common";
import { ClientCryptoService } from "../client-crypto/client-crypto.service";
import { DeeplinkService } from "./deeplink.service";

@Controller("/api/v1/appbox/deeplink")
export class DeeplinkController {
  constructor(
    @Inject(DeeplinkService) private readonly deeplink: DeeplinkService,
    @Inject(ClientCryptoService) private readonly crypto: ClientCryptoService
  ) {}

  @Post("resolve")
  async resolve(@Body() body: unknown) {
    return this.crypto.encryptJson(await this.deeplink.resolve(this.crypto.decryptBody(body)));
  }
}
