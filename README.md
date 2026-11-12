<div align="center">

<img src="public/icon.svg" alt="" width="88">

# Faro Cobranza

**El CRM de cobranza donde cada obligación vencida está a la vista y cada promesa de pago cae en
día hábil.** Ruby on Rails 8 + Hotwire: bandeja de cobro, gestiones con promesas, acuerdos con
plan de cuotas según los festivos de Colombia y una API REST idempotente para bots RPA.

[![CI](https://github.com/DarwinMontiel/faro-cobranza/actions/workflows/ci.yml/badge.svg)](https://github.com/DarwinMontiel/faro-cobranza/actions/workflows/ci.yml)
![Ruby](https://img.shields.io/badge/ruby-3.4-CC342D?logo=ruby&logoColor=white)
![Rails](https://img.shields.io/badge/rails-8.1-D30001?logo=rubyonrails&logoColor=white)
![Hotwire](https://img.shields.io/badge/Hotwire-Turbo%20%2B%20Stimulus-5CD8E5)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql&logoColor=white)
[![Licencia: MIT](https://img.shields.io/badge/licencia-MIT-green)](LICENSE)

[Arquitectura](docs/architecture.md) · [API](docs/api.md) · [OpenAPI](docs/openapi.yaml) ·
[Probar la API](docs/api.http) · [Despliegue](docs/deployment.md) · [Decisiones (ADR)](docs/adr/)

<img src="docs/images/dashboard.png" alt="Tablero de Faro Cobranza con saldo de cartera, PAR30 y saldo por franja de mora" width="900">

</div>

---

## Qué resuelve

Un equipo de cobranza necesita, en una sola herramienta:

- **Priorizar**: ver las obligaciones vencidas ordenadas por días de mora, que se recalculan solos
  cada madrugada, y filtrar por franja.
- **Registrar cada gestión** (llamada, WhatsApp, visita…) con su resultado y, si hay promesa de
  pago, la fecha y el valor.
- **Negociar acuerdos de pago** que cumplan la política (entre 60 % y 150 % del saldo) con cuotas
  que nunca venzan un domingo o un festivo.
- **Integrarse con bots RPA** que registran gestiones y acuerdos de forma automática, segura y sin
  duplicados aunque reintenten.

De ahí el nombre: un faro no mueve los barcos, les muestra por dónde ir. El tablero y la bandeja de
cobro le muestran al equipo qué obligación atender primero.

## Un martes en la bandeja de Mónica

> Historia ficticia, con los datos sintéticos del proyecto; sirve para recorrer las funciones.

**Martes 16 de junio de 2026, 8:05 a. m.** Mónica Arango, gestora de cobranza, abre la **bandeja de
cobro**. Durante la noche el cierre diario recalculó la mora de toda la cartera: la tarjeta de
crédito de Laura Gómez amaneció con **47 días** de mora, en la franja `31-60`. Nadie escribió esa
cifra a mano: sale de la fecha del vencimiento impago más antiguo.

**8:12 a. m.** En el historial de Laura ya hay una gestión de origen **"API / bot"**: un bot de
WhatsApp ([colmena-rpa](https://github.com/DarwinMontiel/colmena-rpa)) le escribió a las 7:30 y
ella respondió que puede pagar, pero no todo de una vez. El bot la registró por la API con el
resultado *contacto con titular*.

**9:40 a. m.** Mónica la llama. Laura acepta un **acuerdo a 3 cuotas** desde el viernes 19 de
junio. Mónica escribe el total, pide 3 cuotas y pulsa **Generar plan**. El servidor arma el plan y
lo devuelve por Turbo Stream, sin recargar la página:

| Cuota | Fecha nominal | Vence | Por qué |
|---|---|---|---|
| 1 | vie 19 jun 2026 | vie 19 jun 2026 | día hábil |
| 2 | dom 19 jul 2026 | **mar 21 jul 2026** | domingo, y el lunes 20 es festivo (Día de la Independencia) |
| 3 | mié 19 ago 2026 | mié 19 ago 2026 | día hábil |

La suma de cuotas se actualiza mientras escribe (Stimulus) y la política se valida en el
servidor: si el total no llega al 60 % del saldo, el acuerdo no se guarda.

**9:43 a. m.** Mónica registra el acuerdo. En la misma transacción la obligación pasa a
**"En acuerdo"**; si un bot hubiera intentado registrar otro acuerdo al mismo tiempo, el índice
parcial de PostgreSQL habría impedido que quedaran dos vigentes.

**Semanas después.** Si una cuota sigue sin pago más de 5 días después de su vencimiento, el cierre
diario marca el acuerdo como **incumplido** y la obligación vuelve sola a **"En mora"**, lista
para la siguiente gestión.

## Funcionalidades

| | |
|---|---|
| **Tablero** | Saldo de cartera, saldo vencido, PAR30, gestiones y contactabilidad del día, acuerdos vigentes, promesas pendientes, saldo por franja y próximas cuotas, con consultas agregadas en SQL (`SUM … FILTER`). |
| **Bandeja de cobro** | Obligaciones vencidas por días de mora con filtro por franja (`1-30` … `>180`) y paginación. |
| **Mora calculada** | Los días de mora se derivan de la fecha del vencimiento impago más antiguo; un job diario de Solid Queue los recalcula y declara incumplidos los acuerdos vencidos. |
| **Clientes** | Búsqueda en vivo por nombre o documento (Turbo Frame + *debounce*, índice de trigramas), alta y edición con normalización de documento, nombre y teléfono. |
| **Gestiones** | Formulario con campos de promesa condicionales; se agrega al historial sin recargar (Turbo Streams). Distingue gestiones hechas por personas y por bots. |
| **Acuerdos de pago** | Plan de cuotas generado en el servidor con los festivos de Colombia (API pública + cálculo por Ley Emiliani como respaldo), filas dinámicas, suma en vivo y validación de política. |
| **API REST v1** | Token Bearer (guardado como SHA-256), errores uniformes, paginación, límite de solicitudes y registro **idempotente** de acuerdos. [Documentación](docs/api.md). |
| **Seguridad** | Autenticación nativa de Rails 8, límite de intentos de login, CSRF, SSL forzado, protección de `Host`, Brakeman y auditoría de dependencias en CI. |
| **Detalles** | Interfaz y correos en español, modo oscuro, diseño responsive, ícono y manifiesto propios, páginas de error con el estilo de la app. |

<table>
  <tr>
    <td><img src="docs/images/obligation.png" alt="Detalle de obligación con historial de gestiones"></td>
    <td><img src="docs/images/agreement-form.png" alt="Formulario de acuerdo con plan de cuotas en días hábiles"></td>
  </tr>
  <tr>
    <td align="center"><sub>Obligación: registro de gestión e historial</sub></td>
    <td align="center"><sub>Acuerdo: el 8 de diciembre (festivo) pasa al 9; el sábado 8 de mayo, antes de un lunes festivo, pasa al martes 11</sub></td>
  </tr>
  <tr>
    <td><img src="docs/images/dashboard-dark.png" alt="Tablero en modo oscuro"></td>
    <td><img src="docs/images/work-queue.png" alt="Bandeja de cobro filtrable por franja de mora"></td>
  </tr>
  <tr>
    <td align="center"><sub>Modo oscuro automático</sub></td>
    <td align="center"><sub>Bandeja de cobro por franja</sub></td>
  </tr>
</table>

## Arquitectura

```mermaid
flowchart LR
    UI[Navegador<br/>Turbo + Stimulus] --> W[Controladores web]
    BOT[Bots RPA<br/>colmena-rpa] -- Bearer token --> API[API v1]
    W & API --> SVC[Casos de uso<br/>RegisterPaymentAgreement]
    SVC --> M[Modelos con reglas<br/>de negocio]
    SVC --> HC[HolidayCalendar] -. HTTPS + caché .-> EXT[(API de festivos)]
    HC -- si falla --> LEY[ColombianHolidays<br/>Ley Emiliani + Pascua]
    JOB[RefreshDelinquencyJob<br/>cierre diario 1:00 a. m.] --> M
    M --> PG[(PostgreSQL<br/>CHECK · índices parciales · pg_trgm)]
```

Detalle de capas, uso de Hotwire, ciclo de vida del acuerdo e integridad de datos en
[docs/architecture.md](docs/architecture.md).

**Integridad en dos niveles.** Cada regla crítica vive en el modelo (mensaje claro) y en la base
(garantía): por ejemplo, "un solo acuerdo vigente por obligación" es una validación **y** un
índice único parcial `WHERE status = 'active'`, que resuelve incluso solicitudes simultáneas.

**Bots que reintentan sin duplicar.** Un bot que pierde la respuesta por un *timeout* reintenta con
la misma `reference` y recibe el acuerdo que ya existía:

```mermaid
sequenceDiagram
    autonumber
    participant Bot as Bot RPA
    participant API as Faro Cobranza · API v1
    participant DB as PostgreSQL
    Bot->>API: POST /payment_agreements (reference: rpa-task-7f3c2a)
    API->>DB: acuerdo + cuotas + estado de la obligación (una transacción)
    API--xBot: 201 Created (la respuesta se pierde)
    Bot->>API: reintento con la misma reference
    API->>DB: busca la reference
    API-->>Bot: 200 OK con el mismo acuerdo, sin duplicar
```

Si los dos envíos llegan a la vez, el índice único de `reference` decide y el perdedor también
responde `200` con el acuerdo ganador (hay una prueba para esa carrera).

## Inicio rápido

Requisitos: Ruby 3.4, PostgreSQL 14+ y Chrome (solo para pruebas de sistema).

```bash
git clone https://github.com/DarwinMontiel/faro-cobranza.git
cd faro-cobranza
bin/setup                 # gemas, base de datos (con datos de demostración) y servidor
bin/dev                   # http://localhost:3000
```

Usuario demo: `admin@faro.test` · contraseña `Faro-Demo-2026` (solo datos de demostración; el
seed imprime además un token de API). Si no tienes PostgreSQL instalado:

```bash
docker run -d --name faro-pg -e POSTGRES_PASSWORD=postgres -p 5432:5432 postgres:16
export DATABASE_URL=postgres://postgres:postgres@localhost:5432
```

Tareas útiles:

```bash
bin/rails mora:recalcular            # corre el cierre diario ahora (también acepta [AAAA-MM-DD])
bin/rails "festivos:listar[2027]"    # festivómetro: festivos del año y cuáles movió la Ley Emiliani
```

**Probar la API en 30 segundos:** abre [docs/api.http](docs/api.http) en VS Code (extensión REST
Client), pega el token del seed y envía las solicitudes; el acuerdo se envía dos veces para ver el
`201` y luego el `200` idempotente.

## Pruebas y calidad

```bash
bin/rails test            # 96 pruebas: modelos, servicios, job, consultas, correo, controladores y API
bin/rails test:system     # navegador real (Chrome headless): Turbo Streams y Stimulus
bin/rubocop               # estilo (rubocop-rails-omakase)
bin/brakeman              # análisis estático de seguridad
bin/bundler-audit         # gemas con vulnerabilidades conocidas
bin/ci                    # todo lo anterior, como en GitHub Actions
```

Destacados de la suite:

- **Reglas de negocio** del acuerdo: cobertura mínima y máxima, suma de cuotas, fechas
  crecientes, días hábiles y festivos, unicidad del acuerdo vigente.
- **Festivos por ley**: el cálculo coincide con los calendarios oficiales de 2026 y 2027, la Pascua
  se verifica para varios años y 2020-2040 tienen siempre 18 festivos con los traslados en lunes.
- **Integración externa simulada** con WebMock: respuesta OK, caché, HTTP 503, *timeout*, respuesta
  malformada y reintento de la API cuando vence el respaldo.
- **Cierre diario**: la mora avanza con el calendario, el job es idempotente y los acuerdos se
  incumplen solo después de la gracia.
- **La base de datos también se prueba**: `update_column` debe fallar contra los `CHECK`.
- **API**: autenticación, revocación, 400/404/422 con detalle por campo, idempotencia y carrera de
  reintentos con la misma referencia.
- **Sistema**: plan de cuotas por Turbo Stream, filas dinámicas, suma en vivo, búsqueda mientras
  se escribe y registro de gestiones sin recargar.

Todo corre en [GitHub Actions](.github/workflows/ci.yml) contra PostgreSQL 16, junto con el
build de la imagen Docker de producción.

## Estructura

```
app/
├── controllers/            # web (HTML/Turbo) y api/v1 (JSON)
├── jobs/                   # RefreshDelinquencyJob: cierre diario de cartera
├── models/                 # reglas de negocio, enums con CHECK en la base
├── services/               # RegisterPaymentAgreement, PaymentPlanBuilder, HolidayCalendar, ColombianHolidays
├── queries/                # PortfolioSummary (agregaciones del tablero)
├── views/                  # ERB + Turbo Streams + Jbuilder (API)
└── javascript/controllers/ # 6 controladores Stimulus
config/recurring.yml        # tareas programadas de Solid Queue
config/deploy.yml           # Kamal 2: web, jobs, PostgreSQL, TLS
db/migrate/                 # restricciones e índices de integridad
docs/                       # arquitectura, API (+ api.http), OpenAPI, despliegue, ADRs
lib/tasks/                  # mora:recalcular y festivos:listar
test/                       # modelos, servicios, jobs, consultas, correo, controladores, API y sistema
```

## Decisiones de diseño

| ADR | Decisión |
|---|---|
| [0001](docs/adr/0001-hotwire-en-lugar-de-spa.md) | Hotwire en lugar de una SPA |
| [0002](docs/adr/0002-reglas-en-modelo-y-base.md) | Reglas críticas en el modelo y en PostgreSQL |
| [0003](docs/adr/0003-calendario-de-festivos-con-respaldo.md) | Festivos desde API pública con respaldo calculado por ley |
| [0004](docs/adr/0004-tokens-de-api-con-hash.md) | Tokens de API aleatorios guardados como SHA-256 |

## Qué demuestra y cómo se relaciona con mi experiencia

- **El dominio, visto desde adentro.** Trabajé en la línea de cobranzas de un contact center y
  después como desarrollador RPA en una fintech de gestión de cartera. Franjas de mora, PAR30,
  promesas de pago y acuerdos con política de cobertura son el vocabulario diario de esa operación;
  aquí están modelados con sus reglas.
- **Rails con Hotwire, como en producción.** Ya desarrollé backend y frontend en Ruby on Rails con
  Turbo y Stimulus. Este proyecto lleva esa forma de trabajo a Rails 8: HTML desde el servidor,
  Solid Queue para los procesos programados y Kamal para desplegar.
- **La otra cara de los bots.** Construyo bots RPA que registran información en aplicativos de
  terceros. Aquí estoy del lado del aplicativo: una API pensada para bots, con tokens revocables,
  errores uniformes e idempotencia ante reintentos. Es la contraparte de
  [colmena-rpa](https://github.com/DarwinMontiel/colmena-rpa).
- **Datos confiables.** Las reglas que importan están también en PostgreSQL (`CHECK`, índices
  parciales y únicos), y la mora se calcula en lugar de escribirse a mano.

## Ecosistema

Proyectos del mismo portafolio sobre cobranza y automatización:

- [colmena-rpa](https://github.com/DarwinMontiel/colmena-rpa): plataforma de bots RPA con
  RabbitMQ, reintentos e idempotencia; sus bots registran gestiones y acuerdos en esta API.
- [torre-de-control](https://github.com/DarwinMontiel/torre-de-control): monitoreo en tiempo real de
  las colas y los bots de colmena-rpa.
- [radar-cartera](https://github.com/DarwinMontiel/radar-cartera): ETL y analítica de cartera; usa
  las mismas franjas de mora que este CRM.
- [vigia-ocr](https://github.com/DarwinMontiel/vigia-ocr): bot con Selenium, OCR y SQL Server.

## Limitaciones conocidas

- Los pagos todavía no se registran desde la interfaz ni desde la API. Mientras tanto, el cierre
  diario declara incumplido todo acuerdo con una cuota vencida hace más de 5 días sin pago marcado.
- El estado "Cumplido" y la anulación de acuerdos existen en el modelo, pero aún no tienen flujo
  en la interfaz.

## Hoja de ruta

- [ ] Registro de pagos (pantalla, API y archivo del banco) y cumplimiento automático de acuerdos.
- [ ] Roles y permisos por equipo (Pundit) y auditoría de cambios.
- [ ] Notificaciones al cliente por WhatsApp/SMS con plantillas.
- [ ] Exportación de la bandeja de cobro a Excel.

## Autor

**Darwin Montiel Mora** · Desarrollador RPA & Backend · Ingeniero de Sistemas · Bogotá, Colombia
[LinkedIn](https://www.linkedin.com/in/darwin-montiel-mora-925216206) · [GitHub](https://github.com/DarwinMontiel)

Datos de demostración 100 % sintéticos: ninguna persona, cliente ni entidad es real.
Licencia [MIT](LICENSE).
