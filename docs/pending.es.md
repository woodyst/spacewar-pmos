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

- **Exposición/ganancia de la IMX766** (sin sensor helper).
- **Calidad de imagen** de la principal: el ISP por software no tiene ajuste bueno para la IMX766.
- Mejorar la app de cámara del sistema en vez de cambiar de app.

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

## ⏳ Rebasar los parches de phosh a la 0.59

El repositorio ofrece **phosh 0.59** (`99990.59.0-r1`), que sustituye a la `99990.57.0-r102` del proyecto.
Al actualizar se pierden los dos parches de `packages/phosh/`; **por decisión del usuario se deja así de
momento** (2026-11-22).

- **`0002-despertar-automatico-no-enciende-la-pantalla.patch`** es el que importa: sin él la pantalla vuelve
  a encenderse en cada despertar automático del firmware (~2,3 por hora, también de noche) y cada rato
  despierto cuesta ~150 mA; el consumo pasa de ~0,47 %/h a ~3 %/h.
- **`0001`** añade el complemento de los botones propios en los ajustes rápidos (4 ranuras); sin él
  desaparecen.

**Qué hay que hacer al retomarlo**: portar los ~20 líneas de `0002` a `src/monitor-manager.c` de 0.59 —la
función `power_save_mode_changed_cb` sigue existiendo— interceptando `PHOSH_MONITOR_POWER_SAVE_MODE_ON` y
convirtiéndolo en OFF cuando `/run/despertar-origen` diga `automatico` y sea reciente, consumiendo la marca;
lo mismo con `0001`; subir `pkgrel` y recompilar. Mientras tanto, para no perderlo: `sudo apk hold phosh
phosh-lang phosh-schemas phosh-systemd phosh-portalsconf` **y phoc** (van acoplados: phosh 0.57 con phoc
0.59 puede no arrancar la sesión).

## ⏳ Rebasar los parches de libcamera a la 0.8

Tras actualizar, **Snapshot dejó de ver las cámaras**. No era el kernel (`cam -l` listaba las tres) sino que
faltaba el plugin de cámara de PipeWire: `/usr/lib/spa-0.2/libcamera/libspa-libcamera.so` no existía y
`pipewire-spa-libcamera` era un marcador vacío `0-r0`. Con pipewire 1.6.11 ese plugin es real pero **necesita
`libcamera.so.0.8`**, y aquí estaba la 0.7.2 (la del proyecto).

**Hecho**: se soltaron los *pins* de `libcamera*`/`py3-libcamera` en `/etc/apk/world` y se instaló
`pipewire-spa-libcamera=1.6.11-r0`, que trajo **libcamera 99990.8.0-r1** (sin nuestros parches) y
`cosmic-ext-camera 1.11.0`. Comprobado: 3 cámaras en `cam -l`, nodos `Video/Source` en PipeWire y
`IsCameraPresent = true` en el portal.

**Pendiente**: de los 13 parches de `packages/libcamera/`, los **0007 y 0008 ya están en upstream**; los 11
restantes hay que portarlos a 99990.8.0 y recompilar (`scripts/94-libcamera.sh`). Los que se notan:
**0010 (autoenfoque por contraste)**, **0009 (enfoque manual)**, **0011 (encender la lente solo mientras se
usa, dw9719)**, **0012 (udmabuf)** y **0013 (contexto EGL al parar)**. Sin ellos la cámara funciona **sin
autoenfoque** y con menos rendimiento.

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
