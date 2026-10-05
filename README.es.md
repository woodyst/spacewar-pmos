*[English version](README.md)*

# postmarketOS en el Nothing Phone (1) (`nothing,spacewar`, SM7325)

Parches y configuración que convierten postmarketOS mainline en el Nothing Phone (1) en un teléfono
que se puede usar de verdad: **llamadas con audio en los dos sentidos** (auricular, altavoz y casco
Bluetooth), audio estéreo, cámaras, sensores, GPS, avisos que **suenan, vibran y encienden los LED
Glyph**, y un teléfono que suspende bien. Además lleva un driver mainline pequeño para las **tiras
LED Glyph** de la parte de atrás.

Todo esto va encima del fork de kernel [sc7280-mainline](https://github.com/sc7280-mainline/linux)
y de los paquetes de postmarketOS. Nada de aquí los sustituye: esto es una capa.

> **Léelo primero:** es un port de aficionado, no un producto. Tiene aristas y las cuento con
> honestidad en [Lo que no funciona](#lo-que-no-funciona). Tampoco está **probado de principio a fin
> sobre una instalación limpia** todavía — ver [Estado de estas instrucciones](#estado-de-estas-instrucciones).

## Lo que funciona

| | |
|---|---|
| **Llamadas** | Salientes y entrantes, **audio en ambos sentidos**, cambio auricular ⇄ altavoz ⇄ casco Bluetooth a mitad de llamada, volumen y **silencio de verdad**. La **cancelación de eco** está implementada pero necesita la calibración de voz de fábrica de tu propio teléfono (ver abajo) |
| **Audio** | Altavoces estéreo con L/R correctos (los dos amplificadores TFA9873), auricular, casco con cable, A2DP por Bluetooth |
| **Bluetooth** | Música A2DP, **llamadas por casco** con el SCO descargado al chip, y mover la llamada entre altavoz y casco sin que se quede muda |
| **Datos móviles / SMS** | LTE, datos y SMS |
| **Cámaras** | Los tres sensores capturan (la principal IMX766, la ultra gran angular y la frontal) |
| **Sensores** | Acelerómetro y rotación, luz, proximidad, magnetómetro |
| **GPS** | El motor del módem, con Galileo y BeiDou llegando a las aplicaciones |
| **Avisos** | Sonido, vibración y las **tiras LED Glyph** de la parte de atrás |
| **LED Glyph** | El AW21018 de 18 canales que mueve las tiras blancas tiene driver aquí; feedbackd lo usa como LED de notificación blanco |
| **Háptica** | El motor LRA, movido por el bloque de haptics del PMIC |
| **USB OTG** | Modo host |
| **Consumo** | El teléfono **suspende bien**: se domesticaron las fuentes de despertar que lo mantenían despierto (UART del Bluetooth, avisos de batería del PMIC, avisos del módem, el keepalive de la VPN) |
| **Estabilidad** | Un perro guardián por hardware con prueba de vida real reinicia si se congela, se mitiga un bloqueo del escalado de reloj de la UFS y se parchean red y Wi-Fi |
| **Waydroid** | Contenedores Android sobre el kernel mainline |

## Lo que no funciona

- **Huella dactilar.** Es un sensor bajo la pantalla con una interfaz de fabricante que mainline no
  maneja.
- **La cancelación de eco necesita ficheros que no están aquí.** Funciona, pero el cancelador del
  DSP necesita la **calibración de voz de fábrica**, que es dato de Nothing y Qualcomm y **no se
  redistribuye**. Sin ella el servicio de arranque deja las llamadas en paso directo: funcionan como
  antes, sin cancelar el eco.
- **El Wi-Fi** va, pero agradece una variante de calibración; cuenta con que no sea perfecto.
- **El NFC** solo está a medias.
- **La calidad de las fotos está sin calibrar**: el ISP por software no tiene un ajuste bueno para la
  IMX766, así que sus fotos tienen artefactos de color. La ultra gran angular y la frontal salen más
  limpias.
- **Los modos de pantalla a 90/120 Hz** no están implementados (solo 60 Hz).

## Requisitos

- [`pmbootstrap`](https://wiki.postmarketos.org/wiki/Pmbootstrap) con un `pmaports`.
- Un Nothing Phone (1) (`nothing,spacewar`) con el **bootloader desbloqueado**.

## Construir una imagen

El paquete del kernel de aquí es una capa sobre el de postmarketOS. Cópialo sobre el aport y compila
como siempre:

```sh
git clone https://github.com/woodyst/spacewar-pmos
cd spacewar-pmos

# 1. Kernel: 52 parches, la receta y la config
PMAPORTS=$(pmbootstrap config aports)
cp kernel/*.patch kernel/APKBUILD kernel/config-* \
   "$PMAPORTS/device/community/linux-postmarketos-qcom-sc7280/"

# 2. Los paquetes parcheados (calls, libcamera, ModemManager, NetworkManager, phosh, …).
#    Cada packages/<nombre>/ trae su APKBUILD y sus parches; cópialos sobre el aport del
#    mismo nombre (en temp/ o en device/community/ donde exista) — mira el APKBUILD de
#    cada paquete para ver qué extiende.

# 3. Sumas y compilación
pmbootstrap checksum linux-postmarketos-qcom-sc7280 <los paquetes que hayas copiado>
pmbootstrap shutdown          # por la trampa de abajo
pmbootstrap install
```

⚠️ **`pmbootstrap checksum` deja su chroot montado**, y la siguiente compilación falla con
*"Failed to umount … /mnt/pmbootstrap/packages"*. Ejecuta `pmbootstrap shutdown` entre medias.

⚠️ **Si un paquete no se recompila**, súbele el `pkgrel`: si no, pmbootstrap dice "up to date" y lo
salta.

⚠️ El `pkgrel` del kernel es alto a propósito, para que una actualización oficial del mismo
`pkgver` no lo sustituya en silencio.

## Flashearlo en el teléfono

El bootloader de Nothing acepta un `boot.img` mainline **solo si `vendor_boot` y `dtbo` no están** —
es lo único que no dice la wiki de postmarketOS, y sin ello el bootloader responde `Load Error` o se
queda en el logo. **No** hace falta instalar antes ninguna versión de Android: el firmware de
arranque y las imágenes del DSP y el módem se quedan en sus particiones.

Con el teléfono en el bootloader (**Volumen Abajo + encendido** desde apagado):

```sh
# borra los overlays de fábrica y la imagen de arranque del proveedor, o el ABL rechaza el kernel
fastboot -w
fastboot erase dtbo
fastboot erase vendor_boot

# la imagen construida antes
pmbootstrap flasher flash_kernel
pmbootstrap flasher flash_rootfs
fastboot reboot
```

Modos: **bootloader** = Volumen Abajo + encendido · **recovery** = Volumen Arriba + encendido ·
**EDL** = Volumen Arriba + Volumen Abajo + encendido.

El primer arranque tarda un minuto; luego el teléfono aparece por USB en `172.16.42.1` (la dirección
por defecto de postmarketOS). ⚠️ Ojo: `fastboot -w` puede fallar al formatear `userdata` con el
`mke2fs` de algunos paquetes `android-sdk`; borrar `userdata` y `metadata` explícitamente hace lo
mismo.

## Instalar la configuración del dispositivo

El kernel solo no basta: el enrutado de audio, los demonios de llamada, los avisos y los ajustes de
energía viven en el espacio de usuario. Mira [`device/README.md`](device/README.md) para saber qué es
cada fichero y dónde va, o usa el ayudante:

```sh
scripts/install-on-device.sh <nombre-o-ip>
```

Después reinicia, para que todo arranque en el orden correcto.

## Lo que **no** está aquí a propósito

Ni un blob propietario. Para funcionar del todo este teléfono necesita binarios de sus propias
particiones de fábrica — calibración de audio (ACDB y la **calibración de voz** que necesita el
cancelador de eco), firmware del DSP y el módem, configuración de los sensores de cámara, el árbol de
dispositivos de fábrica. Son de Nothing y de Qualcomm, no de este proyecto, y **no se redistribuyen
aquí**. Ya están en tu teléfono, y postmarketOS no borra las particiones que los guardan, así que se
pueden leer de ahí.

También quedan fuera: grabaciones de audio, trazas de Bluetooth y volcados de registros de las
sesiones de desarrollo. Llevan voces, direcciones e identificadores, y nada de eso hace falta para
reproducir nada.

## Estado de estas instrucciones

Con honestidad: esta capa **se sabe que funciona**, porque el teléfono en el que se desarrolló la
ejecuta, y la serie de parches del kernel está verificada como aplicable y compilable. Pero **la
receta entera nunca se ha ejecutado de principio a fin sobre una instalación limpia**. Si lo
intentas, cuenta con huecos y, por favor, cuéntalos.

## Licencias

Los parches del kernel son obra derivada del kernel Linux y son **GPL-2.0**. Los demás parches de
paquete conservan la licencia del proyecto que parchean (libcamera **LGPL-2.1-or-later**,
ModemManager y NetworkManager **GPL-2.0-or-later**, hexagonrpcd **GPL-3.0-or-later**, etc.). Los
ficheros de configuración y los guiones se publican en los mismos términos que los proyectos que
extienden. Ver [`NOTICE.md`](NOTICE.md).

## Documentación

- [`docs/`](docs/) — notas por subsistema: qué fallaba, cómo se encontró y las trampas.
- [`kernel/`](kernel/) — la serie de parches, un commit por arreglo, más la receta y la config.
- [`packages/`](packages/) — los paquetes parcheados (calls, callaudiod, libcamera, hexagonrpcd,
  ModemManager, NetworkManager, phosh, stevia, flare, iio-sensor-proxy, mobile-broadband-provider-info).
- [`device/`](device/) — la configuración del dispositivo, y [`device/README.md`](device/README.md)
  para saber qué es cada fichero y dónde va.
- [Versión en inglés de este fichero](README.md).
