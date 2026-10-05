# Cámaras

camss (con C-PHY ya en 7.2.2 para sc7280) + libcamera con el pipeline simple y softISP. Las tres
cámaras dan imagen.

| Cámara | Sensor | Bus | Estado |
|---|---|---|---|
| Principal | Sony IMX766, C-PHY 3 trios | CCI1 bus 1 0x10, CSIPHY3 | capta y **enfoca** (driver WIP de Danila, `0045`; DT `0046`; el actuador AK7377 probado como AK7375, `0048`) |
| Ultra gran angular | Samsung S5KJN1 | CCI1 bus 0 0x2d, CSIPHY2 | bien; **autoenfoque** (DW9800W + libcamera propio) |
| Frontal | Sony IMX471 | CCI0 bus 0 0x1a, CSIPHY0 | bien (orden Bayer corregido, `0047`) |

## Lo que costó

- **S5KJN1**: el DT pedía 600 MHz y el driver solo tiene 700 → no sondeaba, y como camss espera a
  **todos** los sensores de su grafo, tampoco registraba la frontal. `0044`.
- **IMX766**: el dato clave fue C-PHY (3 trios) y la topología del DT de fábrica (CSIPHY 3, CCI
  máster 1, MCLK3 19,2 MHz, reset GPIO 78, vana/vdig/vio 79/108/49, GPIO 72). Sin el driver cargado
  **no se veía ninguna cámara**, por eso estuvo en lista negra; desde r128 se carga sola.
- **IMX471**: el driver anunciaba SGRBG10, pero un fotograma en bruto tiene los verdes en (0,1) y
  (1,0): es RGGB. Con GRBG salían tintes verde/magenta. `0047`.
- **Autoenfoque**: los parches de libcamera `0009`/`0010` exponen `LensPosition`/`AfMode` a las apps y
  añaden nitidez por software; el algoritmo corre donde el fichero de ajuste lista `- Af:` y el sensor
  tiene lente.
- **Enfoque de la principal**: no hay driver del AK7377; se describe como `asahi-kasei,ak7375` con
  `vreg_camw_vaf_1p8` (GPIO 96) y `lens-focus` en `camera@10`. El nombre del actuador se sacó del
  módulo de fábrica (`com.qti.sensormodule.abra_qtech_*`).

## Color

Con el `uncalibrated.yaml` el nivel de negro se estima de la propia imagen y aparecen manchas de
color; `device/camaras/libcamera/imx766.yaml` e `imx471.yaml` lo fijan (64 a 10 bits) en
`/etc/libcamera/ipa/simple/`. La imagen de la IMX766 sigue **sin calibrar** (sin sensor helper), así
que sus fotos tienen artefactos de color.

## Trampas

- ⚠️ wireplumber (y las apps) solo ven cámaras o calibraciones nuevas al **reiniciarlo**, nunca en
  llamada. Si `cam -l` no lista y sale «Resource busy», otra app tiene la cámara cogida.
- ⚠️ El orden de carga importa y camss espera a todos los sensores del DT: si uno falla, **no aparece
  ninguna**.
- Los datos de fábrica de los sensores (`com.qti.sensormodule.*.bin`, EEPROM, PDAF) **no se
  redistribuyen**; están en la partición `vendor` del propio teléfono.
