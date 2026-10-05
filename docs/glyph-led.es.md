# LED Glyph (Awinic AW21018)

Los «Glyph» son las tiras LED blancas de la parte de atrás del Nothing Phone (1). No las mueve el
PMIC: son los **18 canales de un Awinic AW21018** en **i2c1, dirección 0x20**, con un pin de
habilitación en **gpio18** (activo alto) y dos pines de revisión de placa en **gpio19/gpio21**.

## Por qué no había driver

El AW21018 **solo lo maneja el kernel de Android** (NothingOSS, LineageOS, CR-Droid:
`drivers/leds/leds_aw210xx.c`, ~2800 líneas llenas de efectos y ficheros CSV). Mainline, con el que
corre este teléfono, no lo trae. El nodo del device tree sí existe en el de fábrica (`aw210xx_led@20`
en el DT extraído de `vendor_boot`), con su `enable-gpio` y su estado de pinctrl.

## El driver

Dos parches del kernel (`0051`, `0052`) añaden:

- `drivers/leds/leds-aw21018.c` (nuevo), con `CONFIG_LEDS_AW21018=m` y el binding
  `awinic,aw21018.yaml`.
- El nodo `led-controller@20` en `&i2c1` y un estado de pinctrl para gpio18.

El driver modela **toda la tira blanca como un único LED**: la función `indicator` y el color blanco
se declaran en el device tree y el núcleo compone el nombre **`white:indicator`**. La inicialización
(chip enable, oscilador de 1 MHz, 12 bits, corriente global, UVLO, APSE, grupo apagado y tabla de
escala por canal) sigue al driver de referencia de Awinic; `brightness_set_blocking` escribe los
registros de brillo de los canales 1‑16 salvo el 6 y lanza el `UPDATE`.

**Revisión de placa:** el AW21018 tiene dos tablas de corriente según la revisión. Los straps
(gpio19/gpio21) se pueden leer en `/sys/kernel/debug/gpio`; en este teléfono leen **1 y 1 → PVT**, que
usa la tabla «EVT» y corriente global 160. Una placa T0 usaría la propiedad `awinic,t0-tables`.

## Por qué `white:indicator`

No hizo falta **ninguna regla udev propia**. feedbackd ya trae una que captura
`DEVPATH=="*/*:indicator"` y marca el LED como suyo; después:

1. lee el **color del nombre** (`fbd-dev-led.c`), y «white:indicator» contiene «white»;
2. exige el atributo **`pattern`**, que crea `fbd-ledctrl` al poner el trigger;
3. ordena por **prioridad** (un LED normal vale 10; el flash de cámara, 5).

El flash (`white:flash`) se clasifica como tal (tiene `flash_strobe`/`flash_brightness`), así que no
compite por los avisos blancos. Nuestro LED gana.

## Cómo probarlo

```sh
fbcli -t 2 -E message-missed-instant    # parpadea el glyph (perfil activo «full»)
notify-send "Prueba" "Aviso"            # suena; con la pantalla apagada/bloqueada, además enciende el LED
```

**Detalle de diseño de phosh:** con la pantalla **encendida**, un aviso dispara solo el evento
*activo* → **sonido**; el LED vive en los eventos *perdidos* (perfil `silent`), que phosh dispara al
**apagar o bloquear** la pantalla. Por eso `notify-send` con pantalla encendida no enciende el LED.

## Pendiente

Patrones multi-paso de verdad (más allá de `color`, `frequency` —con 0 = fijo—, `max-brightness` y
`priority` que admite el tema de feedbackd) y los efectos de hardware del AW21018: respiración,
control por grupos y los paquetes CSV «ringtone/notification» del driver de Android.
