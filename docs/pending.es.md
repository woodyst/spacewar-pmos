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
