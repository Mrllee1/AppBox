import { CanActivate, ExecutionContext, Inject, Injectable } from "@nestjs/common";
import { AuthService } from "./auth.service";

interface AdminRequest {
  adminUser?: ReturnType<AuthService["verifyBearerHeader"]>;
  headers: Record<string, string | string[] | undefined>;
}

@Injectable()
export class AdminAuthGuard implements CanActivate {
  constructor(@Inject(AuthService) private readonly auth: AuthService) {}

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<AdminRequest>();
    const header = request.headers.authorization;
    request.adminUser = this.auth.verifyBearerHeader(Array.isArray(header) ? header[0] : header);
    return true;
  }
}
