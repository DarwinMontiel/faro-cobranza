# Registro de cambios

Formato [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) · [SemVer](https://semver.org/lang/es/).

## [1.1.0] - 2026-11-13

### Cambiado
- El proyecto se llama ahora **Faro Cobranza** (antes "Cartera CRM"): módulo `FaroCobranza`, bases
  `faro_cobranza_*`, servicio de Kamal, variable `FARO_COBRANZA_DATABASE_PASSWORD` y prefijo de
  tokens `faro_`. Los tokens `crm_` ya emitidos siguen funcionando hasta que se revoquen.
- Los días de mora se derivan de `past_due_since` en lugar de ser una columna escrita a mano.
- El respaldo de festivos se calcula por ley (Ley Emiliani + Pascua) para cualquier año, en lugar
  de una lista fija de 2026-2027, y se recuerda solo 10 minutos antes de reintentar la API.
- El saldo por franja del tablero sale de una sola consulta (`SUM … FILTER`).

### Agregado
- `RefreshDelinquencyJob`: cierre diario de cartera (1:00 a. m.) que recalcula la mora y declara
  incumplidos los acuerdos con cuotas vencidas más allá de 5 días de gracia. Tarea `mora:recalcular`.
- Tarea `festivos:listar[AAAA]` (festivómetro).
- Ícono propio, manifiesto PWA, páginas de error y correo de restablecimiento en español.
- Configuración de correo por variables de entorno (`APP_HOST`, `MAILER_FROM`, `SMTP_*`) y
  protección de `Host` en producción.
- `docs/api.http` para probar la API, diagramas de secuencia (reintentos idempotentes) y de
  estados del acuerdo.

### Corregido
- Un reintento que perdía la carrera contra otro con la misma `reference` recibía `422` en lugar
  del `200` idempotente.
- Un corte de red momentáneo dejaba al proceso usando el respaldo de festivos hasta reiniciarse, y
  los años sin respaldo trataban los festivos como días hábiles.
- El correo de restablecimiento salía en inglés, desde `from@example.com` y con enlaces a
  `example.com`.

## [1.0.0] - 2026-11-05

### Agregado
- Autenticación nativa de Rails 8 con límite de intentos y recuperación de contraseña.
- Clientes con búsqueda en vivo (Turbo Frame, índice de trigramas) y normalización de datos.
- Bandeja de cobro por franja de mora y detalle de obligación con historial de gestiones.
- Registro de gestiones con promesas de pago vía Turbo Streams.
- Acuerdos de pago con plan de cuotas en días hábiles (API de festivos + respaldo), formulario
  anidado dinámico y validación de política de cobertura.
- API REST v1 con tokens hasheados, errores uniformes, paginación, límite de solicitudes y
  registro idempotente de acuerdos.
- Restricciones de integridad en PostgreSQL (CHECK, índices únicos y parciales).
- Tablero con indicadores de cartera y gestión.
- Interfaz en español (i18n), modo oscuro y diseño responsive.
- CI: Brakeman, bundler-audit, importmap audit, RuboCop, pruebas, pruebas de sistema y build Docker.
- Despliegue con Kamal 2 (web, jobs, PostgreSQL, TLS).

[1.1.0]: https://github.com/DarwinMontiel/faro-cobranza/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/DarwinMontiel/faro-cobranza/releases/tag/v1.0.0
