import { Body, Controller, Get, Inject, Post, Req, UseGuards } from "@nestjs/common";
import { AdminAuthGuard } from "./admin-auth.guard";
import { AuthService, AdminUser } from "./auth.service";

interface AdminRequest {
  adminUser?: AdminUser;
}

@Controller("/admin/auth")
export class AuthController {
  constructor(@Inject(AuthService) private readonly auth: AuthService) {}

  @Post("login")
  login(@Body() body: unknown) {
    return this.auth.login(body);
  }

  @UseGuards(AdminAuthGuard)
  @Get("me")
  me(@Req() request: AdminRequest) {
    return this.auth.me(request.adminUser as AdminUser);
  }
}
