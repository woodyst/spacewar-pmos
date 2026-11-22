# Pendiente

Lo que queda abierto, y por dónde empezar.

## Grandes

- **Huella dactilar**: sensor bajo la pantalla con interfaz de fabricante que mainline no maneja.
- **Cancelación de eco sin calibración de fábrica**: implementada, pero necesita la calibración de
  voz (dato de Nothing/Qualcomm). Sin ella, llamadas en paso directo.
- **Causa de fondo del enrutador de wireplumber** que se rompe al cambiar de perfil con el sumidero
  activo. Ver [`wireplumber.es.md`](wireplumber.es.md).
- **Fallo intermitente de `q6voiced`**: en algunas llamadas no abre el PCM de voz y la llamada sale
  muda; la causa no está demostrada (una vez sonó **sin** abrir el PCM, así que «abrir el PCM» no es
  la causa). Arreglo candidato: reiniciar `q6voiced` **al colgar**. ⛔ **No** portar el parche 0003 de
  callaudiod del POCO: rompía todas las llamadas.
- **Calibración de radio Wi-Fi de fábrica** (variante `Nothing_Spacewar` en `board-2.bin`). Ver
  [`wifi-modem.es.md`](wifi-modem.es.md).

## Cámaras

- ✅ **Exposición/ganancia**: hechos los *sensor helpers* de `s5kjn1` e `imx766` (el AGC converge). Antes
  la IMX766 se quedaba en ganancia 0 y las imágenes salían negras.
- ✅ **Autoenfoque** por contraste y **enfoque manual** (`LensPosition`), probados en la app.
- **Zoom digital**: el pipeline ignora `ScalerCrop`; hay que atenderlo y recortar+escalar en el ISP.
- **Calidad de imagen** de la principal: el ISP por software no tiene ajuste fino para la IMX766; la CCM
  de la trasera‑1 (`s5kjn1.yaml`) se puede afinar si aún se ve verdosa.
- `AfMode` se publica pero no aparece en la lista de controles.

## LED Glyph

- **Patrones multi-paso** de verdad, más allá de `color`, `frequency` (0 = fijo), `max-brightness` y
  `priority` que admite el tema de feedbackd.
- **Efectos de hardware** del AW21018: respiración, control por grupos y los paquetes CSV
  «ringtone/notification» del driver de Android.
- Que el Glyph se encienda también con la pantalla encendida exigiría elegir sonido **o** LED por
  evento (feedbackd admite uno por evento y perfil).

## Menores

- **NFC** solo a medias.
- **90/120 Hz** de pantalla, no implementados (60 Hz).
- **Volumen de llamada**: el TFA9873 casi no tiene ganancia útil; el volumen va por el DSP. Afinar el
  paso si hiciera falta.
- **Sensores**: decidir si el interruptor `spacewar-sensores.conf` sobra ya (con el parche de
  iio-sensor-proxy, phosh se recuperaría solo).
- **Micrófonos digitales** del WCD9385 con mainline: no dan audio (los analógicos sí).

## ✅ phosh 0.59 con nuestros dos parches

Compilado e instalado `phosh-99990.59.0-r100`:

- **0002** — la pantalla ya no se enciende en un despertar automático.
- **0001** — vuelven los botones de **VPN** y **Waydroid** (complemento «mandato»).

✅ Probado el 2026-11-22: los dos botones funcionan.

Al portar cambió una cosa: la lista de complementos activos está ahora en `mobi.phosh.shell.plugins
quick-settings` (antes `sm.puri.phosh.plugins`); el script de botones prueba las dos. Y dos piezas de la receta
0.57 ya sobran en 0.59: `splash-timeout-flatpak-dbus.patch` (ese MR ya está upstream) y el `appstream-dev`
añadido a mano.

De paso quedó resuelto el bloqueo del buildroot: `systemd 262.2` duplica ficheros entre `bin/` y `usr/bin/` y
`apk` fallaba al instalarlo; `apk fix` deja el estado sano y el script lo hace solo con `--lax` + reintento.

## ✅ RESUELTO: la voz en 7.2.9

Dos fallos encadenados, los dos corregidos y probados con una llamada real (2026-11-22 15:00):

1. **DTS**: los parches `0019`/`0022` insertaban con el contexto `platform {`, que se repite en todos los
   enlaces, y `patch` metió los cinco enlaces de voz dentro del nodo del panel. La tarjeta quedaba con 7
   enlaces y ASoC decía `no backend DAIs enabled for CS-Voice`. El `0060` los devuelve a `&sound`.
2. **Supervisor**: al conectar el casco la tarjeta bluez aún no tiene perfil de voz ni fuente SCO, así que el
   SCO de calentamiento no subía y el intento se daba por gastado; la llamada llegaba con el WCN6750 fuera del
   SLIMbus y el calentamiento solo acertaba ya sin llamada (11 s de silencio). Ahora ese fallo no cuenta como
   intento y se reintenta durante 20 s.

## ✅ Autoenfoque en libcamera 0.8

Funciona (`Autofocus settled at 2558 (fom 9.63) after 12 measurements`). Portado a la estructura nueva
del IPA (`src/ipa/softisp`), con estos tropiezos documentados en los parches:

- la **fusión de estadísticas** del ISP no copiaba la nitidez (se calculaba por hilo y se tiraba);
- el rango del actuador se guardaba antes del reset del contexto del IPA;
- la IPA recibía el mapa de controles sin la lente;
- **`/dev/udmabuf` primero**: con 16 MB de CMA la captura no arrancaba;
- ***sensor helpers*** de `s5kjn1` e `imx766` (sin ellos el AGC dejaba la IMX766 en ganancia 0 y todo
  salía negro);
- las calibraciones van en `ipa/softisp` (0.8 renombró la carpeta desde `ipa/simple`).

⚠️ Con escena oscura la nitidez es 0 **y es correcto**: sin luz no hay contraste que medir.

✅ Probado en la app el 2026-11-22: enfoca bien. Y el portal de cámara también funciona (hay que
cerrar la app si se quedó colgada de un intento anterior).

