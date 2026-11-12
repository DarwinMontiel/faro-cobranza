# API REST v1

API JSON para integraciones: consultar cartera y registrar gestiones y acuerdos de pago desde
sistemas externos, por ejemplo los bots de [colmena-rpa](https://github.com/DarwinMontiel/colmena-rpa).
Para probarla en 30 segundos: [api.http](api.http) (extensión REST Client de VS Code o el cliente HTTP de JetBrains).
Especificación formal: [openapi.yaml](openapi.yaml).

## Autenticación

Token Bearer creado en **Integraciones API** (`/api_tokens`). Se muestra una sola vez; en la base
solo queda su SHA-256 y puede revocarse en cualquier momento.

```http
Authorization: Bearer faro_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

Límite: 300 solicitudes por minuto por token (`429 rate_limited`).

## Errores

Todas las respuestas de error tienen la misma forma:

```json
{
  "error": {
    "code": "validation_failed",
    "message": "La solicitud tiene datos inválidos",
    "details": { "promise_date": ["Fecha de la promesa no puede estar en blanco"] }
  }
}
```

| HTTP | `code` | Cuándo |
|---|---|---|
| 400 | `parameter_missing` | Falta un parámetro obligatorio |
| 401 | `unauthorized` | Token ausente, inválido o revocado |
| 404 | `not_found` | El recurso no existe |
| 422 | `validation_failed` | Reglas de negocio o formato (`details` por campo) |
| 429 | `rate_limited` | Se superó el límite de solicitudes |

Los montos se devuelven como *string* decimal (`"2450000.0"`) para no perder precisión.

## Endpoints

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/api/v1/clients?q=&page=&per_page=` | Busca clientes por nombre o documento |
| GET | `/api/v1/clients/:document_number` | Cliente con sus obligaciones |
| GET | `/api/v1/obligations?bucket=&status=&page=` | Obligaciones, filtrables por franja de mora (`31-60`, `>180`…) |
| GET | `/api/v1/obligations/:number` | Obligación con cliente y acuerdo vigente |
| POST | `/api/v1/collection_activities` | Registra una gestión de cobro |
| POST | `/api/v1/payment_agreements` | Registra un acuerdo de pago (**idempotente** por `reference`) |
| GET | `/api/v1/payment_agreements/:reference` | Consulta un acuerdo y sus cuotas |

### Registrar una gestión (bot de llamadas)

```bash
curl -X POST https://faro.example.com/api/v1/collection_activities \
  -H "Authorization: Bearer $FARO_TOKEN" -H "Content-Type: application/json" \
  -d '{
        "obligation_number": "OB-0000001",
        "channel": "call",
        "outcome": "promise_to_pay",
        "promise_date": "2026-11-12",
        "promise_amount": 350000,
        "notes": "Contacto automatizado; cliente acepta fecha"
      }'
```

`201 Created` con la gestión registrada (`source: "api"`). Valores de `channel`: `call`,
`whatsapp`, `visit`, `email`, `sms`. Valores de `outcome`: `no_answer`, `voicemail`,
`wrong_number`, `contact_holder`, `contact_third_party`, `refused`, `promise_to_pay`.

### Registrar un acuerdo de pago (idempotente)

```bash
curl -X POST https://faro.example.com/api/v1/payment_agreements \
  -H "Authorization: Bearer $FARO_TOKEN" -H "Content-Type: application/json" \
  -d '{
        "obligation_number": "OB-0000001",
        "reference": "rpa-task-7f3c2a",
        "total_amount": 2000000,
        "installments": [
          { "number": 1, "due_on": "2026-12-01", "amount": 1000000 },
          { "number": 2, "due_on": "2027-01-04", "amount": 1000000 }
        ]
      }'
```

- `201 Created` la primera vez; **`200 OK` con el mismo acuerdo** si se reintenta con la misma
  `reference` (por ejemplo, tras un *timeout* del bot). Nunca se duplica.
- `422` si el total no cubre el 60 % del saldo, supera el 150 %, las cuotas no suman el total,
  alguna cae en fin de semana o festivo, o la obligación ya tiene un acuerdo vigente.

#### Reintentos e idempotencia

Un bot que pierde la respuesta por un *timeout* no sabe si el acuerdo quedó registrado. Por eso
reintenta **con la misma `reference`**: el CRM responde con el acuerdo existente en lugar de
crear uno duplicado. Esto se cumple incluso si los dos envíos llegan al mismo tiempo: el que
pierde la carrera (por validación o por el índice único de la base) vuelve a buscar la referencia
y responde `200` con el acuerdo ganador.

```mermaid
sequenceDiagram
    autonumber
    participant Bot as Bot RPA (colmena-rpa)
    participant API as Faro Cobranza · API v1
    participant DB as PostgreSQL
    Bot->>API: POST /payment_agreements (reference: rpa-task-7f3c2a)
    API->>DB: INSERT acuerdo + cuotas (una transacción)
    DB-->>API: OK
    API--xBot: 201 Created (la respuesta se pierde por timeout)
    Note over Bot: El bot no sabe si quedó registrado y reintenta
    Bot->>API: POST /payment_agreements (misma reference)
    API->>DB: SELECT por reference
    DB-->>API: acuerdo existente
    API-->>Bot: 200 OK con el mismo acuerdo (sin duplicar)
```