import { Controller, Get, Inject } from "@nestjs/common";
import { ClientCryptoService } from "../client-crypto/client-crypto.service";
import { CatalogService } from "./catalog.service";

@Controller("/api/v1/appbox")
export class CatalogController {
  constructor(
    @Inject(CatalogService) private readonly catalog: CatalogService,
    @Inject(ClientCryptoService) private readonly crypto: ClientCryptoService
  ) {}

  @Get("catalog")
  async getCatalog() {
    return this.crypto.encryptJson(await this.catalog.getCatalog());
  }
}
