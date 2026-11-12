# ADR-0004 · Tokens de API aleatorios guardados como SHA-256

- **Estado:** aceptada · **Fecha:** 2026-11

## Contexto

Los bots y otras integraciones necesitan credenciales de larga duración, revocables y
auditables, separadas de las contraseñas de los usuarios.

## Decisión

- Token = prefijo `faro_` + 32 caracteres base58 aleatorios (`SecureRandom`). Los tokens
  emitidos con el prefijo anterior al cambio de nombre (`crm_`) se siguen aceptando hasta que se
  revoquen, para no romper integraciones existentes.
- Se muestra **una sola vez** en la respuesta de creación (no pasa por flash ni por cookies).
- En la base solo se guarda `SHA-256(token)`. SHA-256 sin sal es suficiente porque el token
  tiene alta entropía (no es una contraseña elegida por una persona); bcrypt agregaría latencia
  a cada solicitud sin beneficio.
- El prefijo permite descartar sin consultar la base y que los escáneres de secretos lo reconozcan.
- `last_used_at` se actualiza como máximo una vez por minuto (evita una escritura por solicitud).
- Revocar marca `revoked_at`; el token deja de autenticar de inmediato.

## Consecuencias

- Una fuga de la base de datos no expone credenciales utilizables.
- Si un usuario pierde el token, debe crear uno nuevo (no hay forma de recuperarlo).
