import { Body, Controller, Headers, Inject, Post } from "@nestjs/common";
import { InternalUnlockService } from "./internal-unlock.service";

@Controller("/api/v1/appbox/internal-unlock")
export class InternalUnlockController {
  constructor(@Inject(InternalUnlockService) private readonly unlock: InternalUnlockService) {}

  @Post("redeem")
  redeem(
    @Body() body: unknown,
    @Headers("cf-connecting-ip") cloudflareIP?: string,
    @Headers("x-forwarded-for") forwardedFor?: string
  ) {
    const requesterKey = cloudflareIP || forwardedFor?.split(",")[0]?.trim() || "unknown";
    return this.unlock.redeem(body, requesterKey);
  }
}
