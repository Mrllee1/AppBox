import "reflect-metadata";
import { NestFactory } from "@nestjs/core";
import { AppModule } from "./app.module";

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    logger: ["error", "warn", "log"]
  });

  const origins = (process.env.APPBOX_ALLOWED_ORIGINS || "http://127.0.0.1:39111,http://localhost:39111")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);

  app.enableCors({
    origin: origins,
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"]
  });

  const port = Number(process.env.APPBOX_API_PORT || process.env.PORT || 39110);
  await app.listen(port, "127.0.0.1");
  console.log(`AppBox API listening on http://127.0.0.1:${port}`);
}

void bootstrap();
