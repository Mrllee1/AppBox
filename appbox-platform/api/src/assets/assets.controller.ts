import { Controller, Get, Inject, Param, Res } from "@nestjs/common";
import { AssetsService } from "./assets.service";

@Controller("/api/v1/appbox/assets")
export class AssetsController {
  constructor(@Inject(AssetsService) private readonly assets: AssetsService) {}

  @Get("apps/:id/icon")
  async appIcon(@Param("id") id: string, @Res() response: any) {
    const file = await this.assets.getAppIconFile(id);
    response.set({
      "Cache-Control": "public, max-age=31536000, immutable",
      "Content-Type": "application/octet-stream",
      "X-Content-Type-Options": "nosniff"
    });
    response.send(file);
  }
}
