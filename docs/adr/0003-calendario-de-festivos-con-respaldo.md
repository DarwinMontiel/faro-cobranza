# ADR-0003 · Festivos desde una API pública con respaldo calculado por ley

- **Estado:** aceptada · **Fecha:** 2026-11 · **Revisión:** 2026-11 (el respaldo pasa de lista fija a cálculo)

## Contexto

Las cuotas de un acuerdo deben vencer en días hábiles. Colombia tiene 18 festivos al año: siete
de fecha fija se trasladan al lunes siguiente (Ley 51 de 1983, "Ley Emiliani") y cinco dependen de
la Semana Santa, tres de ellos también trasladables. Un acuerdo puede tener hasta 36 cuotas, así
que el calendario debe conocer festivos de hasta tres años en el futuro.

La primera versión usaba como respaldo una lista en `config/holidays_co.yml` con 2026 y 2027.
Tenía dos problemas: un acuerdo con cuotas en 2028 o 2029 trataba los festivos como días hábiles
si la API fallaba, y el respaldo se memorizaba sin vencimiento, de modo que un corte de red
momentáneo dejaba al proceso usando la lista hasta el siguiente reinicio.

## Decisión

`HolidayCalendar` consulta la API pública de [Nager.Date](https://date.nager.at)
(`/api/v3/PublicHolidays/{año}/CO`) con:

- *timeouts* de 3 s de conexión y lectura;
- caché por año (`Rails.cache`, 30 días) y memoización por proceso de las respuestas válidas;
- **respaldo calculado** con `ColombianHolidays`: fechas fijas, traslado a lunes por Ley Emiliani
  y Domingo de Pascua por el algoritmo gregoriano anónimo (Meeus/Jones/Butcher). Funciona para
  cualquier año sin mantenimiento;
- el respaldo se recuerda solo **10 minutos** (`FALLBACK_TTL`); después se vuelve a intentar la API.
  Una respuesta vacía o malformada también activa el respaldo, y cada uso queda en el log.

El calendario se inyecta (`PaymentAgreement.calendar`) para que las pruebas usen uno
determinístico y la suite nunca salga a internet (WebMock bloquea la red).

## Consecuencias

- Una caída de un tercero nunca impide registrar un acuerdo ni produce cuotas en festivos.
- Las pruebas comparan el cálculo con los calendarios oficiales de 2026 y 2027, verifican la
  Pascua de varios años y que 2020-2040 tengan siempre 18 festivos con los traslados en lunes.
- `bin/rails "festivos:listar[2027]"` imprime el calendario de un año y marca los trasladados.
- Si el Congreso cambia la ley, hay que actualizar `ColombianHolidays` (un solo archivo).
