# Bluetooth y llamadas por casco

Misma arquitectura que el POCO X3: el audio de la llamada va del DSP al chip por **SLIMbus**
(`SLIMBUS_7`) y el enlace SCO por aire es solo control. Lo que costó no fue eso, sino **hacer
aparecer al chip en el bus**.

## El chip que no se presentaba

`wcn-bt-slim` no encontraba al WCN6750 («chip never showed up on the bus»). Descartado con medidas:
la alimentación, los pines del bus, el firmware (se probó el de fábrica), `hfp_offload`, el
controlador despierto y el SCO descargado. La causa:

1. **El controlador SLIMbus se autosuspende** a los 100 ms; el ADSP desmonta el bus, y cada consulta
   sale a milisegundos de rearrancarlo, sin tiempo a que el chip se anuncie. El driver de fábrica
   (`btfm_slim_hw_init`) sondea cada 1 ms durante 100 ms y mantiene el bus en pie.
2. **El código de producto no es el que dice el device tree.** El driver de fábrica lee la versión
   del chip y reescribe la dirección elemental: el WCN6750 se enumera como **217:222**, no como el
   217:221 del DT. El parche `0031` corrige el DT y el id.
3. **El chip solo se deja enumerar con un SCO ya montado**: en la primera llamada tras arrancar, la
   búsqueda del chip debe hacerse **al arrancar el flujo de audio de la llamada** (el SCO ya está),
   con el bus retenido y un margen de varios segundos; no en el arranque (parches `0036`-`0040`).

Desde la r124, el **arranque del flujo falla en ~0,6 s sin bloquear la tarjeta** y el supervisor
monta el circuito al primer intento.

## El supervisor de llamada por casco

`device/supervisor/` (`llamada-al-bluetooth.service` + `supervisor-llamada-bt.py`) es **dirigido por
eventos D-Bus** (ModemManager y PipeWire), sin sondeo:

- monta el lado del casco cuando empieza una llamada (perfil de voz + SCO por el
  `bluetoothOffloadActive` del dispositivo bluez);
- lo desmonta al pasar a manos libres, y lo **vuelve a montar** al volver — la vuelta que en el POCO
  dejaba la llamada muda;
- comprueba que el circuito está de verdad en pie (señal fiable: `bus channel 157 reserved` frente a
  `chip not enumerated`), y si no, lo reintenta;
- **al colgar, arregla el enrutado de wireplumber** (ver [`wireplumber.es.md`](wireplumber.es.md));
- avisa cuando el controlador Bluetooth está caído: **reiniciar y no tocarlo** (cada intento de
  reconectar contra un chip muerto ha colgado el teléfono).

## Trampas

- ⚠️ **Nunca mSBC**: la tasa del SCO de este chip es fija a 8 kHz y mSBC da silencio.
- ⚠️ Grabar del nodo con `bluez5.hw-offload-sco` **no abre el SCO**: se abre con
  `bluetoothOffloadActive` en las propiedades del dispositivo bluez.
- ⚠️ El **greeter** no debe registrar el perfil manos libres: ganaría la carrera y la primera llamada
  tras arrancar se quedaría sin perfil (`device/bluetooth/10-greeter-sin-bluetooth.conf`).
- `hci_qca` solo anuncia los códecs descargados con el parámetro `hfp_offload` puesto, y eso es
  **después de reiniciar**.
- El `hfp-registrado.sh` de surya **no reparaba nunca** aquí: usaba `ps -o etimes=` (busybox no lo
  tiene) y el veredicto era siempre «bien». Ahora saca la edad de `/proc/<pid>/stat`.

## La primera llamada de cada arranque (arreglado el 2026-11-10)

Síntoma: tras encender el móvil, **la primera llamada nunca va al casco**; se queda en el
teléfono y el acta del supervisor dice `sin enlace SCO en pie` / `sin bajada por SLIMBus`.

Causa: el chip WCN6750 **no existe en el bus SLIMbus** (el que lleva el audio de las llamadas)
hasta que se ha montado **una vez** un SCO descargado desde que arrancó. Mientras no esté:

```
wcn-bt-slim 217:222:1:0: chip not enumerated
ASoC error (-19)   ← ENODEV
```

Medido en un arranque completo: **36 `chip not enumerated` y 0 reservas del canal 157 en 17 h**,
hasta el primer SCO real de una prueba. En cuanto lo hubo:

```
wcn-bt-slim 217:222:1:0: enumerated at stream startup after 0 ms: pgd laddr 0x86, ifd laddr 0x85
wcn-bt-slim 217:222:1:0: bus channel 157 reserved for playback
```

…y a partir de ahí todas las llamadas montan el circuito en ~1 s.

Arreglo (`supervisor-llamada-bt.py`): antes de montar, **solo si el chip aún no está en el
bus** en este arranque, se hace un SCO real de 1 s para despertarlo
(`Sistema.calentar_sco()` con un `parec` del micro del casco). Cuesta ~1,5 s **una vez por
arranque**; el resto de llamadas no pagan nada. El estado se lee del diario del kernel
(`enumerated at stream startup` o `bus channel 157 reserved`).

⚠️ Ojo: pedir el camino del vendor (`hw-offload-datapath`) y tener el SCO montado **no basta** —
se comprobó que con el SCO en pie y sin flujo de audio el chip sigue sin aparecer. Lo que lo
levanta es el SCO **con datos**.
