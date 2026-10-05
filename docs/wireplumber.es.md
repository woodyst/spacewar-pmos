# El enrutador de wireplumber se rompe con cada llamada

Esta es, probablemente, la historia más útil del repo.

## Síntoma

«No me suenan las llamadas entrantes ni creo que tampoco las notificaciones». El teléfono quedaba
**mudo** hasta reiniciar wireplumber.

## Causa

El cambio de perfil que hace **toda** llamada (`HiFi` → `Voice Call (Earpiece)` → `HiFi`) rompe el
despachador de eventos de wireplumber **si el sumidero está ACTIVO en ese momento** — que es justo lo
que pasa mientras **suena el timbre**. A partir de ahí **ningún flujo nuevo se enlaza**: ni avisos, ni
timbre, ni la llamada siguiente.

## Cómo se ve, sin adivinar

| Dónde | Qué aparece |
|---|---|
| `pactl list sink-inputs` | flujos `libcanberra` **`Corked: yes`** con **`Sink: 4294967295`** (= ningún sumidero); se acumulan |
| `journalctl --user -t pipewire-pulse` | `[feedbackd] timeout on stream … channel:0` |
| `journalctl --user -t wireplumber` | `wp-event-dispatcher … failed: failed to activate item: Object activation aborted: proxy destroyed` y `s-linking: … Link was not activated before removing` |
| cualquier cliente | `paplay` da `Stream error: Timeout` y `pw-play` se queda colgado |

⚠️ **No es del rol, ni del tema de sonido, ni de feedbackd**: falla igual con cualquier `media.role` y
con `pw-play` (cliente nativo). El grafo sigue corriendo; lo que no ocurre es el **enlace** del nodo
nuevo.

## Medido (A/B)

Ciclo de perfil `HiFi → Voice Call → HiFi`:

| Estado del sumidero al cambiar | Rompe |
|---|---|
| en reposo (SUSPENDED) | **0 de 5** |
| activo (RUNNING) | **2 de 3** |

El mensaje `wp-event-dispatcher … failed` sale en **todos** los cambios de perfil, pero solo deja el
enrutado roto cuando el sumidero estaba activo: **el mensaje por sí solo no prueba el fallo.**

Esto explica los fallos intermitentes de llamadas que llevaban días sin causa (una llamada muda, otra
por el altavoz).

## Mitigación (el síntoma, no la causa)

`device/supervisor/supervisor-llamada-bt.py`: **al colgar**, comprueba el enrutado y, si está roto,
reinicia wireplumber. La prueba es un instrumento silencioso: **0,2 s de silencio** por `paplay`; si
está roto, expira; si está bien, sale en un pestañeo y **no se oye nada**. Solo actúa **sin llamada en
curso** (se revalida antes y después) y lo deja en el acta.

⚠️ La causa de fondo (wireplumber 0.5.17 + PipeWire 1.6.8: cambio de perfil con nodos activos) sigue
abierta. Ojo: `suspend-node-spacewar.lua` hace justo lo contrario durante la llamada, y por una razón
medida (remontar el AFE con el casco Bluetooth estrella el ADSP).

## Trampa de método

La propia sonda de llamadas llegó a **ser el fallo**: su foto retrasaba el montaje del SCO 6,8 s y
dejaba muda la llamada con casco. Pasó de 17,0 s a 4,1 s al arreglarla. **Medir sin perturbar.**
