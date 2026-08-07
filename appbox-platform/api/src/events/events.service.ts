import { Inject, Injectable } from "@nestjs/common";
import { z } from "zod";
import { randomUUID } from "node:crypto";
import { FileDataStore } from "../common/file-data-store";
import { AppBoxEventLog } from "../common/types";

const EventSchema = z.object({
  event: z.string().min(1),
  app_id: z.string().optional(),
  external_app_id: z.string().optional(),
  channel: z.string().optional(),
  platform: z.string().optional(),
  success: z.boolean().optional(),
  error_code: z.string().optional(),
  duration_ms: z.number().int().nonnegative().optional(),
  device_id: z.string().optional(),
  session_id: z.string().optional(),
  payload: z.record(z.string(), z.unknown()).optional()
});

const BatchSchema = z.object({
  events: z.array(EventSchema).min(1).max(100)
});

@Injectable()
export class EventsService {
  constructor(@Inject(FileDataStore) private readonly store: FileDataStore) {}

  async ingest(rawBody: unknown) {
    const body = BatchSchema.parse(rawBody);
    const now = new Date().toISOString();
    const logs: AppBoxEventLog[] = body.events.map((event) => ({
      id: randomUUID(),
      event: event.event,
      appId: event.app_id,
      externalAppId: event.external_app_id,
      channel: event.channel,
      platform: event.platform,
      success: event.success,
      errorCode: event.error_code,
      durationMs: event.duration_ms,
      deviceId: event.device_id,
      sessionId: event.session_id,
      payload: event.payload,
      createdAt: now
    }));

    await this.store.update((data) => {
      data.events.push(...logs);
    });

    return {
      success: true,
      accepted: logs.length
    };
  }

  async summary() {
    const data = await this.store.read();
    const today = new Date().toISOString().slice(0, 10);
    const todayEvents = data.events.filter((event) => event.createdAt.startsWith(today));
    const count = (name: string) => todayEvents.filter((event) => event.event === name).length;

    return {
      total_events: data.events.length,
      today_events: todayEvents.length,
      deeplink_received: count("deeplink_received"),
      deeplink_resolved: count("deeplink_resolved"),
      download_start: count("download_start"),
      download_success: count("download_success"),
      launch_success: count("launch_success"),
      launch_failed: count("launch_failed")
    };
  }
}
