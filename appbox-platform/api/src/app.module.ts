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
import { CredentialCryptoService } from "./platform-config/credential-crypto.service";
import { PlatformConfigService } from "./platform-config/platform-config.service";
import { R2StorageService } from "./platform-config/r2-storage.service";
import { InternalUnlockController } from "./internal-unlock/internal-unlock.controller";
import { InternalUnlockService } from "./internal-unlock/internal-unlock.service";

@Module({
  controllers: [
    AdminController,
    AssetsController,
    AuthController,
    CatalogController,
    ConfigController,
    DeeplinkController,
    EventsController,
    InternalUnlockController
  ],
  providers: [
    AdminAuthGuard,
    AssetCryptoService,
    AssetsService,
    AuthService,
    ClientCryptoService,
    CredentialCryptoService,
    FileDataStore,
    AdminService,
    CatalogService,
    DeeplinkService,
    EventsService,
    PlatformConfigService,
    R2StorageService,
    InternalUnlockService
  ]
})
export class AppModule {}
