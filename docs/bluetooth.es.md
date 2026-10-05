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
