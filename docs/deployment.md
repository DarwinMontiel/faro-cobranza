# Despliegue

La aplicación se distribuye como imagen Docker de producción (`Dockerfile` multi-stage con
jemalloc, *bootsnap* precompilado, usuario sin privilegios y Thruster delante de Puma).

## Kamal 2 (servidor Linux propio)

`config/deploy.yml` define:

- contenedor `web` y contenedor `job` (Solid Queue, incluido el cierre diario de cartera) en el
  mismo servidor;
- `kamal-proxy` con TLS automático (Let's Encrypt) y *healthcheck* en `/up`;
- PostgreSQL 16 como *accessory*, expuesto solo en `127.0.0.1`;
- imagen publicada en GitHub Container Registry.

```bash
export KAMAL_REGISTRY_PASSWORD=ghp_...            # token con permiso write:packages
export FARO_COBRANZA_DATABASE_PASSWORD=...        # contraseña de la base de producción
export SMTP_USERNAME=... SMTP_PASSWORD=...        # opcional: correo saliente
kamal setup                                        # primera vez
kamal deploy                                       # siguientes despliegues, sin interrumpir el servicio
kamal app exec "bin/rails db:seed"                 # opcional: datos de demostración
```

Los secretos se leen del entorno de quien despliega (`.kamal/secrets`); `config/master.key`
nunca se versiona.

## Cualquier PaaS con Docker (Render, Railway, Fly.io)

1. Crear una base PostgreSQL administrada y una app desde este repositorio usando el `Dockerfile`.
2. Variables: `RAILS_MASTER_KEY`, `DATABASE_URL` (o `DB_HOST` + `FARO_COBRANZA_DATABASE_PASSWORD`),
   `APP_HOST` y, en instancias pequeñas, `SOLID_QUEUE_IN_PUMA=true` para correr los *jobs*
   (incluido el cierre diario) dentro de Puma.
3. Comando de *release*: `bin/rails db:prepare`.

## Variables de entorno

| Variable | Obligatoria | Uso |
|---|---|---|
| `RAILS_MASTER_KEY` | sí | Descifra `config/credentials.yml.enc`. |
| `FARO_COBRANZA_DATABASE_PASSWORD` / `DB_HOST` | sí (o `DATABASE_URL`) | Conexión a PostgreSQL. |
| `APP_HOST` | recomendada | Dominio público. Se usa en los enlaces de los correos y como lista blanca de `Host` (protección contra DNS rebinding). |
| `MAILER_FROM` | no | Remitente, p. ej. `Faro Cobranza <no-responder@midominio.com>`. |
| `SMTP_ADDRESS`, `SMTP_PORT` | no | Servidor SMTP (puerto 587 con STARTTLS por defecto). |
| `SMTP_USERNAME`, `SMTP_PASSWORD` | no | Credenciales SMTP (secretos). |
| `RAILS_LOG_LEVEL` | no | `info` por defecto. |
| `JOB_CONCURRENCY`, `RAILS_MAX_THREADS`, `WEB_CONCURRENCY` | no | Procesos e hilos de Solid Queue y Puma. |

### Correo

El único correo de la aplicación es el de restablecimiento de contraseña ("¿Olvidaste tu
contraseña?"), en español. Si `SMTP_ADDRESS` está vacío **no se envían correos**: la pantalla
responde igual (para no revelar qué cuentas existen), pero el enlace no llega. Cualquier proveedor
SMTP sirve (Amazon SES, Mailgun, Postmark, SendGrid o el de Google Workspace / Microsoft 365).

Para revisar el diseño del correo en desarrollo: `http://localhost:3000/rails/mailers/passwords_mailer/reset`.

## Tareas programadas

`config/recurring.yml` programa en producción el **cierre diario de cartera**
(`RefreshDelinquencyJob`, 1:00 a. m. hora de Colombia): recalcula los días de mora a partir de
`past_due_since` y declara incumplidos los acuerdos con cuotas vencidas hace más de 5 días.
Es idempotente; para correrlo a mano:

```bash
kamal app exec "bin/rails mora:recalcular"          # o con fecha de corte: "mora:recalcular[2026-12-01]"
```

## Checklist de producción

- [x] `config.force_ssl` y `assume_ssl` activos (Rails 8 por defecto).
- [x] Protección de `Host` con `APP_HOST` (excepto `/up`).
- [x] Límite de intentos de inicio de sesión (`rate_limit` en `SessionsController`).
- [x] Límite de solicitudes de la API por token.
- [x] Brakeman, bundler-audit e importmap audit en CI.
- [x] Restricciones de integridad en la base (ver [ADR-0002](adr/0002-reglas-en-modelo-y-base.md)).
- [x] Correo de restablecimiento configurable por variables de entorno.
- [ ] Copias de seguridad programadas de PostgreSQL (`pg_dump` diario a almacenamiento externo).
- [ ] Monitoreo de errores (p. ej. Sentry o Honeybadger) y alertas de *healthcheck*.
