import { Injectable, UnauthorizedException } from "@nestjs/common";
import { createHmac, randomBytes, scryptSync, timingSafeEqual } from "node:crypto";
import { z } from "zod";

const loginSchema = z.object({
  username: z.string().min(1),
  password: z.string().min(1)
});

interface AdminTokenPayload {
  exp: number;
  iat: number;
  role: "admin";
  sub: string;
}

export interface AdminUser {
  role: "admin";
  username: string;
}

@Injectable()
export class AuthService {
  private readonly username = process.env.APPBOX_ADMIN_USERNAME || "admin";
  private readonly passwordHash =
    process.env.APPBOX_ADMIN_PASSWORD_HASH || AuthService.hashPassword(process.env.APPBOX_ADMIN_PASSWORD || "appbox-admin");
  private readonly secret = process.env.APPBOX_ADMIN_SESSION_SECRET || "appbox-local-dev-session-secret";
  private readonly ttlSeconds = Number(process.env.APPBOX_ADMIN_SESSION_TTL_SECONDS || 8 * 60 * 60);

  static hashPassword(password: string, salt = randomBytes(16).toString("base64url")) {
    const hash = scryptSync(password, salt, 64).toString("base64url");
    return `scrypt$${salt}$${hash}`;
  }

  login(body: unknown) {
    const input = loginSchema.parse(body);
    if (input.username !== this.username || !this.verifyPassword(input.password, this.passwordHash)) {
      throw new UnauthorizedException("Invalid username or password");
    }

    const now = Math.floor(Date.now() / 1000);
    const payload: AdminTokenPayload = {
      exp: now + this.ttlSeconds,
      iat: now,
      role: "admin",
      sub: this.username
    };

    return {
      success: true,
      token: this.sign(payload),
      expires_at: new Date(payload.exp * 1000).toISOString(),
      user: {
        role: payload.role,
        username: payload.sub
      }
    };
  }

  verifyBearerHeader(header: string | undefined): AdminUser {
    const token = header?.startsWith("Bearer ") ? header.slice("Bearer ".length).trim() : "";
    if (!token) {
      throw new UnauthorizedException("Missing admin token");
    }
    const payload = this.verifyToken(token);
    return {
      role: payload.role,
      username: payload.sub
    };
  }

  me(user: AdminUser) {
    return {
      success: true,
      user
    };
  }

  private verifyPassword(password: string, encoded: string) {
    const [scheme, salt, expectedHash] = encoded.split("$");
    if (scheme !== "scrypt" || !salt || !expectedHash) return false;
    const actual = Buffer.from(scryptSync(password, salt, 64).toString("base64url"));
    const expected = Buffer.from(expectedHash);
    return actual.length === expected.length && timingSafeEqual(actual, expected);
  }

  private sign(payload: AdminTokenPayload) {
    const header = this.base64UrlJson({ alg: "HS256", typ: "JWT" });
    const body = this.base64UrlJson(payload);
    const signature = this.hmac(`${header}.${body}`);
    return `${header}.${body}.${signature}`;
  }

  private verifyToken(token: string): AdminTokenPayload {
    const [header, body, signature] = token.split(".");
    if (!header || !body || !signature) {
      throw new UnauthorizedException("Invalid admin token");
    }

    const expectedSignature = this.hmac(`${header}.${body}`);
    const expected = Buffer.from(expectedSignature);
    const actual = Buffer.from(signature);
    if (expected.length !== actual.length || !timingSafeEqual(expected, actual)) {
      throw new UnauthorizedException("Invalid admin token");
    }

    const payload = JSON.parse(Buffer.from(body, "base64url").toString("utf8")) as AdminTokenPayload;
    if (payload.role !== "admin" || !payload.sub || payload.exp < Math.floor(Date.now() / 1000)) {
      throw new UnauthorizedException("Expired admin token");
    }
    return payload;
  }

  private base64UrlJson(value: unknown) {
    return Buffer.from(JSON.stringify(value)).toString("base64url");
  }

  private hmac(value: string) {
    return createHmac("sha256", this.secret).update(value).digest("base64url");
  }
}
