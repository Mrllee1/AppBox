import { Body, Controller, Delete, Get, Inject, Param, Post, Put } from "@nestjs/common";
import { UseGuards } from "@nestjs/common";
import { AdminAuthGuard } from "../auth/admin-auth.guard";
import { AssetsService } from "../assets/assets.service";
import { DeeplinkService } from "../deeplink/deeplink.service";
import { PlatformConfigService } from "../platform-config/platform-config.service";
import { AdminService } from "./admin.service";
import { InternalUnlockService } from "../internal-unlock/internal-unlock.service";

@Controller("/admin")
@UseGuards(AdminAuthGuard)
export class AdminController {
  constructor(
    @Inject(AdminService) private readonly admin: AdminService,
    @Inject(AssetsService) private readonly assets: AssetsService,
    @Inject(DeeplinkService) private readonly deeplink: DeeplinkService,
    @Inject(PlatformConfigService) private readonly platformConfig: PlatformConfigService,
    @Inject(InternalUnlockService) private readonly internalUnlock: InternalUnlockService
  ) {}

  @Get("summary")
  summary() {
    return this.admin.summary();
  }

  @Get("apps")
  listApps() {
    return this.admin.listApps();
  }

  @Post("apps")
  createApp(@Body() body: unknown) {
    return this.admin.createApp(body);
  }

  @Put("apps/:id")
  updateApp(@Param("id") id: string, @Body() body: unknown) {
    return this.admin.updateApp(id, body);
  }

  @Delete("apps/:id")
  deleteApp(@Param("id") id: string) {
    return this.admin.deleteApp(id);
  }

  @Get("categories")
  listCategories() {
    return this.admin.listCategories();
  }

  @Post("categories")
  createCategory(@Body() body: unknown) {
    return this.admin.createCategory(body);
  }

  @Put("categories/:id")
  updateCategory(@Param("id") id: string, @Body() body: unknown) {
    return this.admin.updateCategory(id, body);
  }

  @Delete("categories/:id")
  deleteCategory(@Param("id") id: string) {
    return this.admin.deleteCategory(id);
  }

  @Get("groups")
  listGroups() {
    return this.admin.listGroups();
  }

  @Post("groups")
  createGroup(@Body() body: unknown) {
    return this.admin.createGroup(body);
  }

  @Put("groups/:id")
  updateGroup(@Param("id") id: string, @Body() body: unknown) {
    return this.admin.updateGroup(id, body);
  }

  @Delete("groups/:id")
  deleteGroup(@Param("id") id: string) {
    return this.admin.deleteGroup(id);
  }

  @Get("mappings")
  listMappings() {
    return this.admin.listMappings();
  }

  @Post("mappings")
  createMapping(@Body() body: unknown) {
    return this.admin.createMapping(body);
  }

  @Get("channels")
  listChannels() {
    return this.admin.listChannels();
  }

  @Post("deeplink/resolve-test")
  resolveDeeplinkForAdmin(@Body() body: unknown) {
    return this.deeplink.resolve(body);
  }

  @Post("assets/materialize-icons")
  materializeIcons() {
    return this.assets.materializeMissingAppIconAssets();
  }

  @Get("platform-config")
  getPlatformConfig() {
    return this.platformConfig.getAdminConfig();
  }

  @Put("platform-config")
  updatePlatformConfig(@Body() body: unknown) {
    return this.platformConfig.updateAdminConfig(body);
  }

  @Get("platform-config/preview")
  previewPlatformConfig() {
    return this.platformConfig.previewRemoteConfig();
  }

  @Post("platform-config/test-entrypoints")
  testPlatformEntrypoints() {
    return this.platformConfig.testEntrypoints();
  }

  @Post("platform-config/test-r2")
  testR2() {
    return this.platformConfig.testR2();
  }

  @Post("platform-config/publish")
  publishPlatformConfig() {
    return this.platformConfig.publishRemoteConfig();
  }

  @Get("internal-unlock/codes")
  listInternalUnlockCodes() {
    return this.internalUnlock.list();
  }

  @Post("internal-unlock/codes")
  issueInternalUnlockCode(@Body() body: unknown) {
    return this.internalUnlock.issue(body);
  }
}
