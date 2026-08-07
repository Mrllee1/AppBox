import { Body, Controller, Get, Inject, Post } from "@nestjs/common";
import { UseGuards } from "@nestjs/common";
import { AdminAuthGuard } from "../auth/admin-auth.guard";
import { ClientCryptoService } from "../client-crypto/client-crypto.service";
import { EventsService } from "./events.service";

@Controller()
export class EventsController {
  constructor(
    @Inject(EventsService) private readonly events: EventsService,
    @Inject(ClientCryptoService) private readonly crypto: ClientCryptoService
  ) {}

  @Post("/api/v1/events/batch")
  async ingest(@Body() body: unknown) {
    const result = await this.events.ingest(this.crypto.decryptBody(body));
    return this.crypto.encryptJson({ ok: 1, n: result.accepted });
  }

  @UseGuards(AdminAuthGuard)
  @Post("/admin/events/test")
  ingestAdminTest() {
    return this.events.ingest({
      events: [
        {
          event: "admin_test_event",
          platform: "admin",
          success: true,
          payload: { source: "admin_console" }
        }
      ]
    });
  }

  @UseGuards(AdminAuthGuard)
  @Get("/admin/events/summary")
  summary() {
    return this.events.summary();
  }
}
