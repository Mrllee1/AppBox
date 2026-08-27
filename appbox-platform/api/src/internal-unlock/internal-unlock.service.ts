import {
  BadRequestException,
  HttpException,
  HttpStatus,
  Inject,
  Injectable,
  NotFoundException,
  UnauthorizedException
} from "@nestjs/common";
import { createHmac, createHash, randomBytes, randomUUID, timingSafeEqual } from "node:crypto";
import { z } from "zod";
import { FileDataStore } from "../common/file-data-store";
import { AppBoxInternalUnlockCode } from "../common/types";

const issueSchema = z.object({
  ttlMinutes: z.number().int().min(1).max(60).default(10),
  customCode: z.string().trim().min(6).max(32).regex(/^[A-Za-z0-9 -]+$/).optional()
}).strict();

const redeemSchema = z.object({
  code: z.string().min(6).max(32),
  installId: z.string().uuid(),
  appVersion: z.string().min(1).max(32),
  appBuild: z.string().min(1).max(32)
}).strict();

interface AttemptBucket {
  count: number;
  resetAt: number;
}

@Injectable()
export class InternalUnlockService {
  private static readonly alphabet = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
  private readonly attempts = new Map<string, AttemptBucket>();
  private readonly enabled = process.env.APPBOX_INTERNAL_UNLOCK_ENABLED === "true";
  private readonly signingSecret =
    process.env.APPBOX_INTERNAL_UNLOCK_SECRET ||
    process.env.APPBOX_ADMIN_SESSION_SECRET ||
    "local-development-internal-unlock-secret";
  private readonly fixedCode = this.normalizeCode(
    process.env.APPBOX_INTERNAL_UNLOCK_FIXED_CODE || ""
  );

  constructor(@Inject(FileDataStore) private readonly store: FileDataStore) {}

  async issue(rawBody: unknown) {
    this.assertEnabled();
    const { ttlMinutes, customCode } = issueSchema.parse(rawBody ?? {});
    const compactCode = customCode ? this.normalizeCode(customCode) : this.generateCode(10);
    if (compactCode.length < 6 || compactCode.length > 32) {
      throw new BadRequestException("自定义指令应为 6 至 32 位字母或数字");
    }
    const now = new Date();
    const record: AppBoxInternalUnlockCode = {
      id: randomUUID(),
      codeHash: this.hashCode(compactCode),
      createdAt: now.toISOString(),
      expiresAt: new Date(now.getTime() + ttlMinutes * 60_000).toISOString()
    };

    await this.store.update((data) => {
      const cutoff = now.getTime() - 24 * 60 * 60_000;
      data.internalUnlockCodes = (data.internalUnlockCodes ?? []).filter((item) => {
        const terminalTime = item.consumedAt ?? item.expiresAt;
        return new Date(terminalTime).getTime() >= cutoff;
      });
      const duplicateActiveCode = data.internalUnlockCodes.some((item) =>
        this.hashesMatch(item.codeHash, record.codeHash) &&
        !item.consumedAt &&
        new Date(item.expiresAt).getTime() > now.getTime()
      );
      if (duplicateActiveCode) {
        throw new BadRequestException("该自定义指令仍在有效期内");
      }
      data.internalUnlockCodes.push(record);
    });

    return {
      success: true,
      code: customCode ? compactCode : this.formatCode(compactCode),
      expiresAt: record.expiresAt
    };
  }

  async list() {
    this.assertEnabled();
    const data = await this.store.read();
    const now = Date.now();
    const records = (data.internalUnlockCodes ?? [])
      .slice()
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
      .slice(0, 50)
      .map((item) => ({
        id: item.id,
        createdAt: item.createdAt,
        expiresAt: item.expiresAt,
        consumedAt: item.consumedAt,
        status: item.consumedAt
          ? "consumed"
          : new Date(item.expiresAt).getTime() <= now
            ? "expired"
            : "active"
      }));
    return { success: true, data: records };
  }

  async redeem(rawBody: unknown, requesterKey: string) {
    this.assertEnabled();
    const input = redeemSchema.parse(rawBody);
    const compactCode = this.normalizeCode(input.code);
    if (compactCode.length < 6 || compactCode.length > 32) {
      throw new BadRequestException("指令格式不正确");
    }
    this.consumeAttempt(requesterKey, input.installId);

    const candidateHash = this.hashCode(compactCode);
    if (
      this.fixedCode.length >= 6 &&
      this.hashesMatch(candidateHash, this.hashCode(this.fixedCode))
    ) {
      this.attempts.delete(this.attemptKey(requesterKey, input.installId));
      return {
        success: true,
        unlock: true,
        consumedAt: new Date().toISOString(),
        fixed: true
      };
    }

    let consumedAt = "";
    await this.store.update((data) => {
      const now = new Date();
      const record = (data.internalUnlockCodes ?? []).find((item) =>
        this.hashesMatch(item.codeHash, candidateHash) &&
        !item.consumedAt &&
        new Date(item.expiresAt).getTime() > now.getTime()
      );
      if (!record) {
        throw new UnauthorizedException("指令无效、已过期或已使用");
      }
      consumedAt = now.toISOString();
      record.consumedAt = consumedAt;
      record.consumedByHash = createHash("sha256")
        .update(`${input.installId}:${input.appVersion}:${input.appBuild}`)
        .digest("hex");
    });

    this.attempts.delete(this.attemptKey(requesterKey, input.installId));
    return {
      success: true,
      unlock: true,
      consumedAt
    };
  }

  private assertEnabled() {
    if (!this.enabled) {
      throw new NotFoundException();
    }
  }

  private generateCode(length: number) {
    const bytes = randomBytes(length);
    return Array.from(bytes, (value) =>
      InternalUnlockService.alphabet[value % InternalUnlockService.alphabet.length]
    ).join("");
  }

  private normalizeCode(value: string) {
    return value.toUpperCase().replace(/[^A-Z0-9]/g, "");
  }

  private formatCode(value: string) {
    return `${value.slice(0, 5)}-${value.slice(5)}`;
  }

  private hashCode(value: string) {
    return createHmac("sha256", this.signingSecret)
      .update(this.normalizeCode(value))
      .digest("hex");
  }

  private hashesMatch(left: string, right: string) {
    const leftBuffer = Buffer.from(left, "hex");
    const rightBuffer = Buffer.from(right, "hex");
    return leftBuffer.length === rightBuffer.length && timingSafeEqual(leftBuffer, rightBuffer);
  }

  private consumeAttempt(requesterKey: string, installId: string) {
    const key = this.attemptKey(requesterKey, installId);
    const now = Date.now();
    const current = this.attempts.get(key);
    if (!current || current.resetAt <= now) {
      this.attempts.set(key, { count: 1, resetAt: now + 10 * 60_000 });
      return;
    }
    if (current.count >= 5) {
      throw new HttpException("尝试次数过多，请稍后再试", HttpStatus.TOO_MANY_REQUESTS);
    }
    current.count += 1;
  }

  private attemptKey(requesterKey: string, installId: string) {
    return createHash("sha256").update(`${requesterKey}:${installId}`).digest("hex");
  }
}
