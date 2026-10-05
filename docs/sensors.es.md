# Sensores y rotación

Los sensores van por el **concentrador del ADSP** (SSC, `hexagonrpcd-adsp-sensorspd` + libssc); el
único dispositivo IIO es el ADC del PMIC. El concentrador tarda **~86 s** en terminar de cargar.

## Por qué phosh perdía la rotación

Tres capas, y hizo falta entender las tres:

1. **iio-sensor-proxy busca los sensores una sola vez al arrancar** y no reintenta. Arranca a los
   ~8 s; el acelerómetro del concentrador aparece a los ~86 s. Si la búsqueda falla, adiós sensor.
2. phosh **sí** escucha `notify::has-accelerometer`, pero iio-sensor-proxy **no difunde** el cambio:
   `send_dbus_event()` solo avisa a los clientes que **ya han reclamado** un sensor, y phosh no lo
   había reclamado porque le dijeron que no existía. Círculo cerrado (medido: `PropertiesChanged`
   **0** mientras `HasAccelerometer` pasaba de false a true).
3. El **gancho de suspensión** paraba iio-sensor-proxy al dormir, y con el «volver a dormir» a 15 s
   eso pasaba sin parar; phosh no se reengancha en caliente.

## Arreglo

- `packages/iio-sensor-proxy`: `send_dbus_event()` además **difunde a todo el bus** los cambios de
  `Has*` (solo la disponibilidad; las lecturas siguen yendo a quien las reclama). Probado en vivo,
  sin cerrar sesión: el botón de autoaparece y rota.
- `device/energia/spacewar-sensores.conf`: crea el interruptor `/run/despertar-sin-parar-sensores`,
  que el gancho ya consultaba, para no parar los sensores al dormir.
- `device/energia/esperar-sensores-adsp.sh` + drop-in: esperan al ADSP antes de arrancar
  iio-sensor-proxy.

## Cómo mirarlo (y una trampa)

- `ssccli --sensor accelerometer|magnetometer|compass|light|proximity` los lee directamente.
- `AccelerometerOrientation` es el indicador útil: **`"undefined"` = nadie lo ha reclamado**,
  `"normal"` = phosh lo tiene. ⚠️ Sale `"undefined"` también con el teléfono **plano**: solo indica
  «nadie lo reclama» si el teléfono está de pie.
- ⚠️ **polkit es un falso positivo por SSH**: `AccessDenied: Sensor claim not allowed` sale porque una
  sesión SSH no tiene *seat*. Preguntar por el proceso real:
  `pkcheck --action-id net.hadess.SensorProxy.claim-sensor --process $(pgrep -x phosh)` → rc=0.
- ⚠️ `orientation-lock = true` hace que phosh **no** lo reclame aunque lo tenga (ahorro): es el botón,
  no un fallo.
