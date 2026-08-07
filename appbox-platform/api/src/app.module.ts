import { Module } from "@nestjs/common";
import { AdminAuthGuard } from "./auth/admin-auth.guard";
import { AuthController } from "./auth/auth.controller";
import { AuthService } from "./auth/auth.service";
import { AssetsController } from "./assets/assets.controller";
import { AssetCryptoService } from "./assets/asset-crypto.service";
import { AssetsService } from "./assets/assets.service";
import { ClientCryptoService } from "./client-crypto/client-crypto.service";
import { FileDataStore } from "./common/file-data-store";
import { AdminController } from "./admin/admin.controller";
import { AdminService } from "./admin/admin.service";
import { CatalogController } from "./catalog/catalog.controller";
import { CatalogService } from "./catalog/catalog.service";
import { ConfigController } from "./config/config.controller";
import { DeeplinkController } from "./deeplink/deeplink.controller";
import { DeeplinkService } from "./deeplink/deeplink.service";
import { EventsController } from "./events/events.controller";
import { EventsService } from "./events/events.service";

@Module({
  controllers: [
    AdminController,
    AssetsController,
    AuthController,
    CatalogController,
    ConfigController,
    DeeplinkController,
    EventsController
  ],
  providers: [
    AdminAuthGuard,
    AssetCryptoService,
    AssetsService,
    AuthService,
    ClientCryptoService,
    FileDataStore,
    AdminService,
    CatalogService,
    DeeplinkService,
    EventsService
  ]
})
export class AppModule {}
