# spacewar — postmarketOS en el Nothing Phone (1)

Proyecto hermano de `../suria` (Xiaomi POCO X3 NFC). Repositorio de trabajo privado: los datos de
fábrica y los nombres del banco de pruebas no salen de aquí. La **copia pública curada** (sin blobs)
es **https://github.com/woodyst/spacewar-pmos** — clon en `~/claude/spacewar-pmos`; última release
`kit-2026-10-05` (kernel r135). Se lleva a mano: ver la memoria `reference_git_publico_spacewar_pmos`.

## Punto de partida (2026-09-12)

| | |
|---|---|
| Móvil | **eut2**: Nothing Phone (1), SM7325 («yupik»), con Ubuntu Touch. Es el segundo móvil del banco de llamadas de surya: instalar postmarketOS lo saca del banco hasta que haga llamadas |
| Firmware del móvil | Nothing OS **V3.2** (`Spacewar_V3.2-260416-1140`, huella de vendor `2604161140`), bootloader **desbloqueado** (`flash.locked=0`), ranura activa `_a` |
| Imagen de fábrica | `/ext_r/ext_edi/src/spaceware_restore`: `fw/` (los 7z oficiales de V3.2), `images/` (particiones extraídas), `edl_package/`, `flash.log`. **No se publica** |
| Port de pmOS | `device-nothing-spacewar` (testing), kernel `linux-postmarketos-qcom-sc7280` (sc7280-mainline), `firmware-nothing-spacewar` 3-r1 (desde el 2026-08-03, blobs de **Nothing OS 3.2 EOL**: el mismo firmware que lleva el móvil) |
| Compilación | en **ia**, con un pmbootstrap propio y aislado del de surya (ver abajo) |

## Qué dice la wiki de postmarketOS (página editada el 2026-09-05)

[`Nothing_Phone_1_(nothing-spacewar)`](https://wiki.postmarketos.org/wiki/Nothing_Phone_1_(nothing-spacewar));
se lee en crudo con `curl -A curl/8 '…/index.php?title=Nothing_Phone_1_(nothing-spacewar)&action=raw'`.

- **No pide instalar ninguna versión de Android antes.** El firmware de arranque y de los
  procesadores (xbl, tz, módem, dsp…) se queda en sus particiones; pmOS escribe el kernel y el rootfs.
- Kernel mainline **7.2.2**. Instalación:
  ```sh
  pmbootstrap install
  fastboot -w                      # ⚠️ borra userdata (y lo formatea: ver nota)
  fastboot erase dtbo              # el dtbo de Android pelearía con el árbol de mainline
  fastboot erase vendor_boot       # ⚠️ NO lo dice la wiki, pero sin esto el ABL no arranca el kernel (ver abajo)
  pmbootstrap flasher flash_kernel
  pmbootstrap flasher flash_rootfs
  fastboot reboot
  ```
- Modos: bootloader = Vol− + encendido; recovery = Vol+ + encendido; EDL = Vol+ + Vol− + encendido.

| funciona | parcial | no funciona |
|---|---|---|
| pantalla, táctil, batería (ADSP firmado), almacenamiento, GPU, Bluetooth, GPS, SMS, datos móviles, sensores, OTG, flash, **LED Glyph** | Wi-Fi, NFC, cámara (la principal IMX766 es C-PHY y no va; ultra gran angular y frontal sí), audio: solo auriculares con cable | **llamadas**, **audio** (altavoces: solo canal izquierdo; micros no), háptica, huella |

⚠️ **Sin llamadas ni audio**: eut2 deja de servir de segundo móvil del banco de surya hasta que
postmarketOS haga llamadas en él.

## pmbootstrap

```sh
sh scripts/00-preparar-pmbootstrap-ia.sh    # una vez (se puede repetir)
sh scripts/pmb.sh config device             # cualquier orden de pmbootstrap
```

En ia: `~/postmarketos-spacewar/{pmbootstrap,pmaports,work,ssh}` y `~/.config/pmbootstrap-spacewar.cfg`.
El de surya (`~/postmarketos/`, `~/.config/pmbootstrap_v3.cfg`, `~/.local/var/pmbootstrap`, en ia y en
local) no se toca; su estado está anotado en `../suria/parches/PMBOOTSTRAP-SURYA.md`.

## Instalar

```sh
sh scripts/05-copia-particiones-eut2.sh                    # EFS del módem y persist (fuera del repo)
PMOS_PASSWORD=… sh scripts/10-compilar-imagen.sh           # en ia; trae boot.img y el rootfs
sh scripts/15-restaurar-android.sh                         # (si hace falta) Nothing OS V3.2 de fábrica
IMAGEN=~/compilados-ia/spacewar/AAAAMMDD DESDE_UT=1 sh scripts/20-flashear.sh              # comprueba
IMAGEN=~/compilados-ia/spacewar/AAAAMMDD DESDE_UT=1 CONFIRMAR=si sh scripts/20-flashear.sh # ⚠️ borra y flashea
```

- 2026-09-12: copia de `modemst1`, `modemst2`, `fsg`, `fsc` y `persist` hecha y comprobada en
  `/ext_r/ext_edi/src/spaceware_restore/copia-particiones-20260912/`. Nada que guardar de `userdata`
  (decisión del usuario).
- ⚠️ En el bootloader de este móvil `fastboot getvar product` e `is-userspace` fallan: se identifica
  por número de serie. En fastbootd (`is-userspace: yes`) `userdata` «no existe».
- ⚠️ `fastboot -w` también formatea userdata con el `mke2fs` del anfitrión, y el de android-sdk de
  Debian falla («mke2fs failed with status 1»). `20-flashear.sh` hace `erase userdata` y
  `erase metadata`: formatear sobra, userdata se sobrescribe con el rootfs.
- 2026-09-12, primer intento (sobre lo que dejó Ubuntu Touch): el flasheo terminó, pero el bootloader
  rechaza el boot.img de pmOS, flasheado o en RAM: `Failed to load/authenticate boot image: Load Error`.
  No es el árbol de dispositivo: añadirle `qcom,msm-id <0x1db 0x10000>` y `qcom,board-id <0x1000b 0>`
  (los de Yupik QRD, el que usa Nothing) da el mismo error. El dts de mainline no los lleva.
- 2026-09-12: restaurado Nothing OS V3.2 de fábrica con `scripts/15-restaurar-android.sh` (Ubuntu Touch
  solo había dejado `system_a`, `vendor_a` y `odm_a` en super).
- ★ **2026-09-12 17:49: la clave es borrar `vendor_boot`** (y `dtbo`). Con un vendor_boot válido, de
  fábrica o de Ubuntu Touch, el ABL acepta el boot.img v2 («Booting OKAY») pero no se lo entrega al
  kernel: sigue en fastboot con el logo en pantalla. Borrados los dos, `fastboot boot` arranca el
  kernel de pmOS (USB `18d1:d001` «Nothing Phone (1)», red 172.16.42.x). Los ids `qcom,msm-id` y
  `board-id` del DTB NO hacen falta. La wiki solo dice borrar dtbo; la guía de barryC12 borra los dos.
- ✅ **2026-09-12 ~17:55: postmarketOS instalado y arrancando en eut2** (`20-flashear.sh` con vendor_boot
  borrado): kernel 7.2.2, postmarketOS edge, SSH por USB (`edi@172.16.42.1`) a los 32 s del reinicio,
  módem, ADSP, WPSS y CDSP en marcha, el rootfs ocupa todo userdata (218 GB). ⚠️ SSH por USB con un
  `known_hosts` aparte: surya usa la misma IP 172.16.42.1 y otra clave de host.
- ⚠️ Tras UN intento de arranque fallido, este ABL responde «Load Error» a cualquier imagen hasta que se
  reinicia el bootloader (`fastboot reboot-bootloader`): cada prueba en RAM, en una sesión nueva.
- Vuelta atrás: la imagen de fábrica V3.2 por fastboot.

## Reproducir spacewar tal como está (orden de los scripts)

Todo se despliega desde este repo (nada a mano en el móvil, salvo lo de «pasos manuales» de abajo). Orden para dejar
un spacewar recién flasheado como el actual (**revisado el 2026-09-21**: kernel r134, 10 paquetes propios). Cada
script explica en su cabecera qué deja y qué comprueba. Los que llevan `INSTALAR=si` compilan un paquete propio en
ia (`packages/…`) y lo instalan; **simulan antes** y se paran si `apk` fuera a tocar algo más que lo nuestro.

1. **Imagen y flasheo** (sección «Instalar»): `00-preparar-pmbootstrap-ia.sh` (una vez, en ia), `05-copia-particiones-eut2.sh`,
   `10-compilar-imagen.sh`, `15-restaurar-android.sh` (si hace falta) y `20-flashear.sh`.
2. **Base**: `30-sudo-sin-contrasena.sh`, `50-consola-y-arranque.sh`, `55-brillo.sh`.
3. **Kernel con respaldo A/B**: `86-igualar-ranura-b.sh` (una vez), luego `40-compilar-kernel.sh` (en ia, con
   `kernel/*.patch`) y `APK=… 46-instalar-kernel-ab.sh` (`45-instalar-kernel.sh` es el de antes, sin A/B); reiniciar y
   `47-comprobar-arranque.sh`.
4. **Módem y red**: `INSTALAR=si 81-modemmanager.sh` (sin los avisos WDS que lo despertaban),
   `INSTALAR=si 83-networkmanager.sh` (desconecta solo su bearer), `13.` de abajo para la SIM, y la VPN: importarla a
   mano (`/etc/openvpn/egp.conf` + unidad `openvpn-egp`, ver «pasos manuales») y luego `95-vpn.sh`, que deja el
   mandato, el lanzador y la unidad **desactivada al arranque**: la enciende el botón «VPN egp» del panel.
5. **Llamadas**: `60-llamadas.sh` (UCM y voz), `INSTALAR=si 42-callaudiod.sh` (manos libres),
   `INSTALAR=si 43-calls.sh` (buscador de contactos que no se congela; favoritos; números bloqueados),
   `INSTALAR=si 45-agenda.sh` (gnome-contacts: botón «Llamar» y estrella de favorito en la ficha),
   `80-captura-calibracion.sh` (calibración de fábrica; datos privados en `calibraciones/`, nunca públicos) y
   `76-cancelacion-eco.sh` (hexagonrpcd de `packages/hexagonrpcd` + calibración + servicio).
6. **Protección ante actualizaciones**: `62-reparacion.sh`. Los ficheros del UCM viven en
   `/usr/share/alsa/ucm2/Nothing/spacewar/` y **son del paquete** `alsa-ucm-conf-qcom-sc7280`; apk protege
   `/etc` (deja el nuevo como `.apk-new`) pero **no `/usr/share`**, así que una actualización los pisa y se
   pierde la ruta «Voice Call (Bluetooth)»: el móvil deja de pasar las llamadas al casco («tarjeta del movil
   sin perfil Bluetooth», pasó el 2026-11-04). Este script instala `reparar-spacewar.service` (al arrancar) y
   `reparar-spacewar.path` (vigila el directorio), que comparan contra `/usr/local/lib/spacewar/ref/`,
   reinstalan lo que difiera y recargan WirePlumber. Probado: romper `HiFi.conf` → repuesto en <6 s.
7. **Bluetooth en llamada**: `82-firmware-bt-fabrica.sh`, `88-bluetooth-llamada.sh` (HFP, vigilante `hfp-registrado`
   a 15 s y la **pantalla de entrada sin Bluetooth**, que robaba el HFP) y `89-cadena-llamada-bt.sh` (supervisor con el
   acta de cada llamada, WirePlumber, aviso de chip caído).
8. **Cuelgues**: `85-cuelgues.sh` (pstore, detectores, perro-vivo).
9. **Vibración y teclado**: `90-vibracion.sh` (regla de udev para feedbackd), `91-teclado-atajos.sh` (fila de atajos:
   Re Pág/Av Pág, y Ctrl+C, Ctrl+D y Shift+Tab detrás de Alt) e `INSTALAR=si 44-stevia.sh` (sin él, Shift+Tab no se
   dibuja: GTK3 rechaza los atajos con Tab).
9. **Sensores**: `INSTALAR=si 41-iio-sensor-proxy.sh` (sin él, **phosh no tiene rotación automática** tras arrancar: el
   acelerómetro del ADSP llega a los ~86 s y el aviso no se difundía). El script instala además el **retardo de
   arranque** (`--ajuste` a solas): `iio-sensor-proxy` no arranca hasta que el concentrador del ADSP contesta.
10. **Energía**: `92-info-carga.sh` (`info_carga.sh`), `97-bateria-sin-despertar.sh` y `98-bt-uart-sin-despertar.sh`
    (que la batería y el UART del BT no despierten al móvil), `99-ganchos-suspension.sh` (gancho de suspensión,
    volver-a-dormir, contadores glink, interruptor de sensores) y `99-suspension-inactividad.sh`.
11. **Cámaras**: `93-camaras.sh` (v4l-utils, libcamera-tools, quita la antigua lista negra de imx766, calibraciones en
    `/etc/libcamera/ipa/simple`) y `INSTALAR=si 94-libcamera.sh` (libcamera propio con autoenfoque).
12. **Wi-Fi**: `95-wifi.sh` (país España en cfg80211, `iw`).
13. **Datos móviles**: `87-datos-moviles.sh` (perfil de NetworkManager de la SIM puesta: APN, itinerancia nacional,
    conexión automática; sección «Datos móviles») e `INSTALAR=si 84-base-operadores.sh` (base de operadores con
    Pepephone 214-04 corregido).
14. **Waydroid**: `96-waydroid-desde-epo.sh` (red, imágenes, datos e identidad copiados de epo; `SOLO_COMPROBAR=si` primero).
15. **Firefox y WebDAV**: `97-firefox.sh` (vídeo en segundo plano) y `97-webdav-secrets.sh` (credenciales copiadas de epo).
16. **Botones propios en el panel de phosh**: `INSTALAR=si 96-botones-mandato.sh` (phosh propio con el complemento
    genérico «mandato»: botones de **VPN egp** y **Waydroid**; añadir más es solo `gsettings`, sin recompilar).
    Hace falta **cerrar sesión** para que phosh cargue el complemento. Ver `docs/BOTONES-AJUSTES-RAPIDOS.md`.
17. **Signal (flare)**: `INSTALAR=si 48-flare.sh` (el flare de la tienda, 0.20.4-r0, **no conecta**: Signal cambió la
    API; se compila la 0.22.2 del git). Necesita el servicio de secretos (libsecret/gnome-keyring) para las credenciales.
18. **Comprobar**: reiniciar y `sh scripts/verificar-instalado.sh` — todo lo de `device/MANIFIESTO.tsv` con su md5 y los
    paquetes propios con nuestro `-rN`. Repetirlo **después de cada `apk upgrade`**.

**Pasos que siguen siendo manuales, a propósito**:
- (Hasta el 2026-09-14, tras cada arranque había que cargar a mano `imx766`; ya no: se carga sola.) Si la app no ve
  las cámaras, reiniciar wireplumber **fuera de llamada** (`systemctl --user restart wireplumber`).
- Wi-Fi, contraseña del usuario y cuentas: se configuran en el móvil, no van al repo.
- Pruebas y medidas (`pruebas/`): no dejan nada instalado salvo lo que dice su cabecera (`descargar.sh` instala
  stress-ng de la distribución).
- **VPN**: el perfil `egp` **no está en el repo y no debe estarlo** (servidor y claves). En un sistema limpio se
  importa a mano en NetworkManager: `sudo nmcli connection import type openvpn file <fichero.ovpn>`. Después,
  `sh scripts/95-vpn.sh` deja los ajustes (ver sección «La VPN, gestionada por NetworkManager»).
  ⛔ Recordatorio: nunca matar `openvpn` en epo (surya).
- **`openscq30-gui`** (control de los auriculares, binario de terceros en `/usr/local/bin`, 39 MB): se instala a
  mano desde su propio proyecto; no se versiona aquí.

**Auditoría de reproducibilidad (2026-09-18)**: cotejadas por md5 **36 piezas** instaladas en el móvil contra el
repo — **todas idénticas**: 3 UCM, 3 `.conf` y 3 `.lua` de wireplumber, 5 reglas udev, 3 de `modprobe.d`/
`sleep.conf.d`, 11 unidades de sistema, 3 de usuario, 5 binarios propios, más el `KernelExperimental` de
`/etc/bluetooth/main.conf`. Para repetirla: comparar `md5sum` de lo instalado con el fichero de `device/` que le
corresponde. Detalles que despistan y **no son fallos**:
- `/usr/share/alsa/ucm2/conf.d/sm8250/NP1.conf` es un **enlace simbólico** a `../../Nothing/spacewar/NP1.conf`.
- Los `.lua` propios van a **`~/.local/share/wireplumber/scripts/`** (no a `~/.config/wireplumber`), y tienen
  prioridad sobre los del sistema: `/usr/share/wireplumber/scripts/device/find-voice-call-profile.lua` existe y
  es **del paquete** `wireplumber-0.5.17-r0`, no un residuo nuestro.
- Cruzar `device/` contra `scripts/` **por nombre de fichero da falsos positivos**: los `.yaml` se copian con
  `*.yaml`, `consumo-reposo-muestra.sh` lo usa `pruebas/`, `test_supervisor.py` no se instala y
  `offload-codecs.conf` es un fragmento cuyo contenido aplica el script sin nombrarlo.

## Sonido (2026-09-12, prioridad del usuario)

Tras instalar, las llamadas se establecen pero no hay audio, ni en llamada ni fuera. Diagnóstico:

- La tarjeta `NP1` existe (máquina sm8250, `qcom,sm7325-sndcard`) y los dos TFA9873 (i2c 2-0034 y
  2-0035) tienen driver. El DSP sirve audio por **APR** (q6afe/q6asm/q6adm), la misma familia que surya.
- ⛔ **El kernel de pmaports (7.2.2) solo trae dos dai-links** (I2S Playback a los TFA y MultiMedia1): el
  códec WCD9385, las soundwire (`3210000`, `3230000`, `3250000`) y los macros LPASS (`3200000`,
  `3220000`, `3240000`, `3370000`) están `disabled` en su DT, y el mezclador solo tiene 20 controles
  (ni siquiera `PRI_MI2S_RX Audio Mixer MultiMedia1`).
- El UCM instalado (`alsa-ucm-conf-qcom-sc7280`, `conf.d/sm8250/NP1.conf` → `Nothing/spacewar/HiFi.conf`)
  espera la cadena completa (WCD, rx-macro, rutas de MultiMedia1/2/3): falla y PipeWire solo ofrece
  «off» y «pro-audio», sin salidas.
- La cadena completa está en las ramas de los mantenedores de `mainlining/linux`
  (`danila/spacewar-next`, `fekz115/spacewar-6.19`): WCD9385 por SWR0/SWR1, RX/TX/VA en `okay`,
  dai-links MultiMedia1-3, I2S (TFA) y WCD playback/capture, `nothing,spacewar-sndcard`. Ninguna trae
  nodos de voz: las llamadas saldrán del trabajo de q6voice de surya.
- Plan: llevar esos commits de audio como parches encima del kernel de pmaports (como en surya).

## USB y red por cable (2026-09-12)

postmarketOS ofrece red por USB con **NCM** (el móvil en 172.16.42.1; bpi lo carga con `cdc_ncm`):
no hace falta RNDIS, que solo es para Windows. Pero **el USB solo entra en modo dispositivo si el
cable está enchufado durante el arranque** (problema conocido de la wiki: el ADSP avisa del cable por
glink solo al arrancar).

- Enchufado con el sistema ya en marcha, bpi no ve nada: `/sys/class/udc/*/state` = `not attached`
  aunque `/sys/class/usb_role/*/role` diga `device`.
- Ni forzar el rol (`none` → `device` en `/sys/class/usb_role/*/role`) ni volver a enchufar lo
  despiertan.
- Lo que funciona: **reiniciar con el cable ya enchufado**.
- El Wi-Fi va a trompicones con el kernel de pmaports y el r100 (le falta `calibration-variant`,
  que trae el r101); NetworkManager tiene el ahorro de energía en «default».

## Estado del sonido (2026-09-12 19:30)

- ✅ **Altavoces en estéreo** con el kernel r103: parche 0007 (cada TFA9873 con su `sound-channel` y
  `sound-name-prefix`). Probado con tonos por canal: el izquierdo sale por el de arriba y el derecho
  por el de abajo.
- ✅ PipeWire con perfil HiFi (Headphones, Mic1, Speaker) desde r102 (orden de los PCM, parche 0001).
- ⏳ Llamadas: cadena de voz de surya portada (0008-0013, r105 compilándose): q6voice/cvp/cvs/mvm,
  SLIMBUS_7, sm8250, hci_qca, controlador SLIMbus fusionado y árbol de voz. Falta el perfil de llamada
  (UCM) y el Bluetooth por SLIMbus. En Android de fábrica el SCO va por SLIMBUS_7.
- ✅ 19:45 **r105 instalado** (por Wi-Fi): el ADSP registra los 7 servicios APR (core, afe, asm, adm,
  mvm, cvs, cvp); PCM «CS-Voice» en hw:0,3; mezcladores de voz presentes.
- ✅ `scripts/60-llamadas.sh` desplegado: `/usr/share/q6voiced/q6voiced.conf` (la unidad de q6voiced lee
  ese fichero, no `/etc/conf.d`), q6voiced activo, perfil «Voice Call» en el UCM (Earpiece, Speaker,
  Bluetooth). ⏳ Falta la prueba con una llamada real. Auricular y altavoz aún suenan igual.
- ⚠️ Tras reiniciar, PipeWire del usuario no arranca hasta iniciar sesión en el greeter (PIN).
- ✅ 19:55 **Brillo alto al arrancar** (`scripts/55-brillo.sh`, `device/brillo/`): systemd-backlight
  restauraba 160 de 4095. Como en surya: se restaura tarde (12 s tras greetd) lo último guardado (al
  apagar y cada minuto por temporizador); sin nada guardado, el máximo. La unidad cuelga de
  `graphical.target` y solo va `After=greetd.service`: con `After=graphical.target` + `WantedBy=` un
  target hay ciclo de orden y systemd no la ejecuta (le pasaba a la de surya). El script lo comprueba.
- ✅ 19:57 **r106 instalado** (0014): «Earpiece Output Switch» / «Speaker Output Switch» en el tfa9872
  (encendidos por defecto); el perfil de llamada Earpiece apaga el de abajo y Speaker el de arriba.
  UCM desplegado. Brillo restaurado solo al arrancar (4095). ⏳ Falta probar una llamada real.
- ✅ 20:11 **Llamadas con audio** (entrante; «ahora sí suena»). La primera (20:05) fue muda por la
  carrera de q6voiced: abre el PCM CS-Voice 3 ms tras `active`, antes de que PipeWire pase al perfil
  Voice Call, y sin ruta de captura el kernel da EINVAL («Failed to open tx: Invalid argument»). Como
  en surya, las rutas `PRI_MI2S_RX Voice Mixer CS-Voice` y `CS-Voice Capture Mixer TX_CODEC_DMA_TX_3`
  van siempre encendidas (HiFi.conf en el repo + VoiceCall.conf). En la buena: sesión MVM «11C05000»,
  cvp tx_port TX_CODEC_DMA_TX_3 / rx_port PRI_MI2S_RX, topologías 0x10f70/0x10f77, perfil Voice Call
  (Earpiece) aplicado a los 0,5 s. `VSS_IVOLUME_CMD_SET_STEP` (0x112c2) falla con error 1 sin tabla
  de volumen (en surya igual: el volumen de llamada va por el amplificador).
- ✅ 21:1x **Micrófonos: nunca habían grabado.** Con el UCM del paquete alsa-ucm-conf-qcom-sc7280 todos los
  micros van por el decimador 1 (DEC1) y `arecord hw:0,2` da «read error: I/O error» dentro y fuera de
  llamada, aunque todo prepara y arranca con 0 (kretprobes en SoundWire, `q6afe_port_start`,
  `q6asm_open_read`, `dpcm_*_prepare`, `q6asm_run_nowait`). Las tomas del DSP lo confirmaron: subida de
  spacewar (VOC_REC_UL) y bajada de surya (VOC_REC_DL) con pico 0. Por **DEC0**, como Fairphone 5 (mismo
  SoC y WCD9385), graban el de arriba y el de abajo. Además el paquete ponía `TX1 MODE` a ADC1
  (TX0=ADC1 … TX3=ADC4). HiFi.conf y VoiceCall.conf corregidos; DEC1 apagado en los dos verbos.
  Los `ADCn Switch` siguen siempre encendidos (puertos SoundWire leídos solo en hw_params).
- ✅✅ 21:42 **TE OYEN (llamada por auricular).** Llamada automática spacewar → surya: la bajada de surya
  (pico 6787), la toma de subida de spacewar (7453) y el micro de spacewar antes del vocproc (3544) llevan
  el mismo sonido: correlación de envolventes micro ↔ bajada de surya **0,97** con 0,35 s de retraso de
  red, micro ↔ toma de subida 0,99. Antes: silencio digital (DEC1) o solo ruido (micro equivocado).
- ✅✅ 21:48 **Llamada desde arranque en frío (r111), por auricular: el tono de 1 kHz pulsado que suena en
  spacewar se reconoce en su micro, en su subida (toma del DSP) y en la bajada de surya** (correlación
  micro ↔ bajada 0,86, 0,35 s). Prueba reproducible: `SALIDA=… ALTAVOZ=0 bash pruebas/llamada-subida.sh`.
- ✅ 23:08 **Cancelación de eco activa** (r113 + `scripts/76-cancelacion-eco.sh`): topologías propias registradas,
  vocproc V3 con las cuatro calibraciones de fábrica registradas con 0 y la llamada con audio en los dos
  sentidos. Primera medida (`pruebas/llamada-eco.sh`, tono desde surya, spacewar en manos libres, **móviles
  juntos**): tono en la subida de spacewar 180 (ON) frente a 186 (OFF), entre pitidos 1,0 frente a 2,0; en la
  bajada de surya 156 frente a 171, entre pitidos 1,5 frente a 2,8. El tono baja poco (−0,3/−0,8 dB) y el
  resto se reduce a la mitad: con los móviles juntos domina la fuga acústica directa del auricular de surya
  al micro de spacewar, que ninguna canceladora quita.
- ✅ 23:45 **Con los móviles en habitaciones distintas y la calibración de manos libres** (el UCM ahora pone
  «Voice Calibration» Handset/Speaker según el dispositivo; antes usaba siempre la del auricular), cancelación
  encendida frente a apagada: en la subida de spacewar −10,2 dB de nivel con pitido, −13,2 dB entre pitidos
  y −21 dB en picos; en lo que le vuelve a surya −9,4 / −11,1 / −25 dB. **El tono puro de 1 kHz solo baja
  ~3 dB** (surya: −23 dB con el mismo tono). Pendiente: medir el ERLE exacto con la toma estéreo subida+bajada
  (`q6cvs rec_mode=0x10F7A`) y revisar la referencia del eco (RX a 2 canales hacia los TFA9873, que tienen
  DSP propio) y el micro (AMIC3 frente al dmic4 de fábrica).
- ⏳ 23:0x **Cancelación de eco (como surya)**: calibración de voz de fábrica capturada con el cargador de
  Qualcomm bajo el linker de Android (`scripts/80-captura-calibracion.sh`, datos en `calibraciones/`, privados)
  y convertida a firmware; topologías de Nothing: manos libres TX 0x10000003 / RX 0x10010F8B (como surya),
  auricular TX 0x1000BFF1 (2 canales) / RX 0x1000BFF2 con módulos propios 0x1000B500/B501. Piezas: kernel r113
  (q6voice `cal_dir`; fastrpc devuelve el heap remoto a HLOS), hexagonrpcd 0.4.0.100-r13 (PD de audio),
  `device/eco/` (PD de audio, -R del dominio raíz, relanzar tras suspender, servicio) y
  `scripts/76-cancelacion-eco.sh`. ⚠️ En la pantalla de bloqueo el móvil se suspende y hexagonrpcd se quedaba
  parado al volver.
- ⚠️ 22:0x **Volumen de llamada: los dos registros de ganancia del TFA9873 casi no mueven el nivel.** Medido
  con tono por el altavoz y el micro de abajo: AMPGAIN (0x52, «Amp Gain Volume», r108) de 190 a 100 =
  −4,4 dB; TDMSPKG (0x61, «Total Gain Volume», r112) de 6 a 0 = sin cambio (±0,5 dB). El paso de volumen
  del DSP (VSS_IVOLUME_CMD_SET_STEP) necesita la tabla de la calibración de fábrica. Pendiente.
- ✅ 21:44 **Botón de manos libres** (callaudiod r100 con el parche de surya, `scripts/42-callaudiod.sh`):
  `callaudiocli -s 1`, lo mismo que el botón del marcador, pasa al perfil Voice Call (Speaker) con el
  altavoz de abajo y el micro de arriba; la voz llega a surya (correlación micro ↔ bajada 0,91, sin
  saturación). Con los dos móviles juntos y sin cancelación de eco, acopla.
- ✅ 21:4x **Qué micro es cuál** (tono de 1 kHz al 30 % por un solo amplificador, `pruebas/barrido-micros.sh`):
  **AMIC1** (ADC1, `SWR_MIC0`) es el de **abajo** (2904 con el tono abajo, 386 arriba) y **AMIC3**
  (ADC2 `INP3`, `SWR_MIC1`) el de **arriba** (196 / 655). Por ADC3 `INP4` / ADC4 `INP5`, que el paquete
  daba como micro de abajo y trasero, no llega sonido. El Android de fábrica usa micros digitales del
  WCD9385 (`mixer_paths.xml` de Nothing: `handset-mic` = dmic1 → `SWRM_TX3_CH1`, `speaker-mic` = dmic4 →
  `TX3_CH4`); con mainline no dan audio ni con `tx-port-mapping <1 2 3 4>` (r110): pendiente. Llamada:
  auricular con el de abajo, manos libres con el de arriba (~23 dB menos acople del altavoz).
- ⚠️ r110: `amixer -c0` falla (remapeo UCM de `sysdefault`); los scripts usan `amixer -D hw:0`.
- ✅ 21:47 **r111**: wcn-bt-slim se autocarga (`MODULE_DEVICE_TABLE(slim, …)`: con `slimbus` modpost no
  generaba alias) y la tarjeta se registra a los 13,8 s en vez de 101 s. Antes, el PipeWire de greetd
  arrancaba sin tarjeta y se quedaba con la reproducción atascada hasta reiniciarlo. BT sigue UP; el chip
  aún no aparece en el SLIMbus («chip never showed up on the bus»): BT en llamada, pendiente.
- 🔧 **Banco de pruebas de llamadas** (`pruebas/llamada-subida.sh`): spacewar llama a surya, surya descuelga
  sola, spacewar pone un tono pulsado (30 %) por el sumidero de la llamada, y se graban la subida de
  spacewar y la bajada de surya con las tomas del DSP (r109: enlaces backend voice-rec en el DT). El
  número sale de la configuración privada de surya y nunca va en una línea de órdenes.
## Llamadas sin Bluetooth: estado final (2026-09-13)

Probado por el usuario en llamada real por auricular: **«ahora funciona bien»**.

> ⚠️⚠️ **(17-09) HAY UN FALLO INTERMITENTE, PERO LA CAUSA SIGUE SIN ENCONTRARSE.**
> Usuario: «cuando está sin bluetooth y llaman se oye por el altavoz de abajo, no por el auricular», y en una
> llamada de prueba «no oí nada». Después, dos llamadas seguidas se oyeron **bien y por el auricular**.
>
> ❌❌ **TEORÍA DESCARTADA (la escribí aquí como «causa demostrada» y era FALSA): «q6voiced abre el PCM una sola
> vez por arranque y por eso la segunda llamada sale muda».** El recuento era correcto, pero **irrelevante**: el
> 17-09 a las 13:33 una llamada **sin ninguna apertura del PCM se oyó perfectamente** (`call5`, 1 sola apertura
> en toda la sesión, a las 13:32 para `call4`). **Correlación, no causa.** Abrir el PCM no hace falta para oír.
>
> El recuento, que sigue siendo cierto pero no explica nada: `q6voiced` abre el PCM de voz una sola vez por
> arranque — **61 arranques**, 23 aperturas, nunca más de una.
> ```
> 16-09 13:16 call0 → "PCM devices were opened" ✔    (q6voiced arrancó a las 11:57)
> 16-09 16:47 call2 → nada                      ❌
> 17-09 12:22 call0 → "PCM devices were opened" ✔    (q6voiced arrancó a las 00:28)
> 17-09 12:51 call3 → nada                      ❌    (llamada MUDA, confirmada por el usuario)
> ```
> Por días: 14-09 **2/2**, 15-09 **3/3** (con reinicios de por medio), 16-09 **1 de 2**, 17-09 **1 de 2**.
> **No es regresión del kernel r134** (empezó el 16-09) ni tiene relación con el trabajo de consumo.
> `q6voiced` **nunca registra un cierre** y en la segunda llamada **no registra ni un error**: no reacciona.
> Escucha `interface='org.freedesktop.ModemManager1.Call'` / `StateChanged` — filtro por interfaz, no por
> objeto, así que la señal de `call3` sí le llega. Hipótesis: **conserva estado interno de la llamada anterior**.
>
> ⏭️ **Arreglo candidato: reiniciar `q6voiced` AL COLGAR** (nunca en llamada). Pendiente de confirmar.
>
> ⛔ **NO portar el parche 0003 de callaudiod de surya** (`superados/0003-stop-the-voice-session-*.patch`), que
> hace justo eso desde callaudiod: está archivado porque **ROMPÍA TODAS las llamadas** — «se quedaron sin audio
> en ambos sentidos y el botón de altavoz dejó de funcionar […] perseguí durante HORAS el DSP, el módem… cuando
> la causa era mi propio binario». Además aquí no existe la regla de sudoers que necesitaría.
>
> **Descartado con pruebas** (no repetir): el UCM es correcto (`alsaucm … set _enadev 'Earpiece'` apaga el
> altavoz, `numid=106` → off; md5 del fichero instalado igual que el del repo); los controles `numid=105/106`
> existen, responden y nadie los revierte; las rutas de voz están **siempre encendidas** y el PCM `closed` y
> libre; el supervisor BT solo observa (sus `P_MOVIL_ALTAVOZ` son comparaciones) y de hecho **interpreta el
> altavoz como «lo has pedido tú con el botón»**; `callaudiod` da `CALL_AUDIO_SPEAKER_OFF` y **nadie llamó a
> `EnableSpeaker`** en el D-Bus capturado; `gnome-calls` no tiene ajuste de altavoz; WirePlumber no guarda
> ningún perfil «Voice Call»; y el `Failed to create ALSA node … proxy destroyed` es ruido de transición.
>
> ⚠️ **Lo del ALTAVOZ sigue sin explicar y puede ser otro fallo distinto.** En la llamada de las 12:22 (que sí
> tenía audio) el perfil entró bien y **1,6 s después saltó solo**, sin que nadie lo registrara:
> ```
> 12:22:27.95  'HiFi (…)'              -> 'Voice Call (Earpiece)'
> 12:22:29.58  'Voice Call (Earpiece)' -> 'Voice Call (Speaker)'
> ```
> Con la sonda puesta (12:51) **no se reprodujo**: se mantuvo en auricular con `speaker=off` los 8,5 s.
> Herramienta lista: `pruebas/llamada-quien-pone-altavoz.sh` (espera al móvil, sondea el perfil a 0,2 s y
> registra el tráfico D-Bus hacia callaudiod).
> Esto ya estaba anotado el 13-09 y **nunca se verificó**: «⏳ Falta la prueba con una llamada real. Auricular y
> altavoz aún suenan igual».

| pieza | qué hace | dónde |
|---|---|---|
| Volumen de llamada | el DSP acepta `VSS_IVOLUME_CMD_SET_STEP` (pasos 0-6) pero **no cambia el nivel** (medido: pasos 6 y 0 alternos, ±1 dB). Lo que cambia entre pasos en la tabla de fábrica es la ganancia Q13 del módulo de volumen de bajada (0x10EF5 / parámetro 0x10E12), 3 dB por paso: el kernel la manda con `SET_PARAM_V2` junto con el paso. El control es «Voice Rx Playback Volume» (0-6) y el UCM se lo da a PipeWire (`PlaybackMixerElem "Voice Rx"`) | kernel r115 (0029, 7 pasos) y **r116 (0030)**; `VoiceCall.conf` |
| Oírse a sí mismo / acople | la calibración de **auricular** de fábrica es para las topologías propias de Nothing (TX 0x1000BFF1 / RX 0x1000BFF2), que no corremos: sobre las de manos libres (TX 0x10000003 / RX 0x10010F8B) metía el micro en la salida (`pruebas/sidetone-medida.sh`: ruido entre pulsos 7990 con Handset, 26 con Speaker; en los dos órdenes). **Se usa la de manos libres en los dos modos** y la llamada ya arranca con ella | `VoiceCall.conf` (Earpiece → `Voice Calibration` Speaker), `device/eco/activar-cancelacion-eco.sh` (`CAL_SET=speaker`) |
| Silencio del micro | `Voice Tx Capture Switch` (VSS_IVOLUME_CMD_MUTE_V2 en el flujo): silencio digital al otro lado. PipeWire solo lo arma por hardware con `CaptureMixerElem "Voice Tx"`, y hubo que quitar el `ctl-remap` del paquete | `NP1.conf`, `VoiceCall.conf` |
| Cancelación de eco | en auricular, sin rastro de la voz de surya en la subida de spacewar (`pruebas/llamada-eco-voz.sh`: correlación de envolventes 0,07). Manos libres sin medir con la calibración actual | r113+, hexagonrpcd r13, `scripts/76-cancelacion-eco.sh` |

Cómo se midió (y trampas): `scripts/diag-volumen-silencio.sh` (kprobes: el volumen y el silencio llegan al DSP y
qué contesta), `pruebas/llamada-grafo.sh` (PipeWire no lleva el micro al auricular), `pruebas/llamada-volumen.sh`
(voz grabada, no tonos: la supresión de ruido del vocproc los trata como ruido; con `CORTAR_BUCLE=1` y referencia
alineada con la subida de surya). ⛔ **Nunca con surya o spacewar en manos libres**: se acoplan y hacen mucho ruido
en casa del usuario. Surya va conectada al Bluetooth de ia (`pruebas/banco-bt/ia-casco-de-surya.sh`).

### Diferencias con surya en llamada sin Bluetooth

| | surya (POCO X3 NFC, SM7150) | spacewar (Nothing Phone (1), SM7325) |
|---|---|---|
| Kernel | 7.1-rc3 (r93) | 7.2.2 (r116) |
| Códec / amplificadores | WCD9375 / 2 × TAS2562 por `TERT_MI2S_RX` | WCD9385 / 2 × TFA9873 por `PRI_MI2S_RX` |
| PCM de voz y señuelos | CS-Voice `hw:0,4`; MultiMedia3 (rep.) y MultiMedia2 (cap.) | CS-Voice `hw:0,3`; MultiMedia1 (rep.) y MultiMedia3 (cap.) |
| Auricular / manos libres | `ASI1 Sel` y volumen digital de cada ampli | `Earpiece/Speaker Output Switch` (0014) |
| Volumen | volumen digital del ampli (después del DSP) | ganancia del módulo de volumen del DSP (0030): el TFA9873 casi no tiene ganancia útil |
| Micros | uno analógico (ADC1) | analógicos AMIC1 (abajo, auricular) y AMIC3 (arriba, manos libres) por DEC0; los digitales de fábrica no dan audio con mainline |
| Calibración de voz | la de Xiaomi por dispositivo (Handset / Speaker) | Speaker en los dos |
| Silencio | `CaptureSwitch` | `CaptureMixerElem "Voice Tx"` y sin `ctl-remap` |

Igual en los dos: rutas CS-Voice y puertos SoundWire de los micros siempre encendidos (q6voiced abre la voz
antes que el perfil), PCM señuelo para que PipeWire aplique el perfil, cancelación de eco del DSP con el PD de
audio servido por hexagonrpcd, y la voz nunca pasa por la CPU.

## Datos móviles: perfil de la SIM (2026-09-14)

La SIM del usuario es de **Pepephone** (SIM 214-04, Yoigo; se registra en Orange, 214-03, y puede caer a Movistar).
Configuración oficial (<https://www.pepephone.com/configura-tu-movil>): APN `internet`, MCC 214, MNC 04, sin usuario
ni contraseña. La base `mobile-broadband-provider-info` del sistema está desfasada (trae Pepephone como 214-06 con
`gprs.pepephone.com`; upstream igual a 20251101). Corregida con un paquete propio:
`packages/mobile-broadband-provider-info` (receta de Alpine + `0001-Spain-Pepephone-update-network-ID-and-APN.patch`,
en formato git para mandarlo upstream), compilado e instalado con `INSTALAR=si sh scripts/84-base-operadores.sh`.

Tras el cambio de SIM, NetworkManager tenía dos perfiles «Default»: el de conexión automática llevaba el `sim-id` de
la SIM anterior («No suitable device», se borró a petición del usuario) y el de la SIM actual tenía `autoconnect=no`
y `home-only=yes`. `sh scripts/87-datos-moviles.sh` deja el perfil de la SIM puesta con APN `internet`,
`home-only no` (itinerancia nacional) y conexión automática, sin guardar el ICCID en el repo (lo lee en el móvil).
⚠️ Batería: con datos, NetworkManager los corta al dormir y el módem despierta al SoC (ver la tabla de consumos).

## Cuelgues: instrumentación y arranque con respaldo A/B (2026-09-13)

El 2026-09-13 spacewar se congeló (descarga de mapas con OSM Scout Server mientras se instalaba un kernel,
escritura fuerte) sin dejar rastro: ni detectores, ni volcado persistente, ni perro guardián. Desde **r120**:

| pieza | qué hace | dónde |
|---|---|---|
| ramoops | consola y pmsg del kernel en la memoria reservada (`ramoops@83a00000`, ya en el DT); tras reiniciar, `systemd-pstore` lo archiva en **`/var/lib/systemd/pstore/`** | config `PSTORE_RAM/CONSOLE/PMSG` |
| detectores | bloqueo blando y duro (variante *buddy*: este SoC no tiene NMI) con pánico, pilas de todas las CPU; tareas colgadas > 120 s con traza y **sin** pánico (en surya el pánico por tarea colgada hacía bucles de reinicio); `panic_on_oops`, reinicio 10 s tras el pánico; consola a nivel 7 para que las pilas lleguen a ramoops; SysRq de volcado | config `SOFTLOCKUP_DETECTOR`, `HARDLOCKUP_DETECTOR`, `DETECT_HUNG_TASK`, `MAGIC_SYSRQ`; `device/cuelgues/90-cuelgues.conf` |
| perro guardián | el watchdog APSS lo tiene el hipervisor Gunyah: `/dev/watchdog` = «Gunyah Watchdog» (margen 32 s). El firmware anuncia SMCCC v1.0 y `qcom_scm` no lo registraba: **0032** lo registra en spacewar. Lo coge `perro-vivo` (de surya) en el arranque y solo lo acaricia si el móvil crea procesos y escribe en disco con fsync | config `GUNYAH_WATCHDOG`; `device/cuelgues/perro-vivo.*`, `watchdog.conf` (systemd no lo abre) |
| diario | persistente, 2 G, volcado a disco cada 30 s | `device/cuelgues/90-retencion.conf` |

Despliegue: `scripts/85-cuelgues.sh` (y reiniciar: el traspaso del perro solo es seguro en el arranque). Tras un
cuelgue: `ls /var/lib/systemd/pstore/`, `journalctl -b -1`, `journalctl -u perro-vivo`. ⚠️ Si se congela, esperar
~2 min antes de forzar el apagado (pánico por detector + 10 s, o mordisco del perro a los 30-60 s). No se usa kdump
(exige `crashkernel=` en la línea de arranque).

**Primer cuelgue cazado (2026-09-13 22:23, r122, a los 318 s): la GPU, no el audio.** Secuencia en
`journalctl -b -1 -k`:
1. La GMU de la Adreno deja de responder: `a6xx_gmu_set_oob ... Timeout waiting for GMU OOB set GPU_SET`.
2. Fallo de la GPU: `gpu fault ring 0`, traducción de la iova 0 desde el CP, tarea `phoc`. Arranca
   `hangcheck recover`.
3. La interrupción global del SMMU se dispara en bucle y el kernel la desactiva (`irq 22: nobody cared`).
4. Bloqueo mutuo:
   - `gpu-worker` (recover_worker → a6xx_recover → runtime suspend → `a6xx_gmu_stop`) espera a la GMU con
     `wait_for_completion`, sin plazo y con el cerrojo de la GPU cogido;
   - `irq/23-arm-smmu` (`msm_gpu_fault_crashstate_capture`) y `drm_sched_run_job_work` esperan ese cerrojo;
   - `phoc` (`adreno_get_param` → `rpm_resume`) espera al apagado que nunca acaba. La pantalla queda congelada.

El sistema seguía vivo (ssh entraba). Por eso **ni el perro ni los detectores reiniciaron**: las tareas colgadas
solo dejan traza, y perro-vivo mira procesos y disco, no el compositor. Es el único caso en los 15 arranques del
diario, y el arranque de la congelación con OSM Scout no tiene nada de la GPU. **Decisión del usuario (2026-09-13):
se deja como está** (`hung_task_panic=0`, sin comprobación de `phoc` en perro-vivo). Si se repite, queda la traza
en el diario. Las alternativas descartadas por ahora eran `kernel.hung_task_panic=1` (reinicio con ramoops, pero
también ante un bloqueo largo legítimo) y vigilar `phoc` en estado D desde perro-vivo.

**Respaldo A/B.** El ABL arranca `boot_<ranura activa>` sin menú. `scripts/86-igualar-ranura-b.sh` dejó el firmware
de `_b` igual que el de `_a` (tenía otro Android de fábrica, con el dtbo de Android). `scripts/46-instalar-kernel-ab.sh`
copia el boot que funciona a la otra ranura, guarda y restaura sus módulos (cada kernel con `LOCALVERSION -rN`, su
`/lib/modules/7.2.2-rN`), instala el nuevo y deja la ranura activa sin confirmar (`qbootctl -s`): si no llega al
sistema, el ABL vuelve al anterior; si llega, `qbootctl.service` la confirma. Estado (2026-09-14 00:14): r126 en
`_a`, r125 en `_b`.

### Cuelgue en suspensión por IPA (2026-09-14)

Con el móvil inactivo toda la noche (SIM con datos móviles conectados además de la Wi-Fi):

- **05:20**: el driver **IPA** (datos móviles) se autosuspende (500 ms sin tráfico) y pide al módem parar un canal:
  `ipa_runtime_suspend → ipa_modem_suspend → gsi_channel_suspend → __gsi_channel_stop → wait_for_completion`. La
  confirmación no llega nunca: tarea `kworker` en estado D, «blocked for more than 120 seconds» cada 2 min. Sin
  ningún aviso previo del módem, ModemManager ni NetworkManager en el diario.
- **07:01**: el sistema entra en suspensión profunda y se congela dentro (ramoops termina en «Suspending
  console(s)»). El perro guardián de Gunyah se detiene al suspender, así que nadie reinicia: hasta el reinicio a mano.
- **Instrumentación** (`scripts/85-cuelgues.sh`):
  - ~~`device/cuelgues/consola-en-suspension.conf` (tmpfiles, `console_suspend=N`): ramoops sigue escribiendo al
    suspender.~~ ⛔ Retirado el mismo día: forzaba un cambio de consola virtual en cada suspensión y mataba phosh
    (ver «phosh moría en cada suspensión»).
  - `device/cuelgues/vigia-ipa.sh` + `vigia-ipa.service`: cada 30 s busca una tarea en D con
    `ipa_runtime_suspend`/`__gsi_channel_stop`; si la ve, foto del estado en `/var/lib/cuelgues/ipa-*.txt` (pila, energía
    de IPA, remoteprocs, módem sin números, rmnet, NetworkManager, kernel), **bloquea la suspensión** (no se congela) y
    avisa en pantalla para reiniciar. `PRUEBA=1` recorre el aviso sin atasco.
  - Para el próximo kernel, en la configuración: `CONFIG_PM_DEBUG`/`PM_SLEEP_DEBUG` (ver en qué dispositivo se para
    la suspensión) y `CONFIG_DPM_WATCHDOG` (120 s: un dispositivo que no termina de suspenderse provoca un pánico con su
    pila en ramoops y un reinicio, en vez de un móvil congelado para siempre).
- `hung_task_panic` sigue a 0 (decisión del usuario).
- Comparado con `danila/spacewar-next`: `ipa_power.c` es idéntico y ningún commit de `drivers/net/ipa` toca la espera
  de `gsi_channel_trans_quiesce`. No hay arreglo conocido: el remedio sería un plazo en esa espera (parche propio).

### Congelado del disco tras volver a entrar en la sesión (2026-09-14 11:16)

Secuencia (ramoops en `/var/lib/systemd/pstore/console-ramoops-0` + `journalctl -b -1`):

1. **11:15:02**: la suspensión profunda se aborta («Wakeup pending») y systemd cae a **s2idle**; despierta a las
   11:15:03 (errores I2C de los dos motores de enfoque al reanudar, inocuos).
2. La pantalla pinta mal («transparente», según el usuario). En el kernel solo aparece `dsi_err_worker: status=5`
   (11:15:23), que sale también en cada arranque al entrar en la sesión. **Ningún error de la GPU** (ni GMU ni
   `hangcheck`), a diferencia del cuelgue del 2026-09-13.
3. **11:15:40-57**: se sale y se vuelve a entrar en la sesión (phrog). `gnome-calls` del greeter revienta al cerrarse
   (SEGV en GTK, inocuo).
4. **11:16:00-06**: tormenta de disco del inicio de sesión; el diario deja de escribir a las 11:16:06.
5. **11:16:10**: perro-vivo, «PRUEBA DE DISCO FALLIDA (1/2)»; 11:16:50 la 2/2; deja de acariciar y el perro de
   Gunyah reinicia.

Sin pilas: el perro reinició a los ~70 s y el detector de tareas colgadas avisa a los 120 s. La firma (disco muerto
con el kernel vivo, en plena tormenta de E/S) es la del **abrazo mortal del UFS de surya** (2026-08-23, capturado
entero): `ufshcd_devfreq_scale` quiere `clk_scaling_lock` para escribir mientras `ufshcd_exception_event_handler` lo
tiene como lector esperando al chip. El 7.2.2 tiene el mismo cerrojo y spacewar tenía el escalado activo
(`simple_ondemand`, 75/150/300 MHz).

- **Mitigación** (`scripts/85-cuelgues.sh`): `device/cuelgues/99-ufs-sin-escalado.rules`, `clkscale_enable=0` en
  `1d84000.ufshc`, también en caliente. Medido al aplicarlo: el reloj se queda en 75 MHz, sin transición (como en
  surya), aunque el código del 7.2.2 intenta subirlo al máximo al desactivar. Queda por ver si baja la velocidad del
  disco y confirmarlo en la medida de consumo en reposo. Revertir:
  `echo 1 > /sys/devices/platform/soc@0/1d84000.ufshc/clkscale_enable`.
- **Instrumentación**: perro-vivo vuelca las tareas bloqueadas con su pila (`SysRq w`) a ramoops al primer fallo de
  cada racha (disco o vida). Si se repite con la mitigación puesta, no era el UFS y las pilas lo dirán. El guion se
  cambia por renombrado atómico y el perro en marcha no se reinicia: vale desde el próximo arranque.
- `/var/lib/cuelgues/ipa-20260914-110642.txt` es la prueba del vigía (`prueba=1`), no un atasco real.

### ⛔ phosh moría en cada suspensión: lo causaba `console_suspend=N` (2026-09-14)

La sesión que se cerraba sola al despertar (11:15, 12:28, 13:22 con gsd-power, y 12:35/12:52/12:54 con las pruebas
de fases) no era cosa de s2idle ni del UART del BT: la **metió la instrumentación de cuelgues**. A las 11:06
`consola-en-suspension.conf` puso `console_suspend=N`, y en el kernel (`kernel/power/console.c`, `pm_vt_switch()`)
eso **fuerza el cambio de consola virtual al suspender** (`vt_move_to_console(SUSPEND_CONSOLE)`) y la vuelta al
despertar. logind ve la sesión gráfica inactiva, retira el DRM a phoc («Disabling seat» / «Enabling seat»), phoc
rehace la salida y phosh pierde la conexión y muere → pantalla de entrada (y a las 11:15, «pantalla transparente»).
Correlación exacta: la última suspensión antes del cambio (10:54, «printk: Suspending console(s)») no la tiró; todas
las de después con sesión abierta, sí.

**Arreglo**: `consola-en-suspension.conf` retirado; `scripts/85-cuelgues.sh` borra el fichero de tmpfiles y deja
`console_suspend=Y`. Coste: ramoops no ve lo que pasa dentro de la suspensión; para un dispositivo que no termina de
suspenderse queda `DPM_WATCHDOG` (r132), que provoca un pánico con su pila. ⚠️ No usar `no_console_suspend` ni
`console_suspend=N` con sesión gráfica.

✅ **Comprobado (13:43)**: gsd-power suspende tras 15 min en batería, suspensión profunda sin aborto ni s2idle, el
kernel vuelve a decir «printk: Suspending console(s)», duerme ~3 min y al despertar **phosh sigue vivo** (mismo PID,
sin «Disabling seat»). El usuario sigue en su sesión.

### La suspensión no duerme: despertar del UART del BT y SoC que vuelve al instante (2026-09-14)

**Síntoma**: a las 12:28 la sesión se cerró sola (parecía un reinicio). Secuencia en el diario, igual que a las 11:15:
gsd-power pide suspender → la suspensión profunda se **aborta** («Wakeup pending. Abort CPU freeze») → systemd cae a
**s2idle**, que despierta al segundo → logind pausa y reanuda el DRM de phoc («Disabling seat») → phoc recrea la
salida DSI-1 → phosh pierde la conexión y muere → pantalla de entrada. Desde el 13-09 las 6 suspensiones de gsd-power
abortaron; phosh murió en 2.

**Diagnóstico** con r131/r132 (`PM_DEBUG`, `PM_SLEEP_DEBUG`) y `pruebas/energia/fases-suspension.sh`, que escribe
directamente en `/sys/power` (sin systemd ni logind) y lo restaura todo al salir:

| prueba | resultado |
|---|---|
| `NIVEL=processors`, sin regla | aborta a los 0,8 s (`EBUSY`): `PM: Triggering wakeup from IRQ 151`, `pm_wakeup_irq=151` = `msmgpio 31 Edge 99c000.serial:wakeup`, el **UART del Bluetooth** (hci0) |
| `NIVEL=processors`, con regla | pasa: apaga las 7 CPU secundarias, espera 5 s y vuelve |
| `NIVEL=none SEGUNDOS=60` (suspensión real con `rtcwake`), con regla, 2 veces | entra sin abortar y vuelve a los **0,9-1,3 s** (duración por `/proc/uptime`, que cuenta el tiempo dormido); sin `pm_wakeup_irq` y la alarma del RTC (IRQ 115) sin dispararse |
| lo mismo con `TRAZA=1` | **duerme 62,4 s** y despierta la alarma del RTC (`pm_wakeup_irq=115`). ⚠️ Pero `qcom_stats` no cambia en `aosd` ni `cxsd`: ni durmiendo 60 s llega el SoC a apagar AOSS/CX, y los estados de bajo consumo de la DDR siguen a 0 desde el arranque (el módem sí duerme) |
| otra vez sin traza | **duerme 57 s** («Timekeeping suspended for 56.961 seconds») y despierta ~3 s ANTES de la alarma, sin `pm_wakeup_irq` y sin disparo del RTC: lo despierta algo que el kernel no registra como despertar. AOSS/CX, igual: sin entradas |

La línea «Timekeeping suspended for N seconds» (con `pm_debug_messages`) es la medida directa del tiempo dormido.

- **Primera causa, resuelta**: la misma que en surya. `device/energia/91-bt-uart-sin-despertar.rules` +
  `scripts/98-bt-uart-sin-despertar.sh` quitan el despertar al UART del BT (`power/wakeup` = `disabled`, también en
  caliente). Coste: el Bluetooth no despierta al móvil dormido; las llamadas sí (módem).
- **Abierto 1 — cazado en parte**: con `TRAZA=1` en un despertar inmediato («Timekeeping suspended for 0.023
  seconds»), la primera interrupción tras `machine_suspend` es `ipcc_0` → `glink-smem` (IRQ 246, `ipcc 196608` =
  `IPCC_CLIENT_LPASS << 16 | IPCC_MPROC_SIGNAL_GLINK_QMP`, el `glink-edge` del ADSP en `kodiak.dtsi`): **un mensaje
  GLINK del ADSP despierta al SoC al instante**. Es el mismo ADSP que nunca duerme (abierto 2). Ya van 5 de 8
  suspensiones reales que vuelven en menos de 1 s. La traza amplía a los callbacks de sus canales para ver cuál habla.
  **Canal cazado**: `qcom_smd_qrtr_callback <- qcom_glink_native_rx`, un mensaje **QRTR cada ~60 ms** que sigue
  llegando mientras el sistema entra en suspensión (15 de QRTR frente a 1 de batería en la traza). Es un flujo de
  sensores: en este móvil van por QMI sobre QRTR al ADSP y los pide iio-sensor-proxy cuando alguien los reclama. Con la
  pantalla encendida gsd-power reclama el sensor de luz (`ambient-enabled=true`); la rotación está bloqueada. Encaja
  con que la suspensión de gsd-power, con la pantalla apagada, sí durmiera 3 min, y con que las pruebas con la
  pantalla encendida vuelvan al instante. ~~Por confirmar con la pantalla apagada.~~ **Descartado**: con la pantalla
  apagada por el usuario (`bl_power=4`) vuelve igual en 0,026 s y los QRTR siguen cada 60 ms hasta el último, que
  despierta. El flujo no depende de la pantalla ni del brillo automático: algo lo tiene abierto siempre.
  **Prueba 2 (`systemctl stop iio-sensor-proxy`)**: los QRTR bajan de ~50 a 2 en 3 s → **el flujo es de
  iio-sensor-proxy**. La suspensión real duerme 32,8 s y despierta un QRTR del **módem** (IRQ 261, `ipcc` cliente
  MPSS; datos móviles activos, despertar legítimo). ⚠️ Aun así `adsp`, `aosd`, `cxsd` y `ddr` siguen a 0, sin sensores
  y sin QCE: el ADSP sigue sin dormir por otra cosa. Pista del usuario: en el OnePlus 6 el problema eran PipeWire y
  PulseAudio (el audio mantiene LPASS/ADSP activo); aquí además `soundwire … clock stop deprepare wait failed`.
- **ADSP sin sensores, despierto**: con iio-sensor-proxy parado 3 min (lecturas cada 30 s), `adsp`, `adsp_island`,
  `cxsd` y `aosd` siguen a 0. El flujo de sensores explicaba los despertares inmediatos, pero no que el ADSP no
  duerma: queda otra causa (o este firmware no actualiza esa estadística).
- **Gancho de suspensión** (`device/energia/50-despertar-y-sensores` en `/usr/lib/systemd/system-sleep/`, instala
  `scripts/99-ganchos-suspension.sh`; systemd 262 no lee `/etc/systemd/system-sleep`): antes de dormir guarda
  `/proc/interrupts` y **para iio-sensor-proxy** (su flujo QRTR despierta al SoC); al despertar escribe en el diario
  qué interrupciones subieron y `pm_wakeup_irq` (`journalctl -t despertar`) y lo vuelve a arrancar sin esperar.
- **Prueba acelerada por el camino real** (sin esperar a gsd-power): `rtcwake -m no -s 60` (solo programa la alarma)
  y `systemctl suspend -i` (pasa por el gancho; `-i` porque la propia sesión SSH inhibe la suspensión), lanzados con
  `sudo systemd-run --unit=prueba-suspension --on-active=8 /bin/sh -c "rtcwake -m no -s 60; systemctl suspend -i"`.
  ⚠️ Con `nohup … &` NO: systemd mata todo lo que cuelga de la sesión SSH al cerrarla y la prueba no llega a correr.
  Pruebas de un minuto (2026-09-14):

  | quitado antes de dormir | durmió | despertó | aosd / cxsd / adsp / ddr |
  |---|---|---|---|
  | iio-sensor-proxy (gancho) + QCE desenganchado | 60 s (17:46:47 → 17:47:47) | RTC (`pm_wakeup_irq=115`) | 0 / 0 / 0 / 0 |
  | lo anterior + `hexagonrpcd-adsp-sensorspd` | 61 s (17:48:55 → 17:49:56) | RTC | 0 / 0 / 0 / 0 |
  | lo anterior + `hexagonrpcd-adsp-audiopd` y `-rootpd` | 61 s (17:51:07 → 17:52:08) | RTC | 0 / 0 / 0 / 0 |

  Con los servicios de usuario del ADSP y los sensores fuera sigue igual → no son los servicios. Pista (17:53):
  **`sync_state` de relojes sin hacer**. Los proveedores de interconexión y los dominios RPMh sí sincronizaron, pero
  `100000.clock-controller` (GCC), `3d90000` (GPUCC) y `af00000` (DISPCC) tienen `state_synced=0`: sus enlaces a
  `3d6a000.gmu` (sin driver propio: adreno usa el nodo) y a `e1000000.framebuffer` (`simple-framebuffer` de `/chosen`,
  sin driver: ni simpledrm ni simplefb en la config) se quedan en `available`. Mientras un proveedor genpd no
  sincroniza, sus dominios quedan con `stay_on` y los que nadie usa no se apagan.
  - `state_synced` se puede escribir y fuerza `sync_state()`: **`sudo sh -c 'printf 1 > …/state_synced'`** (⚠️ con
    `echo` va un salto de línea y el kernel responde `EINVAL`). No es persistente.
  - Control sin forzar (17:55:06 → 17:56:07): RTC, 0 / 0 / 0 / 0.
  - Forzado en GCC, GPUCC y DISPCC (17:56): se apagaron `disp_cc_mdss_core_gdsc` y los tres
    `hlos1_vote_mmnoc_mmu_tbu_*_gdsc`, que seguían encendidos sin usuarios; quedan `gcc_usb30_prim_gdsc` (USB,
    `PWRSTS_RET_ON` por diseño), `gcc_ufs_phy_gdsc`, `mx` y `cx`. phosh sigue vivo. Prueba de 60 s después
    (17:57:12 → 17:58:13): RTC, **0 / 0 / 0 / 0**. Forzar `sync_state` no cambia nada: no era eso.

  El gancho paró y volvió a arrancar iio-sensor-proxy y registró solo interrupciones de suspender y reanudar; phosh
  sigue vivo. Llegar a AOSS/CX no depende de cuánto duerma: basta un minuto y mirar
  `qcom_stats`.
- **Tabla de consumos dormido** (`pruebas/energia/consumo-5min.sh "etiqueta"` → `pruebas/energia/consumo-5min.csv`).
  Dejamos de perseguir `qcom_stats` (lección de surya: el ADSP dormido no ahorraba nada; y `aosd`/`cxsd` salen del
  nodo `rpmh-stats` de Chromebook, sin garantía de que este firmware los rellene) y medimos mA. 5 min de suspensión
  forzada por configuración. ⚠️ `charge_counter` baja a saltos de ~8 mAh: en 5 min es inservible (daba 138 mA
  dormido y 1 300 mA en 22 s despierto). La cifra buena es la media del medidor, `time_to_empty_avg`, **leída al
  instante de despertar** (el gancho la anota: `journalctl -t consumo`); a los ~20 s ya refleja el consumo despierto.
  Son lecturas del medidor del teléfono (en surya ~2,5× menos que un medidor externo): valen para comparar.

  | configuración | dormido (medidor) | notas |
  |---|---|---|
  | reducida: iio-sensor-proxy parado al dormir, QCE fuera, `sync_state` forzado | ~49 mA | despierto con pantalla apagada ~150 mA |
  | reducida + QCE enganchado | ~49 mA | QCE no influye en el consumo dormido |
  | … + iio-sensor-proxy activo al dormir (`/run/despertar-sin-parar-sensores`) | 114 mA ⚠️ | despertó sola a los 151 s de 300, sin `pm_wakeup_irq` (no fue el RTC): la media arrastra tramo despierto, no comparable |
  | … + iio-sensor-proxy activo al dormir (repetición) | ~55 mA | durmió los 300 s (RTC): los sensores activos cuestan ~6 mA dormido, al borde del ruido; lo caro es que puedan despertarlo antes de tiempo (primera medida) |

  ⚠️ Una medida solo vale si duerme los 300 s enteros: `consumo-5min.sh` marca en la columna `despertar` las que
  despiertan antes de tiempo.

- **Por qué el conjunto `[sleep]` de RPMh no baja a cero (2026-09-16)** — ⚠️ **investigación repetida**: se rehízo
  todo lo de arriba sin leer antes esta sección, y se volvió a colgar el móvil parando los `hexagonrpcd` (prueba que
  ya constaba como `0/0/0/0` el 14-09). **Leer el README antes de investigar.** Lo que sí es nuevo es el mecanismo,
  con instrumentos que antes no se habían usado:
  - **`/sys/kernel/debug/cmd-db`** (es un **fichero**) traduce las direcciones de RPMh: `0x30000 cx.lvl`,
    `0x30070 ddr.lvl`… y los BCM de bus `0x50000 MC0` (controlador de memoria), `0x50004 SH0`, `0x50014 SH4`,
    `0x50054 MM0`, `0x50088 ACV`.
  - **Traza `rpmh_send_msg`** en instancia propia: cada voto lleva su conjunto `[active]` / `[wake]` / `[sleep]`. El
    `[sleep]` es lo que el hardware ejecuta al dormir. ⚠️ filtrar por `[sleep]`: el ruido de `sugov` inunda el búfer.
    En la suspensión solo se votan **BCM de bus, ningún raíl** (`cx.lvl` y compañía no aparecen jamás).
  - **`interconnect_summary`** da el consumidor por nombre. Los únicos con ancho de banda ≠ 0: `xm_usb3_0` (240000,
    desaparece al desenchufar) y **`qxm_crypto` (393600 fijos)**; su suma es exactamente `llcc_mc`/`ebi`.
  - **QCE**: `1dfa000.crypto` pide `QCE_DEFAULT_MEM_BANDWIDTH` (393600) en el probe y no lo retira (sin `pm_runtime`
    ni `remove`). Desvinculándolo (`/sys/bus/platform/drivers/qcrypto/unbind`): `qxm_crypto` → 0, `llcc_mc` −393600
    exactos y **`MC0` (0x603d81ec) y `SH0` (0x601740bb) pasan a `0x40000000`, desactivados en el conjunto `[sleep]`**.
    Y aun así `cxsd`/`aosd`/`ddr` siguen a 0 → **coherente con la medida del 14-09 de que el QCE no cambia los mA**.
    Incorporado igualmente como parche 0050 (r134), por ser correcto de por sí, no como mejora de consumo.
  - **UART del BT** (`99c000.serial` = `uart7`): **`active` el 99,86 % del tiempo** (5.197.154 ms activo / 7.416
    suspendido) y vota `SH4`; al bloquear el BT pasa a `suspended` y ese voto cae a 0. `hci_qca` implementa IBS pero
    **`__serial_clock_on/off` están vacías con un `TODO`** y el driver no tiene ni una llamada a `pm_runtime`. El DTS
    ya está preparado para lo contrario: IRQ de despertar en **`&tlmm 31`, el propio pin RXD**, y `pinctrl-1` «sleep».
    Un parche tendría que usar `pm_runtime_get`/`put_autosuspend` sobre `hu->serdev->ctrl->host` (el platform device;
    el `parent` es otro y no serviría) y ⚠️ sin dormir, que `serial_clock_vote()` corre con el spinlock cogido.
  - **El clúster de CPU sí funciona**: `pm_genpd/power-domain-cluster/idle_states` sube `S2` (`cluster-sleep-2`) una
    vez por suspensión. El problema nunca estuvo en la CPU.
  - ⚠️ **Los contadores de TIEMPO (`runtime_active_time`, `runtime_suspended_time`, los de `genpd`) no avanzan
    durante la suspensión**: cuelgan de un reloj que se congela. Solo valen los contadores de USO.
  - Lateral: **el RTC está en 1970**, descuadrado del reloj del sistema; `rtcwake -s 40` despertó a los 14 s.

- ✅ **Kernel r134 con el QCE arreglado (16-09 18:52)** — parche 0050 = commit upstream `6f5569203bb6` «crypto: qce -
  Add runtime PM and interconnect bandwidth scaling support». Tras arrancar con él, `1dfa000.crypto` pasa de
  `unsupported` a **`suspended`** y su voto de bus de **393600 a 0**. El mecanismo queda corregido.
  ⚠️ **No es una mejora de consumo** y no se instaló como tal: el 14-09 ya se midió que quitar el QCE no cambia los
  mA dormido. Se incorpora porque el driver mantenía relojes y ancho de banda encendidos estando ocioso.

- 🔋 **ATACAR LOS DESPERTARES, no el consumo dormido (decisión del usuario, 16-09)**. El dato que lo justifica ya
  estaba medido: durmiendo de un tirón son **40-50 mA**, pero un tramo con 8 despertares se va a **128 mA**. De los
  31 despertares de la noche del 16-09: **21 avisos de batería del ADSP**, 5 del módem (rmtfs) y 5 del botón.
  - ❌ **Acortar la duración de cada despertar está agotado**: los 15 s de espera por el módem se probaron en 10 s y
    «no basta» (el IMS cae con los datos), y dejarlos en 15 s fue decisión explícita del usuario.
  - ✅ **Desplegado: la batería ya no puede despertar al móvil** (`scripts/97-bateria-sin-despertar.sh`,
    `device/energia/92-bateria-sin-despertar.rules` + `bateria-sin-despertar.service`). El aviso sigue llegando,
    pero no saca al SoC de la suspensión. `qcom-battmgr-usb` y `-wls` se dejan intactos para que **enchufar el
    cargador siga despertando**. Silenciarlos en origen ya había fallado: el parche 0049 (r133) expone la petición
    `BATTMGR_REQUEST_NOTIFICATION` y el firmware del SM7325 ignora los campos.
    - ⚠️ Coste: mientras duerme, el sistema no se entera de los cambios de nivel de batería. El apagado por batería
      crítica lo hace el firmware por su cuenta, pero una alerta de batería baja puede tardar hasta el siguiente
      despertar por otra causa.
  - ⚠️⚠️ **En este móvil las reglas udev de `power_supply` NO se aplican en el arranque**, y por eso hizo falta el
    servicio systemd. El uevent se pierde:
    ```
    [ 1.173890] synth uevent: .../qcom-battmgr-bat: failed to send uevent
    [ 1.173900] power_supply qcom-battmgr-bat: uevent: failed to send synthetic uevent: -11
    [pmOS-rd]: Failed to write 'add' to '.../uevent': Resource temporarily unavailable
    ```
    El power_supply de pmic-glink aparece a 1,17 s y falla con EAGAIN desde el initramfs; `udevd` no arranca hasta
    los **7,0 s**, y `udevadm info` no muestra `USEC_INITIALIZED`: udev **nunca** ha procesado ese dispositivo. La
    regla en sí es correcta (`udevadm verify` Success 1/Fail 0, `udevadm test` casa y aplica el atributo) y funciona
    al forzar `udevadm trigger --action=add`, pero en el arranque no hay evento que la dispare. Vale para cualquier
    otro ajuste de `power/wakeup` en estos dispositivos.
  - ✅✅ **RESULTADO (noche 16→17-09, 19:00 → 09:53, 14,9 h, r134 + batería sin despertar)**: **0,47 %/h frente a los
    3,08 %/h de la noche anterior**, y encima con **menos** tiempo dormido (72 % frente a 91 %). **Cero despertares
    por batería** (antes 21 de 31), confirmado por tres vías: ninguna línea `battmgr` en las causas, la batería ya no
    figura en `wakeup_sources`, y **ningún QRTR del nodo 5 (ADSP)** al volver — los 6 identificados son del nodo 0
    (módem): 3 peticiones a `rmtfs` y 3 de señalización de voz.
    - **El aviso sigue llegando, simplemente ya no despierta**: el gancho cuenta `glink ADSP por canal:
      qrtr=+2 apr=+0 fastrpc=+0 **pmic=+85**` en cada sueño. 85 mensajes del gestor de batería por sueño, y el móvil
      sigue durmiendo. Era justo el objetivo, ya que silenciarlos en origen es imposible (el firmware ignora la
      petición del parche 0049).
    - **Por franjas** (mismo instrumento que la noche anterior): 02-06 h **54-72 mA** (antes 44-77: igual, dentro del
      ruido), pero **08 h 48 mA y 09 h 34 mA** frente a **133 / 122 / 110 mA** de la mañana anterior. Los sueños pasan
      de bajar un 1 % cada 18-24 min a cada **36-60 min** (el más largo, 60,4 min a 38 mA).
    - 🔑 **Esto CIERRA el «queda por cuadrar de dónde salían los 110-133 mA por la mañana»**: los avisos llegan uno por
      cada 1 % de capacidad, así que de madrugada (1 % cada 45-60 min) había pocos, pero por la mañana la batería
      bajaba rápido → más avisos → más despertares → más gasto → bajaba aún más rápido. **Un círculo vicioso que se
      retroalimentaba**, no los 38 s de cada despertar. Al quitarles el despertar, el bucle se rompe.
    - ⚠️ **La cifra de «23 mA medios» del informe NO es fiable**: sumando los mAh de los 34 sueños salen 705 mAh, el
      doble de los 339,7 mAh del total. El contador salta a escalones de ~45 mAh y **cada sueño que cruza un escalón
      se apunta el salto entero**, así que con 34 sueños la suma por sueños sobrecuenta muchísimo. Para comparar
      noches vale el **%/h**, no los mAh.
    - ⏭️ **Siguiente objetivo: los 26 despertares «sin fuente»**. El número total no bajó (34 en 14,9 h frente a 31 en
      11,4 h): lo que cambió es que ya no cuestan lo que costaban.
      ❌ **CORRECCIÓN (17-09): decir que «son del módem» NO tenía base** y se escribió aquí por error. Se apoyaba en 6
      lecturas de 34, y las otras 28 estaban vacías **porque el instrumento leía antes de que existiera el dato**
      (ver el arreglo del gancho más abajo). Lo único cierto: de esos 6, tres eran peticiones a `rmtfs` y tres
      indicaciones de voz, todas del nodo 0.

- 🔧 **El instrumento de «primeros QRTR» estaba roto desde el 15-09 (arreglado el 17-09, commit 629d025)**. El gancho
  leía el búfer nada más reanudar:
  ```
  06:09:56.286676  systemd-sleep: System returned from sleep
  06:09:56.344381  despertar[...]: pm_wakeup_irq=ninguna      (+58 ms)
  ...primer paquete en qrtr_endpoint_post:                     +689 ms
  ```
  Escribe a los **51-65 ms** y el primer paquete no llega hasta los **~690 ms**: leía diez veces antes de tiempo.
  Ahora la lectura se difiere **3 s** en una unidad aparte (como `pantalla-apagada`) y registra «NINGUNO en 3 s»
  cuando de verdad no llega nada, para distinguir «no hubo mensaje» de «no se miró».
  - ⚠️ Al interpretarlo: los primeros paquetes tras reanudar suelen ser **`qmi_tipo=2` (respuestas)** a lo que
    ModemManager pregunta al despertar — o sea **consecuencia**, no causa. Las causas son los entrantes espontáneos:
    peticiones (tipo 0, p. ej. `rmtfs`) e indicaciones (tipo 4, p. ej. voz).
  - **Qué NO despierta al móvil** (descartado el 17-09): no son abortos de suspensión (`suspend_stats`: 12 éxitos,
    1 fallo con errno −16); no son temporizadores (**ninguna unidad con `WakeSystem=yes`** y `wakealarm` vacío); y en
    31 de 34 despertares el gancho anota «fuentes de despertar con eventos: **ninguna**» (los otros 3, `[timerfd]`).
  - ⚠️⚠️ **OJO, CONCLUSIÓN CORREGIDA (ver el bloque siguiente): lo de abajo NO demuestra que el ADSP despierte.**
    El glink del ADSP es lo **primero que se atiende** al reanudar, pero su IRQ **no está armada como fuente de
    despertar** (`/sys/kernel/irq/246/wakeup = disabled`), así que no puede ser la causa: es un mensaje pendiente
    que se procesa en cuanto el núcleo vuelve. **Consecuencia, no causa.**
  - 📌 **(14-10): la sonda ya es permanente.** `device/energia/despertar-causa.sh` se instala en
    `/usr/local/sbin/despertar-causa.sh` y `despertar-causa.service` la arma en cada arranque (antes se armaba a
    mano y un reboot la borraba). Leer: `ssh edi@epo2lan 'sudo /usr/local/sbin/despertar-causa.sh leer'`, o desde
    el ordenador `sh pruebas/energia/quien-despierta.sh leer`. La GRABACIÓN la enciende y apaga el gancho
    `50-despertar-y-sensores`: con el móvil despierto, `irq_handler_entry` llena el búfer (2 MB) en segundos.
  - 🔎 **(17-09): el ADSP es lo primero que se atiende al reanudar.** Capturado con
    `pruebas/energia/quien-despierta.sh` (`irq:irq_handler_entry` grabando solo durante el sueño). **Dos ciclos
    independientes, idénticos al microsegundo**:
    ```
    Ciclo 1 (sueño 320 s):  +0,012 ms ipcc_0 · +0,022 ms irq=246 glink-smem · +0,064 ms arch_timer
    Ciclo 2 (sueño 178 s):  +0,012 ms ipcc_0 · +0,022 ms irq=246 glink-smem · +0,065 ms arch_timer
    ```
    `irq 246 = ipcc 196608 = ADSP` (módem = 261/131072, CDSP = 245/393216, WPSS = 244/1572864; lo confirma
    `irq 16 = ipcc 196610 = smp2p-adsp`). Acumuladas: **ADSP 452.572 frente a 4.918 del módem, 92 veces más**.
    En los dos ciclos, además: `pmic=+85` mensajes del gestor de batería durante el sueño, `paquetes +0/+0` y
    «fuentes de despertar con eventos: ninguna».
    - **Por qué no se veía**: en suspensión profunda quien despierta el SoC es el PDC, por debajo de Linux, y el
      núcleo **solo anota la causa si la interrupción estaba marcada como fuente de despertar**. La del glink del
      ADSP no lo está, así que el kernel la procesa al volver sin registrar nada y `pm_wakeup_irq` queda vacío.
      De ahí los «ninguna» de 26 de 34 despertares que llevábamos días interpretando mal.
    - 🔑 **Encaja con lo de ayer**: quitarle al `power_supply` el despertar bajó el consumo de 3,08 a 0,47 %/h
      porque el kernel dejó de hacer el trabajo asociado, **pero el SoC sigue saliendo de la suspensión** cada vez
      que el ADSP habla. Por eso el NÚMERO de despertares no bajó (34 en 14,9 h frente a 31 en 11,4 h), solo su
      coste. Los avisos siguen llegando (85 por sueño) y siguen despertando.
    - ⚠️ **Descartados por el camino** (con sondas, no por deducción): no es el módem (`pmirq` solo disparó con el
      botón, nhit=1, irq=116); no es el RTC (sus activaciones son POSTERIORES al despertar y no hay alarma:
      `wakealarm` vacío, `alarm_IRQ: no`); no son temporizadores (**ninguna unidad con `WakeSystem=yes`**); y el
      UART del Bluetooth, pese a acumular 448.625 interrupciones y estar siempre `active`, tiene su **IRQ de
      despertar dedicada (`msmgpio 31`) a CERO**.
- 🧱 **CONCLUSIÓN REAL (17-09): el despertar NO lo origina Linux.** Comprobado con sondas, no deducido:
  - **Ninguna interrupción está armada como fuente de despertar** en todo el sistema (`/sys/kernel/irq/*/wakeup`:
    la lista de `enabled` sale **vacía**). Ni siquiera la del glink del ADSP (`irq 246 = disabled`).
  - **Ningún subsistema remoto ha reportado un despertar jamás**: `wakeup_count = 0` en los cuatro `remoteproc`
    (módem `4080000`, **ADSP `3700000`**, wpss `8a00000`, cdsp `a300000` — ojo, `a300000` es el CDSP, no el ADSP).
  - **Ninguna fuente sube durante el sueño**: «fuentes de despertar con eventos: ninguna» en todos los ciclos. Las
    que tienen `wakeup_count` alto (`ucsi-source-psy` 4.860, `qcom-battmgr-usb` 58, el RTC 23) lo acumulan **estando
    despierto** (enchufar, negociación USB-C), no dormido.
  - **`pm_system_irq_wakeup` solo dispara con el botón** (nhit=1, irq=116) en toda la sesión.
  ⇒ El SoC sale de la suspensión por el **PDC / firmware**, por debajo de Linux, y el núcleo se limita a reanudar y
  atender lo que había pendiente. **Por eso el glink del ADSP aparece siempre el primero (22 µs): es lo que estaba
  esperando, no quien despertó.** Y explica por qué ninguna contramedida de estos días ha cambiado el NÚMERO de
  despertares (34 en 14,9 h frente a 31 en 11,4 h), solo lo que cuesta cada uno.
  - 🔒 **Y el device tree lo remata**: en `kodiak.dtsi` (el SoC real; `sm7325.dtsi` es un envoltorio de 17 líneas
    que lo incluye) hay **un solo `wakeup-parent` en las 7.933 líneas**, y es el del **`tlmm`** (línea 5837, el
    controlador de pines) apuntando al `pdc` (`qcom,sc7280-pdc`, 13 rangos de líneas mapeadas al GIC):
    ```
    5837   tlmm: pinctrl@f100000 {
    5846       wakeup-parent = <&pdc>;
    ```
    ⇒ **El único camino declarado para despertar el SoC por debajo de Linux son los GPIO, vía PDC.** Ni el glink,
    ni el IPCC, ni los `remoteproc` tienen esa vía. Y en el móvil **ningún GPIO está armado** (la lista de
    `/sys/kernel/irq/*/wakeup = enabled` sale vacía), incluido el `msmgpio 31` del UART del Bluetooth, que
    desarmamos nosotros y está a **0 interrupciones**.
    ⇒ **Por los caminos que Linux declara, nada debería despertar el móvil. Y despierta igual.** La única
    explicación compatible con todo lo medido: **lo decide el firmware (AOSS/RPMh) por su cuenta.**
  - ⚠️ **Límite alcanzado con las herramientas de Linux**: el móvil no expone nada del PDC en `debugfs` (solo
    `qcom_aoss`, `qcom_socinfo` y `qcom_stats`) ni tiene `/sys/kernel/debug/irq/domains`. Para ir más allá haría
    falta instrumentar el propio firmware, que es una caja negra.
  - ⏭️ **Lo práctico mientras tanto**: aceptar ~2,3 despertares/hora y seguir abaratándolos, que es lo que de hecho
    funcionó (de 3,08 a 0,47 %/h sin quitar un solo despertar).

- 🗑️ **Quitado el guardado POR MINUTO del brillo (17-09, decisión del usuario)**: fuera `brillo-persistente.timer` y
  `brillo-guardar.service`, que se disparaban **cada minuto** (no despertaban al móvil —sin `WakeSystem`— pero era el
  único temporizador propio que quedaba). **Se mantiene `brillo-persistente.service`**, que restaura el brillo al
  arrancar (tras el greeter) y lo guarda al apagar con su `ExecStop`, así que la función no se pierde: sin él,
  `systemd-backlight` restaura demasiado pronto y con un valor viejo, y la pantalla sale casi a oscuras.
  ⚠️ **Coste**: el brillo solo se guarda en un **apagado ordenado**; si el móvil se cuelga o se queda sin batería, se
  pierde el último valor y arranca con el anterior.

  **Datos móviles (18:35)**: con los datos conectados **despertó a los ~5 s** de dormirse, sin `pm_wakeup_irq`; subieron
  49 interrupciones `glink-smem` del canal del **módem** (IPCC 131072; el de los sensores es 196608). Lo que se ve en
  los registros:
  - **NetworkManager desconecta TODO al dormir** (`reason 'sleeping'`): los datos y también el Wi-Fi. En todas las
    medidas el Wi-Fi estaba desasociado mientras dormía; al despertar se vuelve a asociar.
  - Hay un segundo bearer fuera de NetworkManager: **APN `ims`** (perfil 2, multiplexado en `qmapmux0.x`), creado
    por ModemManager a la vez que los datos al arrancar. ModemManager (con `--test-quick-suspend-resume`, de
    `postmarketos-base-ui-modemmanager-systemd`) lo **reconecta ~6 s después de cada despertar**: 24 conexiones
    desde el arranque, ~7 KB/8 KB cada una (registro IMS). En las medidas anteriores se cortaba al despertar; con
    los datos puestos se cortó justo **antes** de dormir, junto con el de datos, y el módem despertó al SoC a los 5 s
    (indicaciones de fin de llamada de datos).
  - Perfiles GSM de NetworkManager: dos «Default»; el que tiene `autoconnect=yes` lleva el `sim-id` de la SIM
    anterior («No suitable device»); el de la SIM actual tiene `autoconnect=no` y hay que activarlo a mano (con
    `sudo`, por SSH no autoriza polkit). NetworkManager no reconecta los datos al despertar.
  - **Reproducible** (18:40, 2 de 2) y visible en todo el arranque: cada vez que el módem cambia el estado de una
    conexión de datos justo al dormir, despierta a los 4-5 s: NM cortando los datos (13:22:47, 18:35:11, 18:40:33)
    o el bearer IMS recién reconectado 7 s antes (18:40:51). Sin cambios en curso durmió 300 s aunque el IMS se
    había reconectado 15 s antes (18:27:11). Con los datos puestos por la mañana, **bucle**: 12:52:24 → 0 s,
    12:52:43 → 5 s, 12:53:09 → 1 s, 12:54:52 → 0 s. Es decir, **con datos móviles el móvil apenas duerme**.
  - Prueba en curso: el gancho `50-despertar-y-sensores` espera N s antes de dormir si existe
    `/run/despertar-espera-modem` (A/B, sin tocar el comportamiento por defecto).
  - **Espera de 10 s (18:50): no basta.** NM corta los datos a las 18:50:23 y el IMS cae con ellos; **a las 18:50:29,
    en plena espera, el IMS ya se había reconectado** (`qmapmux0.0` nuevo); duerme a las 18:50:34 y el módem lo
    despierta ~7 s después, sin `pm_wakeup_irq`. Encaja con lo anterior: con la reconexión IMS 15 s antes durmió 300 s
    (18:27:11), con 7 s despertó (18:40:51). Lo que despierta parece el registro IMS que sigue a cada reconexión, que
    tarda más de ~10 s en asentarse. Perfiles del módem (`qmicli --wds-get-profile-list=3gpp`, por el proxy, solo
    lectura): 1 `xcap`, 2 `ims`, 3 `sos`, 4 `internet`; el autoconnect del módem no se puede consultar
    (`InvalidOperation`).
  - **CAUSA (18:55, `dbus-monitor` de las llamadas a ModemManager mientras se cortan y reconectan los datos)**:
    - **NetworkManager corta los datos con `Modem.Simple.Disconnect("/")`** (tres veces): «/» significa **todos los
      bearers**, así que se lleva también el IMS, que no es suyo.
    - Quien reconecta el IMS es **`81voltd`** («IMS Data service on QMI/QRTR», paquete `81voltd` 1.2.0 de pmOS, el
      servicio del VoLTE): `Bearer.Connect` sobre `Bearer/2` unos segundos después.
    - Al dormir, NM corta los datos → cae el IMS → 81voltd lo relanza → el registro IMS (~15 s) despierta al SoC si
      ya está dormido. Con datos, cada suspensión acaba así (el bucle de las 12:52).
    - Arreglo natural: que NM desconecte **solo su bearer** (pasar su ruta en vez de «/»).
    - **Arreglo aplicado**: `packages/networkmanager` (receta `extra-repos/systemd/networkmanager` de pmaports,
      1.58.0, pkgrel 91) + `0002-wwan-disconnect-only-our-own-bearer.patch` (formato git, para upstream: en
      `nm-modem-broadband.c`, `mm_modem_simple_disconnect()` recibe `mm_bearer_get_path()` del bearer propio; sin
      bearer conocido, todos como antes). Compila e instala `INSTALAR=si sh scripts/83-networkmanager.sh` (copia la
      receta ENCIMA de la de pmaports en ia: dos carpetas con el mismo pkgname rompen pmbootstrap). También en surya
      (NM 1.52.2, mismo código; 81voltd e IMS igual).
    - Prueba reproducible, con el móvil despierto: `sh pruebas/red/datos-sin-tumbar-ims.sh` (corta los datos ~15 s
      con `dbus-monitor` escuchando). **Control sin parche (19:02, NM 1.58.0-r1)**: `Simple.Disconnect` ×3 con «/»
      ❌, IMS caído a los 2 s y reconectado a los 12 s ❌.
    - ⛔ **La v1 del parche (r91, 19:09) era INERTE**: instalada y con NetworkManager reiniciado, la prueba seguía
      ❌ ❌. Usaba `self->_priv.bearer`, pero en `nm-modem.c` las tres rutas de desactivación llaman a
      `deactivate_cleanup()` —que hace `g_clear_object(&self->_priv.bearer)`— **antes** de `disconnect()`: siempre
      NULL, siempre «/». Faltó comprobar que el código parcheado corría con el dato que esperaba.
      (Además, `83-networkmanager.sh` buscaba los `.apk` en `packages/edge`; esta receta los deja en
      `packages/systemd-edge`, y el fallo del rsync quedó tapado por una tubería: arreglado.)
    - **v2 (r92)**: guarda la ruta en `_priv.bearer_path` al conectar (`connect_ready()`), la pasa a
      `mm_modem_simple_disconnect()` y no la consume (disconnect llega tres veces por desactivación); se sustituye
      en la siguiente conexión y se libera en `dispose()`. Generada igual sobre 1.58.0 y 1.52.2.
    - ✅ **v2 comprobada (19:18, NM 1.58.0-r92)**: `Simple.Disconnect` ×3 con `/org/freedesktop/ModemManager1/Bearer/4`
      (el de datos), el IMS sigue conectado a los 2 s y a los 12 s de cortar los datos; Wi-Fi y datos reconectados,
      NetworkManager, ModemManager, 81voltd y phosh activos.
    - **Medida dormido con datos y r92 (19:19)**: al dormir solo cae el bearer de datos (el IMS ya no), pero **sigue
      despertando a los ~10 s** sin `pm_wakeup_irq`. Las marcas monotónicas de dmesg (no cuentan el sueño) dan 0,32 s
      de la entrada al apagado de las CPU y 0,6 s el ciclo entero frente a 10 s de reloj: **durmió de verdad ~9,4 s**,
      no fue una suspensión lenta de drivers. En la lista de interrupciones no sale `glink-smem` del módem, pero la
      lista se cortaba en 8: el gancho ahora lista 15 y registra qué fuentes de despertar (`/sys/class/wakeup`)
      tuvieron eventos mientras dormía. Siguiente: espera de 10 s antes de dormir, ahora que solo se corta el bearer
      de datos.
    - ✅ **Datos + r92 + espera de 10 s (19:24)**: NM corta el bearer de datos a las 19:24:43.4, el gancho espera 10 s,
      entra a dormir a las 19:24:54 y **duerme 291 s hasta la alarma del RTC** (`pm_wakeup_irq=115`; única fuente de
      despertar con eventos: `pmic@0:rtc@6100`). **56 mA dormido con datos**, igual que sin datos (55). Eran **dos
      causas apiladas**: (1) NM tumbaba el IMS con `Disconnect("/")` → parche de NM; (2) el corte del propio bearer de
      datos deja al módem avisando ~10 s después (19:19: corte 19:19:13.4, despertar 19:19:24) → espera antes de
      dormir.
    - **Espera permanente (decisión del usuario, 19:35)**: el gancho `50-despertar-y-sensores` espera **15 s** antes
      de dormir **solo si la radio móvil está activada y hay un perfil gsm con conexión automática** (`nmcli radio
      wwan` y `nmcli -f TYPE,AUTOCONNECT connection show`); sin datos se suspende al instante. 15 y no 10: el aviso
      llegaba a ~10,6 s del corte. `/run/despertar-espera-modem` sigue sirviendo para forzar otro valor (0 = sin
      espera) hasta reiniciar.
    - ✅ **Verificada (19:33, sin interruptor)**: NM corta el bearer de datos a las 19:33:01.7, el gancho registra
      «espera de 15 s», entra a dormir a las 19:33:17.6 y **duerme 285 s hasta el RTC** (`pm_wakeup_irq=115`, única
      fuente con eventos `rtc@6100`): **56 mA dormido con datos**. Wi-Fi y datos reconectados y phosh vivo.
    - **Uso real 19:40-22:17 (batería 53 % → 29 %)**: solo 3 suspensiones (19:43→19:47, 20:28→20:38, 22:15→22:16), todas
      con la espera de 15 s. ⚠️ **Tras un despertar automático gsd-power no vuelve a suspender**: a las 19:47 (sin fuente
      registrada) y a las 20:38 (`qcom-battmgr-bat +1`) se quedó despierto 35 y 81 min con la pantalla apagada hasta que
      el usuario pulsó el botón; tras actividad del usuario sí suspende a los 5 min (`sleep-inactive-battery-timeout`
      300). Waydroid arrancó a las 22:01 (40 → 32 % en 2 min).
    - **Volver a dormir (22:22, decisión del usuario)**: el gancho `50-despertar-y-sensores` programa en cada despertar
      `volver-a-dormir` a los 300 s (`systemd-run`, se cancela al volver a dormir) y `/usr/local/sbin/volver-a-dormir.sh`
      (`device/energia/`, lo instala `99-ganchos-suspension.sh`) suspende de nuevo solo con batería, sin llamada, con
      la pantalla apagada (`PowerSaveMode` de phosh ≠ 0) y sin inhibidores de aplicaciones
      (`org.gnome.SessionManager.IsInhibited` 4|8); si no puede leer algo, no suspende. Decisiones en
      `journalctl -t volver-a-dormir`. Probado a mano con cargador: «no: con cargador».
      ✅ **Probado con batería (22:26-22:38)**: suspensión con alarma a 60 s (despertar automático 22:27:27) → a los
      300 s «sí: batería, sin llamada, pantalla apagada (PowerSaveMode 3) y sin inhibidores: vuelvo a suspender»
      (22:32:33) → durmió hasta la alarma de control (22:35:51). Tras ese despertar gsd-power sí pidió suspender en
      el acto (22:36:07) y a las 22:37:43 se despertó **solo, sin `pm_wakeup_irq` ni fuente de despertar**; quedó
      programado otro `volver-a-dormir`. Batería 41 % → 41 % en 12 min. ⚠️ Una sesión SSH abierta pone un bloqueo de
      suspensión (`sshd`, modo block) que `volver-a-dormir` respeta a propósito.
      Despertar sin fuente de las 22:37:43: entre las interrupciones sube `smp2p-adsp 1 Edge q6v5 ready` y actividad
      glink del ADSP (29), módem (19) y otros DSP (16/16), pero **no hay ningún fallo ni reinicio de remoteproc** en el
      arranque (0 crash/fatal, solo los 4 «is now up» iniciales): la pista del ADSP estrellándose no se sostiene.
      **Espera acortada a 60 s (22:45, decisión del usuario)**: los 300 s eran los de gsd-power (inactividad del
      usuario); tras un despertar automático con la pantalla apagada cada minuto despierto cuesta ~150 mA.
      ⚠️ **Prueba a 60 s (23:05): no volvió a dormir** — «no: pantalla encendida» a las 23:07:51 sin ninguna pulsación:
      **phosh enciende la pantalla al despertar** y la apaga a los 300 s (`idle-delay`); con 300 s funcionó por
      casualidad. `org.gnome.Mutter.IdleMonitor.GetIdletime` no lo implementa phosh («Not supported»). **Nueva señal**:
      el gancho guarda al despertar los contadores de `/proc/interrupts` del táctil (`fts_ts`, IRQ 170) y los botones
      (`pmic_pwrkey` 116, `pmic_resin` 117, `Volume up` 165) en `/run/volver-a-dormir.entrada`; si suben, alguien lo
      usa y no suspende. La pantalla se anota solo como dato. (Despertar y reanudar no mueven `fts_ts`: nunca aparece
      en las listas del gancho.)
      ✅ **Probado con batería (23:11-23:16)**: despertar por alarma 23:12:42 → a los ~60 s «sí: batería, sin llamada,
      nadie lo ha tocado (PowerSaveMode 0) y sin inhibidores: vuelvo a suspender» (23:13:47; la pantalla estaba
      encendida por phosh) → durmió de 23:14:03 a 23:16:27 y **se despertó solo otra vez** (sin fuente, antes de la
      alarma de control). Batería 39 % → 39 %.
    - **Noche del 14 al 15 (con batería, primera noche con volver-a-dormir)**: ~40 suspensiones entre las 00:56 y las
      08:44, despertares cada 1-28 min casi siempre **sin fuente** (o `qcom-battmgr-bat +1`) y volver-a-dormir
      durmiéndolo a los ~60 s cada vez. Batería **97 % (01:16) → 81 % (07:14)**: 16 % en 6 h ≈ 2,7 %/h ≈ 120 mA de media
      (la tarde anterior, sin volver-a-dormir, ~10 %/h). ⚠️ **En cada despertar automático la pantalla se enciende**
      (`PowerSaveMode 0` en todas las decisiones): el usuario lo vio por la noche y gasta.
    - ⛔ **CUELGUE TRAS REANUDAR (08:44:47)**: suspensión «deep» pedida por volver-a-dormir sin «suspend exit» en el diario;
      arranque nuevo a las 09:10:25 (25 min después, primero en el arranque el botón de encendido; el usuario encontró la
      pantalla de entrada). `console-ramoops-0` (pstore, 08:44) termina en **«PM: suspend exit»** con las CPU y las
      tareas reanudadas y **ni un mensaje más** (ni la reasociación del Wi-Fi, que llega ~5 s después; ni avisos de
      tarea colgada, que saldrían a los 120 s): cuelgue total en los primeros segundos tras reanudar. El perro guardián
      no reinició: en cada reanudación sale «gunyah_wdt_start: Failed to stop gunyah wdt -22».
      **Causa probable: agotamiento de FastRPC por parar/relanzar hexagonrpcd en cada suspensión.** Sus unidades de
      pmOS llevan `Conflicts=suspend.target` (se paran al dormir) y `hexagonrpcd-reanudar.service` (de
      `76-cancelacion-eco.sh`) las relanza al despertar: **72 relanzamientos** esa noche. A las 08:37:50 sensorspd
      empezó a fallar en bucle (salida 4) con «Could not attach to FastRPC node» / «Could not remotectl: **No space
      left on device**»; tras el despertar de las 08:43:31 fallaban rootpd, sensorspd y audiopd cada 3 s (53 fallos en
      total), y la suspensión siguiente (08:44:47) colgó el móvil. volver-a-dormir multiplica los ciclos (40-70 por
      noche), por eso aflora ahora. En el arranque nuevo (4 ciclos) no hay fallos.
      **Arreglo (decisión del usuario, desplegado 11:05)**: hexagonrpcd **ya no se para al suspender**:
      `device/eco/hexagonrpcd-adsp-{rootpd,sensorspd}.service` son copias completas de las del paquete sin
      `Conflicts=/Before=suspend.target` (systemd no deja quitar un Conflicts con un drop-in; el `-R` del firmware va
      dentro y se retira `override-fwdir.conf`), `audiopd` sin Conflicts y **`hexagonrpcd-reanudar.service` retirado**
      (`SOLO_UNIDADES=si sh scripts/76-cancelacion-eco.sh`). Comprobado: las tres desde `/etc/systemd/system`,
      Conflicts solo `shutdown.target`, activas. Prueba: `pruebas/energia/ciclos-suspension.sh` (N ciclos cortos,
      para al primer cambio de PID, fallo de hexagonrpcd o caída del ADSP). ⚠️ En surya el proceso de sensores vivo al
      suspender estrellaba el ADSP.
    - **Pantalla apagada tras un despertar automático (2026-09-15)**: el gancho lanza a los 3 s
      `volver-a-dormir.sh --apagar-pantalla` (unidad `pantalla-apagada`) si `pm_wakeup_irq` no es el botón de
      encendido (116) ni el volumen (117, 165): pone `PowerSaveMode` 3 (`org.freedesktop.DBus.Properties.Set`, la
      propiedad es de lectura y escritura) salvo llamada o si ya lo han tocado.
    - 🔧 **Quien enciende la pantalla al despertar (2026-10-13)**: con `rtcwake -m mem -s 20` y la pantalla ya
      apagada, `bl_power` **sigue en 4** al reanudar. `rtcwake` escribe `/sys/power/state` y se salta logind: ni
      `PrepareForSleep` ni los ganchos de system-sleep corren. **El kernel no reenciende el panel**: lo enciende el
      espacio de usuario por la señal `PrepareForSleep(resume)` de logind. Emitir `org.gnome.ScreenSaver.WakeUpScreen`
      a mano **no** la enciende: phosh solo emite esa señal; quien manda es la propiedad
      `org.gnome.Mutter.DisplayConfig PowerSaveMode` (la implementa phosh en `src/monitor-manager.c`,
      `power_save_mode_changed_cb` → `zwlr_output_power_v1_set_mode`).
      **Parche `packages/phosh/0002-despertar-automatico-no-enciende-la-pantalla.patch`** (phosh r101): si el gancho
      escribió `/run/despertar-origen` = `automatico` y es reciente (ventana de 10 s), cualquier petición de encender
      la pantalla se convierte en mantenerla apagada. Pasados 10 s, un toque o un botón la encienden como siempre;
      sin el fichero, comportamiento de upstream. El gancho además apaga el panel (`bl_power=4`) en el propio despertar
      automático, por si suspendió con la pantalla encendida.
      ⏳ **Pendiente de compilar e instalar** (phosh 99990.57.0-r101); comprobar con
      `pruebas/energia/pantalla-parche-phosh.sh`, que no necesita suspender.
    - ✅ **Instalado y comprobado (2026-10-13, phosh 99990.57.0-r101)**. Prueba de mecanismo sin suspender
      (`pruebas/energia/pantalla-parche-phosh.sh`): con `/run/despertar-origen=automatico` la petición de
      encender deja `bl_power=4`; con `usuario` se enciende; con un marcador de 12 s se enciende (la ventana
      es de 10 s). Ciclos reales (`systemctl suspend` + alarma RTC, muestreo de `bl_power` cada 50 ms):
      - 22:27:36 despertar automático (alarma, `pm_wakeup_irq=115`): **panel ya apagado al reanudar**
        (`bl_power 4`); a los 5 s `PowerSaveMode` sigue 0 (gsd-power lo pidió) pero **el panel nunca se
        iluminó** — esa es la firma del parche.
      - 22:29:28 despertar por botón (`116`, origen `usuario`): `bl_power 4 → 0`, se enciende. ✔
      - 22:30:00 despertar automático con la pantalla **encendida al suspender**: el kernel sí reactiva el
        CRTC y el gancho lo apaga a los ~60 ms (`bl_power 0 → 4`). Por eso conviene mantener ambas cosas.
      ⚠️ El kernel **no** enciende el panel si estaba apagado al dormir; lo reactiva si estaba encendido.
      Para cazar cualquier encendido posterior: `pruebas/energia/vigia-pantalla.sh` (lee `bl_power` cada
      0,5 s y solo anota cambios; `journalctl -t vigia-pantalla`).
    - ✅ **Ciclos naturales con el SSH cerrado (23:00-23:36)**: 5 despertares, 2 automáticos y 3 del usuario.
      **Todos** los cambios de pantalla a encendido llevaron `origen: usuario`; **ninguno** automático.
      El automático de las 23:06:26 reanudó con `bl_power=4` y **no hubo transición a 0**: la pantalla
      siguió apagada. El vigía se lanza así:
      `scp pruebas/energia/vigia-pantalla.sh edi@epo2lan:/tmp/ && ssh edi@epo2lan 'sudo systemd-run --no-block --unit=vigia-pantalla /bin/sh /tmp/vigia-pantalla.sh 3600'`.
    - ✅ **Comprobado (11:06-11:14, `ciclos-suspension.sh`, 15 ciclos de 20 s antes de que el usuario la cortara
      reiniciando: «con 5 es suficiente»)**: hexagonrpcd con los **mismos PID** los 15 ciclos (sin reinicios), **0 fallos**,
      0 caídas del ADSP (running) y **pantalla apagada** (`PowerSaveMode 3`) tras cada despertar, salvo en los dos ciclos
      en que el usuario pulsó el botón (0). Tras el reinicio los tres servicios arrancan desde `/etc` sin fallos.
      ⚠️ La prueba solo se podía parar entrando por SSH en los 2-3 s de red entre ciclos: pruebas futuras cortas y que
      se paren solas (marca en /run o botón).
    - **Qué despierta al móvil cuando se despierta solo (traza, 11:24-11:32 del 15)**: `traza-despertar.sh` con
      `MAXIMO=600` → se despertó solo a los **526 s** (antes de la alarma), sin `pm_wakeup_irq` ni fuente de despertar.
      Primeras interrupciones tras `syscore_resume`: **`irq=13 ipcc_0` → `irq=261 glink-smem`**, y la 261 en ese
      arranque es `ipcc 131072` = cliente 2 = **MPSS, el módem** (ADSP = 196608, CDSP = 393216, WPSS = 1572864).
      ⇒ el despertar sin fuente es **un mensaje GLINK del módem** (QRTR: ModemManager/QMI, 81voltd/IMS, rmtfs…),
      no los sensores. En el diario de la vuelta no hay nada del módem que lo explique. Con volver-a-dormir a 60 s y
      la pantalla apagada cada despertar cuesta ~75 s despierto.
      Segunda traza (11:49-11:59, con sonda kprobe en `qrtr_endpoint_post`): **durmió los 604 s hasta la alarma**
      (`pm_wakeup_irq=115`), sin despertar espontáneo. La sonda funciona (cabeceras QRTR con nodo/puerto de origen y
      destino tras la vuelta, p. ej. nodo 5 puerto 14 → nodo 1), pero `qrtr-lookup` salió vacío (no está instalado:
      solo `qrtr-libs`).
      **Tercera traza (30 min, 12:15)**: despertar solo a los **640 s**, sin `pm_wakeup_irq`. Cadena: `ipcc_0` →
      `glink-smem` 261 (módem) → **primer paquete QRTR: nodo 0 (módem) puerto 67 → nodo 1 puerto 16419**, 44 bytes
      (aviso QMI pequeño); luego nodo 0 puerto 62 → nodo 1 puerto 16416 (0xb0/0xb4) y el tráfico normal del ADSP
      (nodo 5 puerto 14). Para traducir puertos a servicios sin instalar nada: `pruebas/red/qrtr-servicios.py`
      (consulta NEW_LOOKUP al servidor de nombres con un socket `AF_QIPCRTR`).
      **Traducido (12:28)**: módem puerto 67 = **servicio QMI 1, WDS (datos móviles)** — el paquete que despierta —;
      puerto 62 = **servicio 9, VOICE**. Los puertos locales 16419 y 16416 no son servidores anunciados: son
      **clientes** suscritos a esos avisos (ModemManager o `81voltd`, que mantiene el bearer IMS del VoLTE durante la
      suspensión; los dos usan WDS y VOICE). ⇒ **Un aviso WDS del módem despierta al móvil** y le siguen avisos de
      VOICE. Siguiente paso posible: saber qué cliente es (sonda en `qrtr_recvmsg`, que anota el proceso) y que ese
      cliente silencie los avisos WDS/VOICE mientras duerme (como hace Android con el filtro de indicaciones).
      **Cliente identificado (14:22): ModemManager, a través de `qmi-proxy`** (`pruebas/red/qrtr-quien.sh 16419 16416`):
      el puerto 16419 lo lee `qmi-proxy` (3 paquetes WDS en 40 s; 16417 también WDS, 16406 NAS) y `qmi-proxy` tiene un
      solo cliente conectado (`ss -xpn`). `81voltd` no es cliente WDS/VOICE: es un servidor IMSD que pide los bearers
      IMS a ModemManager por D-Bus («IMSD Start Connection…», «failed to create bearer»); `qmi-proxy` (PID 3831) nació
      después de ModemManager (2390), no de 81voltd (760, arrancó antes). ⇒ **los despertares son avisos WDS (y VOICE)
      del módem a ModemManager**; su `--test-quick-suspend-resume` («terse state») solo silencia los avisos de
      registro 3GPP, no los de datos ni llamadas.
      **¿Qué aviso WDS? (análisis por tamaños con `data/qmi-service-wds.json` de libqmi)**: el paquete que despierta
      trae 12 B de mensaje QMI = 7 B de cabecera + **un único TLV de 2 B**. En «Packet Service Status» (0x0022) el TLV
      obligatorio «Connection Status» mide 2 B ✓; en «Event Report» (lo que MM registra con `set_event_report`:
      tecnología, dormancia, estado de llamada de datos…) los TLV miden 1, 4, 8, 9 o 16 B (el único de 2 B es de
      EVDO). ⇒ **casi seguro «Packet Service Status»: una conexión de datos (probablemente la IMS) cambia de estado
      mientras duerme**. Ese aviso no se puede silenciar por registro (es como MM se entera de que se cae una
      conexión): un parche de «silenciar en terse» no quitaría este despertar. Pendiente confirmarlo con el id del
      mensaje (la sonda de `traza-despertar.sh` ya lo lee). `mmcli -G DEBUG` falló por polkit («Operation was
      cancelled»): no quedó activo.
    - ⛔ **CUELGUE 14:38:47 POR CAER A s2idle**: tres suspensiones deep seguidas volvieron al instante (14:35:51,
      14:37:17, 14:38:47) con **~3300 interrupciones glink del ADSP** (`ipcc 196608`) por ciclo (lo normal son 30-80):
      un flujo continuo del ADSP que sigue durante la espera de 15 s aunque iio-sensor-proxy ya esté parado. En la
      tercera, la deep devolvió error y **systemd-sleep pasó a s2idle** («PM: suspend entry (s2idle)» en el mismo
      milisegundo, sin «System returned»); **en s2idle spacewar se cuelga** (console-ramoops acaba en «Suspending
      console(s)»; arranque nuevo 14:42:53). Arreglo: `device/energia/sleep-solo-deep.conf` (`SuspendState=mem`,
      `MemorySleepMode=deep`): si la deep aborta, la suspensión falla y se reintenta más tarde. La traza de las 14:46
      no vale: la despertó el botón (`pm_wakeup_irq=116`); la sonda QMI funciona (tipo 2 = respuesta, 0x22 = Get
      Packet Service Status…).
    - 🔎 **ORIGEN DE LA AVALANCHA DEL ADSP (15:10-15:45)**. En los 44 arranques del diario solo hubo una: normal (27)
      en la suspensión de 12:27:33 y 3249 en la de 12:42:39, constante (~200 mensajes/s) hasta el cuelgue.
      - Las suspensiones no abortaban: el kernel apagaba las CPU y volvía en milisegundos (interrupción pendiente).
        Seguía con `user.slice` congelado e iio-sensor-proxy parado: la genera el kernel o el DSP, no un proceso.
      - Descartados: el flujo de sensores por QRTR (nodo 5 puerto 14 → 16403: 7-10 paquetes por ventana en las trazas
        de 12:00 y 12:26) y Waydroid (sesión parada; el único que usa libssc es iio-sensor-proxy).
      - Entre medias, **llamada entrante (12:28:50-12:29:42) con el casco conectado a mitad**: el paso a «Voice Call
        (Bluetooth)» falló ~15 veces (`wcn-bt-sco` ASoC -19, `chip not enumerated`) y la llamada **terminó en mitad del
        montaje fallido**; tras colgar siguieron los errores y «FE CS-Voice is not ready hw_free». En la llamada
        siguiente q6voiced dio «Failed to open tx: No such device». Hipótesis: el frontal CS-Voice o la sesión de voz
        del DSP quedan a medio arrancar.
      - Reproducción 15:24 (casco encendido a mitad, pero colgando con el circuito ya bien): **sin avalancha**. De paso,
        fallo aparte: el supervisor dio «CIRCUITO MONTADO» con 11 `chip not enumerated` y **no se oía por el casco**
        hasta pasar a manos libres y volver. Falta repetirla colgando durante el fallo.
      - `pruebas/energia/contadores-glink.sh`: cuenta 10 s por canal del ADSP (sondas en `qcom_smd_qrtr_callback`,
        `apr_callback`, `fastrpc_rpmsg_callback` y `pmic_glink_rpmsg_callback`, en una instancia de trazas aparte) y
        3 s de detalle (QRTR nodo:puerto, APR servicio/opcode). En reposo: 0-2 mensajes/s, casi todos de la batería.
      - **Contadores permanentes**: `device/energia/contadores-glink` + `contadores-glink.service` (sondas armadas al
        arrancar, solo cuentan) y el gancho de sueño anota en cada despertar «glink ADSP por canal: qrtr=+N apr=+N
        fastrpc=+N pmic=+N»; con más de 500 lanza 3 s de detalle. Leer: `journalctl -t despertar | grep glink`.
        Instala `scripts/99-ganchos-suspension.sh` (no despliega con una llamada en curso). Desplegado 15:34 (las
        cuatro sondas armadas).
      - Segunda reproducción (15:36, casco encendido a mitad y colgada a los ~5 s): **no se reprodujo**, porque esta
        vez el casco montó al primer intento (1,6 s, sin `chip not enumerated`). Sin avalancha (2,1 mensajes/s a los
        45 s, APR 0). Dato útil: esa llamada de 13 s dejó `apr=1251` en los contadores, ~100 mensajes APR/s con una
        sesión de voz en marcha; una sesión que quedara viva en el DSP daría un tráfico del orden de la avalancha
        (hipótesis). El fallo de enumeración es aleatorio: en vez de insistir, los contadores permanentes lo anotarán
        si vuelve.
    - ✅ **«Parece colgado / tarda en responder al botón» (15:44), arreglado.** No era un cuelgue: la espera de 15 s
      del gancho (datos móviles) corre con la sesión ya congelada (systemd-sleep congela `user.slice` antes de los
      ganchos). El usuario pulsó a los 2 y 6 s, la pantalla no reaccionó, el móvil se durmió igual y despertó con la
      pulsación de los 17 s. Ahora la espera mira el contador de la IRQ `pmic_pwrkey` cada 0,25 s; si sube, escribe
      `wakeup_count` y pone un `wake_lock` de 5 s («despertar-boton»): el kernel aborta la suspensión con EBUSY.
      Prueba (15:59, pulsación simulada con `touch /run/despertar-simular-boton`): detectada a los 0,3 s de empezar la
      espera, «Failed to put system to sleep … Resource busy», sin caer a s2idle, el gancho «post» corre igual (suelta
      el wake_lock, iio-sensor-proxy activo) y la sesión descongelada **0,43 s después de la pulsación**.
    - 🔎 **QUIÉN DESPIERTA AL MÓVIL (15:13-16:30, gancho con contadores por canal + traza de 16:14)**. De los
      despertares automáticos (sin `pm_wakeup_irq`):
      - **Batería del ADSP** (15:14:48, 16:10:18, 16:30:29): fuente `qcom-battmgr-bat +1`, interrupción glink del ADSP
        112-157 (normal ~25) y `pmic=+82` mensajes pmic_glink (normal 4): el gestor de batería avisa de un cambio y el
        kernel vuelve a leer todas las propiedades.
      - **Módem** (15:13:02, 15:34:05, 15:54:15, 16:03:55, 16:16:29): sin fuente de despertar. La traza de las 16:14
        (durmió 97 s) da como primera interrupción `glink-smem` del módem y como primer paquete una **petición QMI al
        puerto local 14 = rmtfs** (`qrtr_open(RMTFS_QMI_SERVICE)` en su código), mensaje 3 = `QMI_RMTFS_RW_IOVEC`
        (caller_id 1): el módem lee o escribe su sistema de ficheros (EFS) en el almacenamiento del teléfono. Las
        trazas de la mañana daban además avisos WDS (datos) a ModemManager. En cada despertar se reconectan los datos
        y al dormir se cortan: sospecha de que eso provoca las escrituras del módem (sin probar).
      - Sueños entre despertares automáticos: 3,2 / 5 / 1,6 / 12,6 min.
      - `rmtfs` corre con `-r -P -s` (sin `-v`): no deja sus lecturas y escrituras en el diario.
      - 15:16:43 (irq 115, RTC): la alarma de seguridad de la traza de las 14:46, que sobrevivió al reinicio; la de las
        16:14 también quedó puesta. Arreglado: `traza-despertar.sh` borra la alarma al volver.
    - 🔎 **A/B DATOS MÓVILES (16:35-17:36, `pruebas/energia/ab-datos-despertares.sh`)**. Sin tocar el móvil; los datos se
      bajan sin conexión automática (llamadas y SMS siguen) y vuelven en el primer despertar tras la hora.
      - **Sin datos** (16:35:44-17:33:27): 4 sueños, **54,5 min dormido** (8,0 / 8,9 / 8,8 / **28,8** min); despertares:
        batería 2 (16:43, 16:53), módem 2 (17:03, 17:33) → **módem uno cada ~27 min dormido**.
      - **Con datos**: la fase B quedó en un sueño de 1,8 min (despertó la batería): no sirve. Referencia con datos del
        mismo día (16:00-16:30, quitando el del botón): 22,4 min dormido, módem 2, batería 2 → **módem uno cada ~11 min**.
      - Lectura provisional (muestras pequeñas): con datos el módem despierta ~2,5 veces más, pero **sin datos también
        despierta**, y la **batería del ADSP despierta tan a menudo como el módem** (sin datos, cada ~10 min). Quitar el
        vaivén de datos no basta para dormir de un tirón.
      - El primer resumen del script repartía mal el despertar que cruza el cambio de fase; corregido (sueño y despertar
        van a la fase en que empezó el sueño).
    - 🔎 **AVISOS DE BATERÍA DEL ADSP (18:55)**. 5 de los 7 despertares por batería coinciden con bajar un 1 % de capacidad
      (16:30, 16:43, 16:53, 18:03, 18:18): el gestor de batería avisa del cambio y upower relee todas las propiedades
      (los 82 mensajes pmic_glink).
      - Mainline (`qcom_battmgr_enable_worker`) y el driver de fábrica de Nothing (`qti_battery_charger.c`, kernel 5.4
        publicado en github NothingOSS/android_kernel_msm-5.4_nothing_sm7325) piden los avisos una sola vez con
        `BATTMGR_REQUEST_NOTIFICATION` (0x04) y los campos `battery_id`, `power_state`, `low_capacity`, `high_capacity`
        **todos a cero**; ninguno los desactiva al dormir (el de fábrica despierta 50 ms en cada aviso).
      - Esos campos son los de `BATTERY_WAIT_STATUS` de Windows (este gestor de batería también sirve a portátiles ARM):
        capacidad en mWh y estado de alimentación por bits (0 enchufado, 1 descargando, 2 cargando, 3 crítico). Idea: al
        suspender, pedir avisos con el estado actual y una franja de capacidad alrededor de la actual; al reanudar,
        volver a cero. Sin probar si el firmware de SM7325 los respeta: requiere parchear `qcom_battmgr`.
      - Aparte: de 16:30 a 17:36, casi todo dormido con el medidor diciendo 51 mA, la capacidad bajó un 3 %
        (~135 mAh en 66 min ≈ 120 mA): el medidor del firmware parece quedarse corto, como el de surya (×2,24).
      - **Kernel r133 (parche 0049)**: `qcom_battmgr` expone la petición en `/sys/module/qcom_battmgr/parameters/`
        (`notif_power_state`, `notif_low_capacity`, `notif_high_capacity`, `notif_apply`; `suspend_notif` y
        `suspend_*` para mandar otra al suspender) y cuenta los avisos por tipo (`notif_counts`). Por defecto, lo de
        siempre. Instalado y arrancado a las 19:13.
      - ❌ **Prueba 19:14-19:21 (`pruebas/energia/avisos-bateria.sh`, CPU cargada): el firmware no respeta los
        campos.** Con la petición a cero, 76 → 74 % en 131 s y 3 avisos; con `power_state=2`, `low=0`,
        `high=4294967295`, 74 → 72 % en 240 s y 2 avisos. El firmware acepta la petición (0) pero sigue avisando
        ~1 vez por cada 1 %. Los avisos son `NOTIF_BAT_STATUS` (0x80), no de propiedad. Queda sin probar con
        valores «plausibles» (0-100 o mWh) en lugar del máximo; el firmware de teléfono (Android) probablemente
        ignora estos campos, que vienen del de portátiles con Windows.
    - 📏 **CONSUMO REAL 1 h sin tocar con r133 y volver-a-dormir a 15 s (19:23-20:26,
      `consumo-uso-real.sh`)**: 166 mAh, 158 mA, 72 → 69 % (2,85 %/h), dormido el 71 %, 9 despertares. Pero los
      primeros 13 min no son ciclos automáticos (venía despierto de la prueba de batería; botón a las 19:31; gsd-power
      lo durmió a las 19:36): 58,7 mAh en 14 min (~250 mA).
      - **Régimen de ciclos automáticos** (19:37:38-20:26:32, contador de carga que anota el gancho en cada despertar):
        **104,7 mAh en 49 min = 128 mA**, dormido ~90 %. Sueños de 75 / 353 / 2 / 19 / 530 / 513 / 18 / 484 / 713 s
        (los de 2-19 s: el módem lo vuelve a despertar nada más dormir); cada despertar dura 34-39 s (15 s de
        volver-a-dormir + 15 s de espera por el módem + gancho). Batería 3 veces (19:37, 19:55, 20:26).
      - ~~Estimación: dormido ~100 mA y los despertares no pesan~~ **CORREGIDO (20:45)** con la tabla del día por tramos
        entre despertares (líneas `consumo` del gancho): el contador de carga baja a saltos de **~11,3 mAh**, así que
        en tramos de 10 min el error es de ±60-70 mA y solo valen las ventanas largas. **Dormido de un tirón: 40-50 mA**
        (17:03-17:33 r132 49 mA con un sueño de 28,8 min; 17:36-18:03 r132 40 mA; 20:26-20:43 r133 50 mA). El tramo de
        128 mA (19:37-20:26) tenía 8 despertares de ~37 s: **lo que sube la media son los despertares** (pantalla que se
        enciende sola, datos que se reconectan, espera de 15 s por el módem). r133 no empeora: con r132 también hubo
        tramos de ~100 mA con muchos despertares. Siguiente candidato: no cortar los datos al dormir.
    - ❌ **Prueba «datos sin cortar al dormir» (20:55-21:03, `pruebas/energia/datos-sin-nm.sh`)**: bearer de datos por
      ModemManager con NetworkManager sin gestionar el módem y sin la espera de 15 s. **Peor**: dormía 1-11 s y pasaba
      ~20 s despierto, una y otra vez. La mayoría de los despertares, **IRQ 171 = `ipa`** (el camino de datos del
      módem): 1073 paquetes recibidos y 1118 enviados por `qmapmux0.0` en ~7 min. Al dormir NetworkManager apaga el
      Wi-Fi y el tráfico (la VPN con `ping 5`/`ping-restart 10`, mensajería…) pasa a los datos móviles, que ahora
      seguían arriba: cada paquete despierta al SoC. Deshecha a las 21:03 (módem otra vez con NetworkManager, espera de
      15 s de vuelta, bearer de la prueba borrado, IMS intacto). Con datos arriba mientras duerme haría falta que
      nada use la red entonces. De paso: la VPN renegocia entera en cada despertar (`ping-restart 10`), y eso
      también alarga cada despertar del ciclo normal.
    - ✅ **VPN sin keepalive (21:19-22:21, `scripts/95-vpn-sin-keepalive.sh`)**: el servidor empujaba `keepalive 5 10`,
      `ping 5`, `ping-restart 10`; ahora se ignoran (`pull-filter`) y a las 22:21 se fijó `ping-restart 3600` (sin él,
      openvpn deja 120 s por defecto). **Medida 1 h sin tocar: 102,9 mAh = 100 mA, 64 → 62 % (1,95 %/h), dormido
      90 %, 8 despertares** (antes 2,85 %/h). Con el registro nuevo del gancho («primeros QRTR al volver»):
      - batería del ADSP: 21:31 y 22:03 (sueños de 617 y 1130 s);
      - **módem: `0:67→1:16419 qmi 4/0x1` = indicación WDS «Event Report» (0x0001)** al cliente de ModemManager, en
        ráfagas: 21:43 + 21:44 (sueño de 10 s), 22:13 + 22:14 + 22:15 (23 y 17 s). No era «Packet Service Status»: este
        aviso lo pide ModemManager (`event_report_input_new()` en `mm-bearer-qmi.c`: dormancy, tecnología del bearer,
        estado de la llamada de datos, control de flujo…) y se puede silenciar.
      - 22:21 el botón.
    - ✅ **ModemManager r90 sin Event Report (22:35, `scripts/81-modemmanager.sh`, `packages/modemmanager`)**: el
      manejador de los avisos WDS Event Report de ModemManager solo escribe «got QMI WDS event report» en depuración;
      el parche 0002 los pide apagados. Compilado en ia sin `$depends_dev` en makedepends (pedía libmm-glib r90) y sin
      pruebas (3 de 38 abortan emuladas). **Medida 22:37-23:43**: 122,3 mAh = 110 mA, 61 → 58 %, dormido 87 %, **4
      despertares y ninguno por Event Report**: 2 por **IRQ 171 `ipa`** (tráfico del enlace IMS `qmapmux0.1`: 91 rx /
      93 tx en 1,5 h, ~1 paquete/min; es el registro para llamadas por 4G), 1 de batería y 1 del botón del usuario, que
      dejó el móvil 319 s despierto (volver-a-dormir no duerme si lo han tocado).
      - Consumo dormido por tramos de ≥94 % dormido: 20:26-20:43 50 mA; 21:31-21:43 68; 21:44-22:03 76; 22:39-22:51 113;
        22:51-23:15 111; 23:43-23:55 73. Con saltos de ~11 mAh del contador, en 12-25 min el margen es de ±30-55 mA: no
        se puede decir que r90 suba el consumo dormido. Hace falta una ventana larga (una noche).
    - 🌙 **MEDIDA DE NOCHE (16-09 00:02 → 11:24, `pruebas/energia/medida-noche.sh`)**, con r133 + ModemManager r90 +
      VPN sin keepalive + volver-a-dormir 15 s: **1593 mAh en 11,4 h = 140 mA, 57 → 22 % (3,08 %/h), dormido 91 %**,
      31 despertares (2,7/h): **21 de la batería del ADSP**, 5 del módem (todos petición a rmtfs: `0:11x→1:14 qmi
      0/0x3`) y 5 del botón (el usuario por la mañana).
      - ⚠️ **El charge_counter salta de ~45 mAh (1 %), no de 11**: casi todos los tramos entre despertares gastan
        43-47 mAh, así que lo que se mide es **cuánto tarda en bajar un 1 %**.
      - **El consumo empeora a lo largo de la noche**, con el móvil dormido el 96-98 % en todos los tramos: 01:15-04:30
        **43-57 mA** (1 % cada 45-63 min), 06:17-08:07 **72-77 mA**, 09:05-11:03 **95-149 mA**. Los 43-51 mA de
        madrugada son como los 50 mA de surya.
      - **Desglose por horas** (repartiendo sueño y gasto por solapamiento; el reparto «a la hora del despertar» daba
        disparates como «dormido 158 %»): 01 h 67 mA · 02 h 44 · 03 h 69 · 04 h 67 · 05 h 77 · 06 h 72 · 07 h 74 ·
        **08 h 133 · 09 h 122 · 10 h 110**, con 96-98 % dormido en todas.
      - **Descartado que sea por despertarse más o estar más rato despierto**: 36-39 s por despertar y 2-3 despertares
        por hora, igual de madrugada que por la mañana (los ratos de 262 s a las 00 h, 122 s a las 08 h y 265 s a las
        11 h son de uso del usuario). **Descartado el medidor**: cada tramo entre despertares gasta ~45 mAh (1 %) a
        cualquier hora; lo que cambia es el tiempo en gastarlos (45-63 min de madrugada, 18-24 min por la mañana).
        **Descartado un proceso desbocado**: en 16,5 h phosh 94 s de CPU, NetworkManager 53 s, phoc 51 s, greenline 31 s.
        El módem sí duerme (`qcom_stats`: 99 826 entradas); el ADSP sigue a 0 toda la noche, así que no explica el cambio.
      - Quedan como sospechosos la **radio** (LTE+5GNR, señal 80) y el **tráfico de mensajería** (greenline/WhatsApp
        reconecta y sincroniza avatares en cada despertar: 958 contactos y 80 grupos).
    - 🔬 **Prueba sin WhatsApp (16-09 12:31:57 → 13:10:51, `pruebas/energia/sin-greenline.sh`)**: greenline (unidad DE
      USUARIO `greenline-daemon.service`) parado y comprobado (0 líneas suyas en el diario en toda la ventana).
      **39 min, 29,1 mAh = 45 mA, 41 → 40 %, dormido 97 % en UN solo sueño y un único despertar (del módem)**: 39 min
      por 1 %, frente a los 18-24 min de la mañana con WhatsApp activo.
      - ⚠️ No es concluyente: la ventana tuvo **un despertar** y las de la mañana 2-3 por hora; además de madrugada, con
        greenline ACTIVO, ya se veían 43-57 mA. Hace falta una ventana de control a la misma hora con WhatsApp activo.
      - Dos trampas del script, corregidas: el patrón `*greenline*` casaba con sus propias unidades
        (`sin-greenline-volver`), y `systemctl stop` de una unidad de sistema inexistente no falla, así que decía
        «parado» sin parar nada (greenline solo existe como unidad de usuario).
    - 🔬 **Ventana de control con WhatsApp activo (16-09 15:20:53 → 16:04, `medida-noche.sh`)**: **contaminada por una
      llamada entrante a las 15:41** (confirmada por el usuario) y por uso del móvil (327 s despierto). Aun así, el
      primer sueño es comparable: **15:21:39-15:41:49, 20,2 min al 100 % dormido, 27,3 mAh = 81 mA**; el tercero
      (15:53:48-16:04:22, 94 % dormido) 20,6 mAh = 113 mA, ya después de la llamada. Frente a los **45 mA** de la
      ventana sin WhatsApp (97 % dormido). Indicio de que la mensajería pesa, pero no prueba: hay que repetir la
      ventana sin llamadas ni uso.
      - El despertar del primer sueño fue una **llamada entrante real**: `ringing-in` a las 15:41:49 (sonó 5 s y se
        cortó), que llega como indicación del servicio de VOZ del módem (`0:62→1:16415 qmi 4/0x2e`), distinta de los
        avisos de datos (WDS) que quitó ModemManager r90. Es decir, el sueño de 20 min terminó por la llamada.
      - ⚠️ **Matiz que debilita la hipótesis de WhatsApp**: en ese sueño de 20 min a 81 mA, greenline **no escribió
        ninguna línea** en el diario (17 líneas en el tramo siguiente, con el móvil en uso). Que no registre nada no
        prueba que no hable con la red (mantiene la conexión), pero deja la comparación 81 mA vs 45 mA sin explicación
        clara. Hay que repetir la ventana con WhatsApp activo, sin llamadas ni uso.
    - ✅ **MEDIDO: durante el sueño NO pasa un solo paquete** (gancho con contadores de red, 16-09 16:22:32 → 16:42:55,
      20,4 min dormido, despertó la batería del ADSP): `paquetes rx/tx desde antes de dormir: wlan0 +0/+0
      qmapmux0.1 +0/+0`. NetworkManager apaga el Wi-Fi y corta los datos al suspender, así que **ningún programa
      (WhatsApp/greenline incluido) puede gastar mientras duerme**: queda descartado como causa del consumo dormido, y
      también el enlace IMS como consumidor de tráfico. Lo que varía entre madrugada (43-57 mA) y día (81-133 mA) tiene
      que ser del hardware con la radio registrada.
    - ✅ **MEDIDA POR SUEÑO (gancho, commit c83358c): el consumo dormido NO sube de día.** El gancho anota ahora la carga
      justo antes de suspender y al volver, así que cada sueño tiene su cifra sin mezclar los ratos despiertos (era lo
      que ensuciaba los tramos: 16:04-16:42 daba 172 mA con 18 min despierto dentro). Primera medida, **a las 17:10 de
      la tarde: `sueño: 1085 s, 16,1 mAh, 53 mA`**, con cero paquetes y despertar sin fuente. Mismo rango que de
      madrugada (43-57 mA). Queda por cuadrar de dónde salían los 110-133 mA por hora de la mañana: 38 s despiertos por
      despertar no bastan para explicarlos.
      - La cifra global de «minutos por 1 %» (43 min con WhatsApp frente a 39 sin él) engaña: la ventana con WhatsApp
        pasó el 17 % del tiempo despierta.
      - **Contadores (20:36, `/sys/kernel/debug/qcom_stats/`, tras 10 suspensiones desde el arranque de las 19:13)**:
        `adsp` Count **0**, `cxsd` **0**, `aosd` **0**, `ddr` 0; en cambio `modem` 9153, `cdsp` 226, `wpss` 10.
        ⚠️ **Hipótesis sin probar** que el ADSP despierto sea lo que gasta: en surya se persiguió ese mismo contador y
        con el ADSP dormido el 100 % no ahorró nada («perseguíamos un contador, no un consumidor»). Si se sigue:
        qué lo mantiene despierto (candidatos: servicios de hexagonrpcd, flujo de sensores, audio/SLIMbus/SoundWire, el
        gestor de batería), probando de uno en uno y mirando si sube `adsp` tras un par de suspensiones. ⚠️ En surya
        desatar el pinctrl de LPASS estrelló el ADSP y parar hexagonrpcd a menudo agota FastRPC aquí: nada de eso en caliente.
    - **Surya (19:47)**: NetworkManager 1.52.2-r92 (su receta de pmaports v26.06 + el mismo parche) instalado con
      `suria/parches/scripts/21-networkmanager.sh`: la prueba da ✅ ✅ (`Disconnect` con `.../Bearer/1`, el IMS no cae) y
      su gancho `55-espera-datos-moviles` espera 15 s con datos. Al reiniciar NetworkManager afloraron perfiles gsm con
      el `sim-id` de una SIM anterior (sin datos): arreglado con `suria/parches/scripts/22-perfil-datos-sim.sh`.

  **Comparación con surya** (`suria`, memoria de batería, 2026-08-19): allí, con el medidor calibrado con un medidor
  USB externo (el suyo informaba 2,24× menos), **50 mA reales dormido** (600 s) y **118 mA reales despierto**. Aquí
  49 mA dormido y ~150 mA despierto, pero **con un medidor sin calibrar** (el del firmware del ADSP, no el `qcom_qg`
  de surya): si es fiel, spacewar duerme como surya; si también se queda corto ×2,24, serían ~110 mA reales. Además
  `time_to_empty_avg` es una media de ventana desconocida: con 5 min puede arrastrar algo del tramo despierto (techo).
  Referencias: OnePlus 6 con pmOS, 27 mA dormido (medido en mAh con ventanas largas).
- Estado 17:38 (tras la regla del UART y quitar `console_suspend=N`): gsd-power suspende en profundo sin abortos,
  sin s2idle y sin matar phosh (20 éxitos; el único fallo fue la prueba de fases). De 6 despertares, 2 fueron el
  botón; 4 sin interrupción de despertar registrada (candidato: el ADSP, 41 042 `smp2p-adsp`).
- **Lista del OnePlus 6** (`~/claude/postmarketos/oneplus6/bateria_oneplus6_para_eduardo.txt`, de otro usuario de
  pmOS/Mobian) repasada en spacewar:
  - audio: todos los nodos de PipeWire en `SUSPENDED`, PCM cerrados, SoundWire y códecs suspendidos; nuestra
    `57-suspender-en-llamada.conf` solo impide suspender durante una llamada. Sin `51-disable-suspension.conf`.
  - sesión de greetd colgada: no; una sola instancia de WirePlumber (la de edi).
  - ⚠️ **cámara, como su fallo 2**: WirePlumber (monitor de libcamera) tiene abiertos `/dev/media0`, `video0` y los
    subdispositivos de las cámaras, incluidos los **dos motores de enfoque** (`dw9719 18-000c`, `ak7375 19-000c`), que
    quedan en runtime PM **`active`** con sus reguladores (`vreg_camu_vaf_1p8`, `vreg_camw_vaf_1p8`,
    `vreg_cam_vio_1p8`) encendidos siempre; los sensores sí están `suspended`. En el OnePlus 6 el mismo patrón
    (actuador lc898217xc) costaba ~60 mA. Por medir aquí.
    Causa en el código: `ak7375` y `dw9719` hacen `pm_runtime_resume_and_get` en el `.open` del subdispositivo y
    solo lo sueltan en `.close`, y libcamera mantiene abierto el del objetivo mientras la cámara está enumerada.
    **Decisión del usuario: arreglarlo en nuestro libcamera** (abrir el objetivo al adquirir la cámara y cerrarlo al
    liberarla), no en los drivers.
    ✅ **Hecho: `packages/libcamera/0011-…` (libcamera r5)**. `CameraLens::init()` guarda los controles y cierra el
    subdispositivo; `open()`/`close()` usan un descriptor propio (reabrir el `V4L2Subdevice` volvería a enumerar
    controles y crearía `ControlId` nuevos en cada uso); `setFocusPosition()` abre bajo demanda con `VIDIOC_S_CTRL`;
    el pipeline simple abre en `acquireDevice()` y cierra en `releaseDevice()`. Instalado con
    `INSTALAR=si SOLO_INSTALAR=si sh scripts/94-libcamera.sh`: sin app de cámara `dw9800w` y `ak7375` pasan de
    `active` a **`suspended`**, sus reguladores `vaf` a uso 0 y nadie tiene abiertos sus nodos; WirePlumber sigue
    enumerando las tres cámaras. Pendiente: autoenfoque con la app abierta y medir los mA.
  - ⛔ **La cámara dejaba de funcionar tras unas horas: CMA de 16 MB** (2026-09-14 16:14, no tiene que ver con el
    0011; en surya, con el mismo parche, funciona). Snapshot no arrancaba: libcamera
    `dma-heap allocation failure for frame-1`, kernel `cma: alloc failed, req-size: 2025 pages … 791 free of 4096`,
    PipeWire `Format negotiation failed`. Causa: el kernel tiene `CONFIG_DMABUF_HEAPS_CMA=y` (sin heap `system`) y
    `CONFIG_CMA_SIZE_MBYTES=16` → `/dev/dma_heap/reserved` de 16 MB; `DmaBufAllocator` abre el primer proveedor
    (CMA → system → udmabuf) y no prueba otro si la reserva falla; dos fotogramas 1920×1080 XRGB son 4050 de 4096
    páginas, así que solo cabe recién arrancado. surya no tiene dma-heaps y libcamera usa `/dev/udmabuf` (memoria
    normal). Arreglo: **`packages/libcamera/0012-…` (libcamera r6)**, el ISP por software usa `/dev/udmabuf` si se
    puede abrir. Descartado quitar el heap CMA del kernel o sus permisos (afecta a todo el sistema, p. ej. Waydroid).
    ✅ Resultado (r6, 16:28): la cámara vuelve a funcionar con la CMA medio llena; `bufinfo` muestra los búferes de
    salida con exportador `udmabuf` y `CmaFree` no cambia.
  - ⛔ **Causa de fondo: fuga en el debayer EGL de libcamera** (y por eso la CMA se llenaba tras usar la cámara).
    Cada sesión dejaba vivo un búfer de salida de 8 MB importado en la GPU (`/sys/kernel/debug/dri/0/gem`, marca
    «I»): 5 → 6 → 8 tras cuatro sesiones, sin que ningún proceso lo tuviera abierto. `DebayerEGL::start()` crea un
    contexto EGL nuevo (`eGL::initEGLContext`) en un hilo nuevo y el anterior no se destruía nunca. Arreglo:
    **`packages/libcamera/0013-…` (libcamera r7)**, `eGL::destroyEGLContext()` al final de `DebayerEGL::stop()`.
    Prueba sin tocar el móvil: `pruebas/camaras/fuga-buferes-libcamera.py` (py3-libcamera de la misma versión; 3
    sesiones de 30 fotogramas en un mismo proceso). Importaciones en la GPU: **r6 8 → 9 → 10 → 11; r7 0 → 0 → 0 →
    0**. ⚠️ En ese guion los `udmabuf` suben de 4 en 4 con o sin parche: los enlaces de Python no liberan los búferes
    hasta que acaba el proceso. `gst-launch-1.0 pipewiresrc` desde SSH no sirve: WirePlumber responde «target not
    found». ✅ Confirmado con la app (17:17): tras 11 sesiones de Snapshot con r7, **0 búferes `udmabuf` retenidos y
    0 importaciones en la GPU**, autoenfoque funcionando, CMA intacta.
  - Para pruebas largas por SSH, `sudo systemd-inhibit --what=sleep --mode=block sleep N` **sí** frena la suspensión
    de gsd-power (diario: `gsd-power: Error calling suspend action: … BlockedByInhibitorLock`); sin `sudo` falla por
    polkit («interactive authentication»). Apagar la pantalla con el botón no es suspender.
  - listas negras en `modprobe.d`: solo la estándar. WoWLAN desactivado, pero no impide suspender (NetworkManager
    desconecta la Wi-Fi antes).
- Antes de cazarlo: a veces la suspensión real vuelve al segundo sin interrupción de despertar registrada. ⚠️ Las
  marcas de tiempo del kernel (dmesg, ftrace) se paran mientras duerme: la duración hay que medirla con
  `/proc/uptime`. La traza (`TRAZA=1`: `power:suspend_resume` + `irq:irq_handler_entry`) marca `machine_suspend`
  begin/end y la primera interrupción de después.
- **Abierto 2**: aunque duerma, el SoC no llega a su estado de menor consumo (AOSS/CX sin entradas en
  `/sys/kernel/debug/qcom_stats`): algo mantiene un voto encendido. Afecta al consumo en suspensión.
  Datos (despierto, 2026-09-14 14:2x; solo lecturas pasivas de debugfs, nunca `clk_summary`):
  - `qcom_stats`: `adsp` **0 entradas desde el arranque** (el ADSP no duerme nunca); módem 10 267, `cdsp` 57,
    `wpss` 11; `aosd`, `cxsd`, `ddr` 0.
  - **QCE** (`1dfa000.crypto`, `CONFIG_CRYPTO_DEV_QCE=y`, nodo activo en `kodiak.dtsi`): vota 393 600 kbps sobre la
    DDR (`ebi`/`llcc_mc`) con etiqueta 0, que en Qualcomm vale «siempre» (también dormido). El driver hace
    `icc_set_bw` en `probe` y no tiene ni suspensión ni runtime PM: **el voto no se suelta nunca**. Nadie lo usa
    (todos sus algoritmos en `/proc/crypto` con `refcnt 1`). Principal sospechoso de que la DDR y AOSS no duerman.
  - **USB** (`a600000.usb`, modo dispositivo sin cable): vota 240 000 sobre la DDR, pero `dwc3_qcom_suspend` suelta
    sus votos (`dwc3_qcom_interconnect_disable`); «HS-PHY not in L2» es solo un aviso.
  - **ADSP**: tres hexagonrpcd (raíz, audiopd, sensores `-s`) con iio-sensor-proxy activo; sin PCM de audio
    abiertos. Sospechoso de que el ADSP no duerma y, con él, CX.
  - Pantalla, cámaras e ISP votan con etiquetas que se sueltan al dormir o están apagados.
- Aviso inocuo al reanudar: `ak7375 19-000c: ak7375_vcm_resume I2C failure: -6` (motor de enfoque de la principal).

## Bluetooth en llamada (en curso, 2026-09-13)

Misma arquitectura que surya: el audio va del DSP al chip por SLIMbus (`SLIMBUS_7`) y el enlace SCO solo es
control. Kernel ya portado (0017-0020, 0024: NGD, `wcn-bt-slim` con el WCN6750 0x221, enlaces en el DT,
`hci_qca hfp_offload`), pero **el chip no aparece en el bus** («wcn-bt-slim 217:221:1:0: chip never showed up
on the bus»; el controlador renegocia el bus en bucle). Primer sospechoso, como en surya: **el firmware del
chip**. Se carga el genérico de linux-firmware (`qca/msnv11.bin`); el de fábrica está en la partición
`bluetooth_a` del propio móvil (`image/msnv11.bin`, `msbtfw11.mbn/.tlv`). En surya el NV genérico mandaba el
audio por HCI y nada funcionaba hasta poner el de fábrica.

- ✅ `scripts/82-firmware-bt-fabrica.sh`: instala el firmware de fábrica desde la partición (BTFW.MOSELLE.1.1.0);
  carga bien, pero **el chip sigue sin presentarse**.
- ✗ Descartados, medidos: alimentación (los raíles y GPIO del `bt_wcn6750` de fábrica coinciden con el nodo
  mainline), pines del bus (GPIO 94/95 ya en `lpass_slimbus`), `hci_uart hfp_offload` (no manda nada al chip),
  controlador SLIMbus despierto (`power/control=on`) y chip ocupado (escaneo): el gestor del bus responde
  `-ENXIO` a la consulta de dirección una y otra vez.
- ★ **Causa**: el driver de fábrica (`bt_fm_slim.ko` de la partición vendor, `btfm_slim_hw_init` desensamblado)
  lee la versión del chip y **reescribe el código de producto de la dirección elemental**: 0x20 Hastings 2.0,
  0x21 Hastings Prime, **0x22 Moselle** (`(versión | 0x10) == 0x40140110`). El WCN6750 da SoC 0x40140110: se
  enumera como **217:222**, no como el 217:221 que dice el DT de fábrica. Kernel **r117 (0031)**: DT
  `slim217,222` e id 0x222 en `wcn-bt-slim`.

- 🔎 **DT de fábrica** (`images/vendor_boot.img`, base «Yupik»): el Bluetooth va por `slim@3ac0000`
  (alias `slim_aud`, `cell-index = <1>`, `qcom,ea-pc = <0x3e0>`), nodo `qca6490` con
  `compatible = "qcom,btfmslim_slave"`, `elemental-addr = [00 01 21 02 17 02]` (dispositivo 1,
  producto 0x221, fabricante 0x217) y el IFD `[00 00 21 02 17 02]`. En kodiak.dtsi ya están
  `slimbam` y `slim-ngd@3ac0000` deshabilitados. Surya usaba 0x220 y `qcom,slim-hw-instance = <1>`.
- ✅ **Montaje falso del supervisor, arreglado (2026-09-15, commit 3e5dd16).** A las 15:24, con el casco encendido a
  mitad de llamada, la tarjeta entró en Bluetooth antes que el SCO: el kernel intentó arrancar el flujo al chip 11
  veces en 6,5 s (`chip not enumerated`) y el SCO subió 1 s después del último intento. Nadie volvió a probar y el
  supervisor dijo «CIRCUITO MONTADO»: todo lo que miraba estaba bien, incluido el puerto 151, porque el kernel escribe
  `moving call 120 -> 151` aunque el flujo falle. No se oía por el casco hasta pasar a manos libres y volver.
  - La señal fiable es `bus channel 157 reserved` frente a `chip not enumerated`: `comprobar()` da el fallo «flujo» si
    el último `chip not enumerated` es posterior a la última reserva del canal 157.
  - `reparar()` → `paso_rearrancar_flujo()`: con el eSCO en pie, la tarjeta a «Voice Call (Earpiece)» y de vuelta a
    Bluetooth (lo que arregló la llamada a mano), una vez por montaje; no es el doble arranque que deja muda la llamada,
    porque el canal 157 no llegó a arrancar.
  - 40 pruebas (5 nuevas: rearranque que arregla, flujo que arranca solo con los reintentos de PipeWire, chip que no
    aparece nunca y se rinde, colgar antes del rearranque, lectura de la línea). Desplegado con
    `SOLO_SUPERVISOR=si sh scripts/89-cadena-llamada-bt.sh`. Sin probar en llamada real: el fallo es aleatorio.
- ✅✅ **r124 (22:49): LOS ARREGLOS YA VAN EN EL KERNEL. La primera llamada tras arrancar funciona por el casco.**
  - Arranque: `no address at boot` y bus suspendido en reposo (2,8 s activo frente a 37 s suspendido). Los
    parámetros salen por defecto.
  - Al empezar la llamada, la tarjeta entra en Bluetooth antes del SCO. El arranque del flujo **falla en ~0,6 s**
    (`chip not enumerated`) sin bloquear la tarjeta.
  - El supervisor monta el circuito **al primer intento, en 7,4 s**: `enumerated at stream startup after 0 ms` y
    canales 157/159 reservados.
  - Subida: tono de ia en surya, 31/32. Bajada: coincide con lo que grabó ia, r=0,95. Al colgar se retiran los
    canales.
  - Quitados `slimbus-bt-enumerar` (servicio y guion) y `/etc/modprobe.d/slimbus.conf`: el script 88 los borra del
    móvil. `hung_task_panic` se queda como estaba (decisión del usuario).
- ⏳ **r123 (22:35), primera llamada tras arrancar, con ia de casco:** casi funciona.
  - El lua de WirePlumber pone la tarjeta en «Voice Call (Bluetooth)» al empezar la llamada, **antes** de que el
    supervisor monte el SCO descargado.
  - El arranque del flujo buscó el chip 5 s sin SCO, dos veces (salida y entrada), y dio `chip not enumerated`.
    Mientras, la tarjeta quedó bloqueada: todos los `pactl` del supervisor agotaron su tiempo y abandonó el primer
    montaje.
  - En el segundo montaje (SCO primero, tarjeta después) salió **`enumerated at stream startup after 0 ms`** y el
    circuito quedó en pie en 4,5 s. La prueba midió antes, así que su silencio no cuenta.
  - r124: búsqueda corta (500 ms) que falla deprisa, sin bloquear la tarjeta. El supervisor reintenta con el SCO
    ya montado.
- ✅ **CONFIRMADO (22:25, r122, `pruebas/banco-bt/enumerar-tras-sco.sh`): el WCN6750 enumera tras un SCO
  descargado.**
  - Sin SCO, 30 ráfagas de 3 s en 5 minutos no lo encontraron («never showed up» a los 329 s).
  - Justo después de un eSCO con `Data Path: Vendor Specific` hacia ia, bus fijado y consulta: **enumerado al primer
    intento** (ifd 0x85, pgd 0x86).
  - Consecuencia para el kernel (r123): no buscarlo en el arranque, sino al arrancar el flujo de audio de la llamada
    (el SCO ya está montado), con el bus retenido y un margen de varios segundos. Así lo hace el driver de fábrica
    en `btfm_slim_hw_init`.
- ⏳ **r122 (22:15): tampoco enumera solo.** Las ráfagas funcionan: 39 «master capability», con el bus suspendido
  entre ráfagas. Revisión: nunca se vio al WCN6750 enumerar solo en un arranque.
  - El «enumerado (intento 1)» del servicio fue a mitad de sesión, con la dirección ya conseguida a mano.
  - El único éxito real (bus fijado a mano, 20:3x) llegó **después** de las pruebas con SCO descargado.
  - Hipótesis viva: **el chip solo activa su lado SLIMbus tras un SCO descargado**, y después se deja enumerar
    con el bus en pie. En una llamada real el SCO va antes que el arranque del DAI. La refutación de antes no
    valía: durante aquel SCO no se consultó con el bus retenido.
- ⛔ **Regresión de la r121 (2026-09-13 22:05): el chip no enumera.** El parche 0037 retenía el controlador
  SLIMbus desde el probe (7,8 s), antes de que el Bluetooth cargara el firmware (8,8 y 10,7 s).
  - Con el bus en pie durante el arranque del chip, el WCN6750 no se anunció en todo ese arranque: ni con 60 s
    retenido y sin reinicios del bus (un solo «Rcvd master capability»), ni después forzándolo a mano.
  - En la r120 el bus se suspendía durante el arranque del chip, y retenerlo después unos segundos bastaba.
  - Arreglo para la r122: sondeo sin retener y, desde los 15 s, ráfagas (retener 3 s, consultar, soltar) cada
    10 s.
- ✅✅✅✅ **CONFIRMADO POR EL USUARIO CON SU CASCO (2026-09-13 21:40): «funciona perfecto por bluetooth».**
- ✅✅✅ **LLAMADA REAL POR EL CASCO BLUETOOTH, EN LOS DOS SENTIDOS (2026-09-13 20:47)**.
  `pruebas/banco-bt/llamada-bt-spacewar.sh`, opción A: spacewar llama a surya, que descuelga sin Bluetooth; ia hace
  de casco con oFono y `auricular-falso.py`.
  - **Montaje.** El supervisor, en `actuar`, monta el circuito en 4,4 s: CVSD y eSCO descargado. El kernel
    `moving call: tx_port 120 -> 151, rx_port 16 -> 150`.
  - **Subida.** El tono de ia llega a la toma de bajada del DSP de surya: 40 de 41 ventanas con señal.
  - **Bajada.** Lo que grabó ia coincide con la toma de bajada del DSP de spacewar: r=0,88 en las envolventes.
  - **Al colgar.** Se retiran los canales 157/159 (`removed 1 channel(s)`).

  ✅ **Vuelta al casco a mitad de llamada (21:02, `REBOTE=1`).** Con la llamada en el casco se pasa la tarjeta a
  «Voice Call (Earpiece)» (sin manos libres).
  - El supervisor lo toma como caída del circuito, desmonta el lado del casco y espera 4,7 s (la guarda de doble
    arranque). Lo vuelve a montar en 10,5 s, al segundo intento.
  - Después, la subida sigue con tono en surya (32/32) y la bajada coincide con lo que graba ia (r=0,86).
  - Al colgar se retiran los canales.
  - Es la vuelta que en surya dejaba la llamada muda hasta `remove_channels`.
  - Repetido a las 21:33 con cada toma comparada con su enlace SCO: toma 1 con subida 32/32 y bajada r=0,68, toma 2
    (tras la vuelta) con subida 32/32 y bajada r=0,63; remontaje en 10,6 s.

  Pendiente:
  - Llamada entrante: el módem de spacewar no da su número, y hay que guardarlo en un fichero de pruebas.
  - `rx volume step 6 not applied: -5` y CVP `0x112c2` error 1 al mover la llamada al Bluetooth. Inocuos: el
    usuario confirma que **el volumen en llamada por casco funciona** (2026-09-13).
  - **El silencio con casco funciona con el botón de la app Llamadas**, según el usuario (2026-09-13). La primera vez
    dijo que no, así que queda por ver si falla a veces. Con la UCM, «Voice Call (Bluetooth)» no tiene fuente en la
    tarjeta del móvil, y `cad_pulse_mute_mic` de callaudiod silencia la fuente de esa tarjeta (`source_id`, que vale
    -1 si no hay).
  - Con ia en modo oFono no hay perfil `a2dp-sink`, así que el supervisor avisa al rebotar el perfil.
  - Probar con un casco de verdad.
- ★★★ **CADENA DE LLAMADA DESPLEGADA (2026-09-13 20:45).**
  `scripts/89-cadena-llamada-bt.sh` instala las piezas de surya adaptadas y deja el supervisor en `MODO=observar`
  (solo anota lo que haría). Piezas:
  - `supervisor-llamada-bt.py`: PCM de voz `pcm3p`, HiFi «HiFi (Headphones, Mic1, Speaker)»; sus 35 pruebas pasan.
  - Scripts lua de WirePlumber: `find-voice-call-profile`, `mantener-voz-bluetooth` y `suspend-node-surya`.
  - `aviso-bt-caido`.
  - UCM `Bluetooth`: enciende SLIMBUS_7 antes de apagar las rutas internas, calla los TFA y deja la
    `DisableSequence` vacía.
  - `q6voice switch_full_session=N`.
  - `coreutils`: el supervisor necesita `stdbuf`.

  Sin llamada, el audio pasa por el chip en los dos sentidos a la vez: `pruebas/banco-bt/slimbus7-spacewar.sh`, con
  captura por MultiMedia2 y reproducción por MultiMedia3. Por un mismo frontal, el ADM rechaza el segundo flujo con
  0x10325 error 2. Siguiente paso: `MODO=actuar` y una llamada real con ia de casco. Con oFono y
  `auricular-falso.py` hay tono en los dos sentidos.
- ★★★ **LA BAJADA POR EL CHIP FUNCIONA (2026-09-13 20:16)**. Banco de medida con `slimbus7-spacewar.sh` (ia con
  oFono + `auricular-falso.py`): un tono de 600 Hz reproducido en spacewar por MultiMedia2 → SLIMBUS_7_RX →
  WCN6750 → aire llega a ia a −15,3 dBFS (**TONO SÍ**). Faltaba `q6afe slim_dev_id=0`: el valor 1 venía de surya
  (sdmmagpie), el DT de fábrica de spacewar pone `qcom,msm-dai-q6-slim-dev-id = <0>` en sb-7-rx/tx, y con 1 el
  DSP rechazaba `AFE_PORT_CMD_DEVICE_START` (0x100e5, error 1) en 0x400e/0x400f.
- ★★★ **LA SUBIDA TAMBIÉN (20:23)**: el tono de 1 kHz enviado por ia llega a la toma de SLIMBUS_7_TX
  (MultiMedia2) en 46 de 48 ventanas. Los registros del chip se leen y valen lo mismo que escribe el driver de
  fábrica para la Moselle (análisis de `bt_fm_slim.ko`): 0x100=0x01, 0x1F0=0x03, 0x50=0x03, revisión 0x24. El
  primer intento dio ceros exactos justo después de los intentos con `dev_id 1`, que habían reservado el canal 159.
  Sin `remove_channels` los canales siguen definidos en el DSP hasta que el NGD se suspende (lección r82 de surya).
  Entonces lo ponía `/etc/modprobe.d/slimbus.conf` (`remove_channels=1`). Desde la r124 viene de serie en el kernel
  (0035) y ese fichero se ha quitado.
- ★★ **CAUSA ENCONTRADA (2026-09-13): la autosuspensión del NGD.** Con el controlador fijo despierto
  (`echo on > /sys/bus/platform/devices/qcom,slim-ngd.1/power/control`, 5 s) y `requery` de `wcn-bt-slim`:
  **`WCNQUERY ifd ret=0 laddr=0x85 | pgd ret=0 laddr=0x86`**, el WCN6750 enumerado. En mainline el NGD se
  autosuspende a los 100 ms. El ADSP desmonta entonces el bus entero: cada reanudación trae un «Rcvd master
  capability» nuevo, y cada consulta sale a milisegundos de rearrancar el bus, sin tiempo para que el chip se
  sincronice y se anuncie. El driver de fábrica (`btfm_slim_hw_init`) sondea cada 1 ms durante 100 ms y mantiene el
  bus en pie. Análisis del `slimbus-ngd.ko` de fábrica: `ea-pc`, la instancia QMI, el orden de bytes de la EA y la
  consulta son idénticos a mainline, así que no eran la causa. (El «power/control=on» que figuraba abajo como
  descartado se probó con 0x221, sin consultar con el bus fijo.)
- ✗ Descartados también (2026-09-13): **NV por placa** (la partición `bluetooth_a` solo trae `msnv11.bin`, y el
  instalado es idéntico por sha256 a `msbtfw11.mbn/.tlv`) y **pines del bus** (GPIO 94/95 en `lpass_slimbus`, con
  keeper, 2 y 4 mA; el DT de fábrica tampoco los configura). Pendiente de descifrar: `unexpected event for opcode
  0xfc48` en el arranque (8,72 s y 10,58 s). Ningún driver del núcleo manda ese código: es un evento de fabricante
  que envía el chip por su cuenta.
- ✗ Con 217:222 (r120) **tampoco** aparece. Hipótesis **refutada** (2026-09-13): que el WCN6750 solo abriera su
  lado SLIMbus con un SCO por la ruta de descarga. Con ia de casco y `pruebas/banco-bt/sco-spacewar.sh`, el eSCO
  se monta **como en fábrica** (`Enhanced Setup Synchronous Connection`, aire CVSD, Linear PCM, `Data Path:
  Vendor Specific (0x01)`, `Synchronous Connect Complete: Success`) y el chip **sigue sin enumerar**. Además
  surya enumera **sin SCO**, durante la carga del firmware: `enumerated: pgd laddr` a 37,44 s, antes de
  `QCA setup on UART is completed` (37,58 s). ⚠️ Con `bluez5.hw-offload-sco` grabar del nodo no abre el SCO: se
  abre con `bluetoothOffloadActive` en las Props del dispositivo bluez. Cómo se llegó:
  - ✅ `scripts/88-bluetooth-llamada.sh` desplegado (hfp-registrado, `54-offload.conf`, `hci_uart hfp_offload=1`,
    `KernelExperimental` Offload Codecs). ⚠️ Hasta reiniciar, `hfp_offload=N` y el núcleo **no ofrece** Offload
    Codecs (`btmgmt expinfo` sin `a6695ace…`): `hci_qca` solo lo anuncia con el parámetro puesto.
  - ✅ Tras reiniciar (r120): `hfp_offload=Y` y el núcleo ofrece Offload Codecs. Sin SCO el chip sigue sin
    presentarse, como se esperaba. Tras reiniciar, PipeWire es del usuario de **phrog** (`greetd`) hasta que se
    entra: `54-offload.conf` y el guardián son de `edi`, así que las pruebas van **después de entrar**.
  - ✅ `hfp-registrado.sh` copiado de surya **no reparaba nunca** en spacewar: usaba `ps -o etimes=`, que el `ps`
    de busybox no tiene, así que la edad salía vacía y el veredicto era siempre «bien». Ahora la saca de
    `/proc/<pid>/stat`. Visto al entrar: `RegisterProfile() failed: NotPermitted` y el adaptador sin
    «Handsfree Audio Gateway».
  - ✅ Banco: **ia hace de casco de spacewar** (`pruebas/banco-bt/ia-casco-de-spacewar.sh`): emparejados,
    vinculados, de confianza; conecta con A2DP y HFP (CVSD/mSBC/LC3-SWB). Trampas del emparejamiento: ia tiene
    que estar **visible/conectable** (si no, su núcleo rechaza con «Unacceptable BD_ADDR (0x0f)»), y `btmgmt pair`
    por dirección empareja en el núcleo pero bluetoothd no guarda el vínculo: buscar + `pair` con la búsqueda en
    marcha + `trust`, en una sola sesión de `bluetoothctl`.

## Vibración (2026-09-13/14)

El motor es un LRA (~170 Hz) movido por el bloque de haptics del PMIC **PM8350B** (`0xf000` configuración, `0xf100`
patrón). Mainline no tenía driver: el kernel lleva la serie v7 de Fenglin Wu `qcom-spmi-haptics` (**0041**, sin
fusionar; el binding sí está en 7.3) y el nodo `haptics@f000` en el DT (**0042**, pico de 1,8 V = Vrms 1,27 V del
motor; los 9150 mV de fábrica son sobreexcitación en pulsos cortos).

- ✅ **r125**: el módulo carga solo, las revisiones del bloque cuadran (0x02 en `0xf001` y `0xf101`) y un pulso de
  200 ms vibra (`pruebas/vibracion/probar-vibracion.sh leer | pulso`).
- ✅ **feedbackd** no conocía el dispositivo: `device/vibracion/72-vibracion-spacewar.rules` lo marca
  `FEEDBACKD_TYPE=vibra` con `uaccess` (antes de `73-seat-late.rules`, que es la que pone las ACL). Lo despliega
  `scripts/90-vibracion.sh`; feedbackd lo coge al reiniciarse.
- ⚠️ Probar con `fbcli`: con la entrada en `/dev/null` corta el efecto a los 2 ms (el fin de entrada cuenta como
  «Press <RETURN>»). Usar `sleep 4 | fbcli -E <evento> -w 3`, con el perfil `quiet` para que no suene.
- ★ **Por qué las teclas vibran flojo y la llamada no vibra** (kprobes en el driver):
  - feedbackd pide `FF_RUMBLE` y el núcleo, como el driver no lo trataba, lo emula con un seno de **un tercio**
    de la magnitud; además feedbackd fija la ganancia al 75 % y el tema manda 7 ms al 20 % por tecla.
  - La llamada entrante usa `FF_PERIODIC`/`FF_SINE`, y el núcleo **rechaza** una forma de onda que el driver no
    anuncia: el efecto no llega nunca al driver.
  - `max-haptic-strength` (el selector de phosh) solo pone un tope a lo que pide el tema.
- ✅ **r126 / 0043**: el driver trata `FF_RUMBLE` a plena escala y anuncia `FF_RUMBLE` y `FF_SINE` (`B: FF=124070000`).
  Con sondas: el rumble de las teclas llega sin convertir (20 %, 7 ms), el de cerrar ventana al 50 %, y la llamada
  entrante (`FF_SINE`, 50 %, 1 s) ya la acepta el driver. Usuario (2026-09-14): «la vibración me vale así».
- **Subir la intensidad**, de menos a más riesgo:
  1. Selector de phosh (`max-haptic-strength`) al 100 %: es solo un tope, no amplifica.
  2. Tema de feedbackd propio, `/usr/local/share/feedbackd/themes/nothing,spacewar.json` (feedbackd busca
     `<compatible>.json` en los directorios de datos del sistema): más magnitud o duración por evento. Margen: las
     teclas van al 20 % (hasta ×5), la llamada al 50 % (hasta ×2).
  3. La ganancia del 75 % la fija feedbackd al abrir el vibrador (`FF_GAIN` 0xC000): solo cambiándolo a él o
     ignorándola en el driver.
  4. `qcom,vmax-microvolt` del DT (1,8 V de pico = la nominal del motor): lo sube todo; los 3,6 V de `wf-vmax` de
     fábrica serían el techo razonable, con más calor y desgaste del motor.

## Avisos y LED Glyph (2026-10-05)

### Por qué «a veces» no sonaban los avisos

phosh traduce cada aviso a un evento de feedbackd **según su `category`** (`src/notifications/notify-feedback.c`):
`im.received` → `message-new-instant`, `email.arrived` → `message-new-email`, `x-phosh.sms.received` →
`message-new-sms`… y **sin `category` → `notification-new-generic`**. El tema que usaba el móvil era el
`default.json` (no había tema para `nothing,spacewar`) y **no tiene `notification-new-generic` en el perfil `full`** →
esos avisos salían **mudos** (ni sonido, ni vibración, ni LED). Los emisores que no mandan `category` (greenline,
karere) caían justo ahí; los que sí la mandan sonaban. Además: el hint `suppress-sound` pasa al perfil `quiet` (solo
vibración) y `maybe_trigger_feedback()` solo lanza feedback del **primer aviso de cada tanda**.

- **Arreglo reproducible**: `device/feedbackd/nothing,spacewar.json` — device theme que feedbackd elige solo por el
  compatible del DT (`nothing,spacewar`). Hereda de `default.json` y añade `notification-new-generic` (sonido
  `message-new-instant`) al perfil `full`, con los «perdidos» en LED blanco. Lo despliega
  `scripts/99-feedbackd-spacewar.sh`.
- ⚠️ feedbackd es una **unidad de D-Bus** (`dbus-:1.2-org.sigxcpu.Feedback@N.service`), no un servicio systemd:
  `systemctl --user restart feedbackd` **falla**. Se recarga con **SIGHUP** y, si se cae, D-Bus lo reactiva.

### LED Glyph (Awinic AW21018)

Los LED blancos de la tapa («glyph») son los **18 canales de un Awinic AW21018** en **i2c1 (0x20)**, habilitado por
**gpio18** (activo alto). Mainline no traía driver (solo existe en kernels Android, `drivers/leds/leds_aw210xx.c`); este
repo añade:

- **0051**: `drivers/leds/leds-aw21018.c` (nuevo) + `CONFIG_LEDS_AW21018=m` y el binding `awinic,aw21018.yaml`. Expone
  **toda la tira blanca como un único LED `white:indicator`** (function `indicator` + color blanco vía fwnode). Init
  del chip según Awinic: chip enable, 1 MHz, 12 bits, corriente global 160, UVLO off, APSE, grupo off y tabla de
  escala **EVT**; `brightness_set_blocking` escribe los BR de los canales 1‑16 salvo el 6 y lanza `UPDATE`.
- **0052**: nodo `led-controller@20` en `&i2c1` + estado pinctrl `glyph_led_default` (gpio18), calcado del DT de
  fábrica (`~/claude/postmarketos/suria/parches/camera/eut2-sm7325/eut2-sm7325.dts`, nodo `aw210xx_led@20`).
- **Revisión de placa**: los straps gpio19/gpio21 (nodo `nt,hwid` de fábrica) se leyeron en
  `/sys/kernel/debug/gpio`: **1 y 1 → PVT**, que usa la tabla «EVT» y corriente 160. En T0 se activaría
  `awinic,t0-tables` (tabla T0 y corriente 32).

**Por qué `white:indicator`**: la regla udev que ya trae feedbackd capta `DEVPATH=="*/*:indicator"`, así que **no hace
falta regla propia**; feedbackd lee el color del nombre (`fbd-dev-led.c`), exige el atributo `pattern` (lo crea
`fbd-ledctrl` al poner el trigger) y ordena por prioridad (LED normal 10 > flash 5), de modo que los avisos blancos van
a nuestro LED y no al flash (que se clasifica como FLASH por tener `flash_strobe`/`flash_brightness`).

✅ **r135** (2026-10-05): al arrancar, `leds-aw21018 1-0020: Awinic AW21018 LED controller`; `/sys/class/leds/white:indicator`
con `FEEDBACKD_TYPE=led` y trigger `[pattern]`; `fbcli -t 2 -E message-missed-instant` hace parpadear el glyph y
`notify-send` suena. Desplegar: `40-compilar-kernel.sh` (⚠️ compilar en ia **se pregunta antes**) +
`46-instalar-kernel-ab.sh` + reiniciar; el tema, con `99-feedbackd-spacewar.sh`.

- Con la pantalla **encendida**, phosh dispara solo el evento *activo* → **sonido**; el LED está en los eventos
  *perdidos* (perfil `silent`), que phosh dispara al **apagar/bloquear** la pantalla (o a mano con
  `fbcli -E message-missed-instant`). Patrones multi-paso y los efectos de hardware del AW21018 (respiración, grupos,
  packs CSV del driver de Android): **pendiente**.


## Teclado en pantalla

`phosh-osk-stevia`; la fila de atajos de la distribución de terminal es la clave de gsettings
`mobi.phosh.osk.Terminal shortcuts`, con aceleradores GTK y teclas por nombre de keysym (`Page_Up`, no `PgUp`).
`scripts/91-teclado-atajos.sh` deja la fila igual que la de epo (surya): lleva copiada su lista y añade lo que
falte en su orden (`Page_Up`, `Page_Down`, `<ctrl>D`, `<ctrl>A`), sin quitar los de más de spacewar (Tab, Escape).
Además añade los propios de spacewar: `<shift>Tab` detrás de `Tab`.

## Sensores (2026-09-14)

Todos van por el concentrador de sensores del ADSP (SSC, `hexagonrpcd-adsp-sensorspd` + libssc); el único
dispositivo IIO es el ADC del PMIC. `ssccli --sensor accelerometer|magnetometer|compass|light|proximity` los lee
directamente, sin iio-sensor-proxy: los cinco dan lecturas (el magnetómetro, unas diez veces el campo terrestre).

- El concentrador termina de cargar a los ~86 s del arranque. iio-sensor-proxy busca los sensores **una sola vez**
  al arrancar (sobre `/dev/fastrpc-adsp`, en orden proximidad, luz, acelerómetro, brújula), esperando a que
  contesten; si una búsqueda falla no reintenta. Del r122 al r125 el acelerómetro apareció a los 86-88 s.
- ⚠️ En el primer arranque del r126 solo encontró luz y proximidad: sin acelerómetro, phosh no deja poner la
  rotación en automático (lo exige para el modo sensor). Ajustes móviles tampoco enseña sensores si se abre antes
  de los ~86 s (solo los busca al abrirse).
- Comprobar: `busctl --system get-property net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy
  HasAccelerometer`. `b false` → `sudo systemctl restart iio-sensor-proxy` (en 2 s vuelven los cuatro); `b true` con
  el botón sin cambiar → sería phosh. Cerrar sesión no reinicia iio-sensor-proxy.
- Decisión (2026-09-14): dejarlo así, sin depuración ni arreglo de fondo mientras no se repita.

### ✅ 2026-09-20: SE REPITIÓ, y la causa era NUESTRA (commit `99e4029`)

Síntoma: «sigo sin que funcione el sensor de rotación en phosh; he cerrado sesión y al volver tampoco, en
varios reinicios». En el menú desplegable **solo salía el selector manual de orientación, sin botón de
automático** — la firma de que phosh cree que no hay acelerómetro.

**El gancho `50-despertar-y-sensores` para `iio-sensor-proxy` al dormir**, y con `volver-a-dormir` a 15 s eso
pasa sin parar: en aquel arranque el servicio llevaba **8 arranques**. **phosh lee el acelerómetro al arrancar y
NO se reengancha** cuando el servicio vuelve: se queda sin él toda la sesión. Cerrar sesión no bastaba porque al
entrar el servicio estaba parado, o recién arrancado con `--no-block` y aún sin sensores (el concentrador del
ADSP tarda ~86 s).

Medido, en este orden:
- el sensor funciona: `ssccli --sensor accelerometer` → `X=8.87 Y=0.23 Z=4.15 m/s²`; `HasAccelerometer=true`,
  `orientation-lock=false`.
- ⚠️ **polkit descartado**: el `AccessDenied: Sensor claim not allowed` que sale al probar `monitor-sensor` **por
  SSH es un falso positivo** — una sesión SSH no tiene *seat* y la política es `allow_active=yes`. Preguntar por
  el proceso real: `pkcheck --action-id net.hadess.SensorProxy.claim-sensor --process $(pgrep -x phosh)` → **rc=0**.
- `AccelerometerOrientation` es el indicador útil: **`"undefined"` = nadie lo ha reclamado**, `"normal"` = phosh lo
  tiene. Con sesión nueva y servicio estable pasa a `"normal"` y vuelve el botón auto/no auto (confirmado por el
  usuario); al simular el gancho (`stop`, 3 s, `start --no-block`) vuelve a `"undefined"` **y ya no se recupera**.

**Arreglo**: `device/energia/spacewar-sensores.conf` → `/etc/tmpfiles.d/`, que crea el interruptor
`/run/despertar-sin-parar-sensores` **que el propio gancho ya consultaba** (línea 107). Lo instala
`scripts/99-ganchos-suspension.sh`. Persistente entre reinicios, reversible con `rm`.
⚠️ Tras el arreglo hay que **cerrar sesión y volver a entrar una vez**: phosh no recupera el sensor en caliente.

⏳ **Coste y pendiente**: con los sensores activos al dormir se midieron ~6 mA (al borde del ruido); el riesgo real
no son los mA sino que su flujo QRTR despierte al SoC antes de tiempo. **Falta medir si phosh SUELTA el
acelerómetro con la pantalla apagada**: si lo suelta, el flujo cesa solo y este interruptor sobra.

### ✅✅ 2026-09-21: la causa DE FONDO estaba en iio-sensor-proxy (commit siguiente a `2ce14c6`)

Tras reiniciar volvió a faltar el botón de automático, con el interruptor ya puesto: el gancho no era toda la
historia. Orden real del arranque: `iio-sensor-proxy` a los **8 s**, phosh a los **26 s** (pregunta
`HasAccelerometer` → **false**), el acelerómetro del concentrador aparece a los **~86 s**. phosh **sí** escucha
`notify::has-accelerometer` (`rotation-manager.c`), pero `iio-sensor-proxy` **no difunde** el cambio:
`send_dbus_event()` solo avisa a los clientes que **ya han reclamado** un sensor, y phosh no lo había reclamado
porque le dijeron que no existía. Círculo cerrado. Medido con `dbus-monitor` y un testigo: `NameOwnerChanged` 2,
`PropertiesChanged` **0** mientras `HasAccelerometer` pasaba de false a true. (Con sensores IIO normales no pasa:
existen desde el arranque.)

**Arreglo**: `packages/iio-sensor-proxy` = Alpine 3.9-r2 + `0001-difundir-los-cambios-de-disponibilidad-de-los-
sensores.patch`: `send_dbus_event()` además difunde a **todo el bus** los cambios de `Has*` (solo la
disponibilidad; las lecturas siguen yendo a quien las reclama). `pkgrel=100`, `scripts/41-iio-sensor-proxy.sh`.
**Probado en vivo, sin cerrar sesión**: tras instalarlo la señal sale con `destination=(null destination)` y
`HasAccelerometer=true`, y en el phosh que llevaba toda la sesión sin rotación **apareció el botón de automático y
rota** (usuario, 21-09).

⚠️ `AccelerometerOrientation = "undefined"` también sale con el móvil **plano**, con el sensor reclamado: solo
indica «nadie lo reclama» si el móvil está de pie. ⚠️ `orientation-lock = true` hace que phosh no lo reclame aunque
lo tenga (ahorro de batería): es el botón, no un fallo.

⏳ Con el parche, el interruptor `spacewar-sensores.conf` **podría sobrar** (phosh ya se recuperaría tras cada ciclo
del gancho) y recuperaríamos el ahorro al dormir: **pendiente de probar**.

## Carga (2026-09-14)

La carga y USB-PD las negocia el firmware del ADSP con el PM8350B; Linux (`qcom-battmgr`, `ucsi_glink`) solo
informa. `device/energia/info_carga.sh` (instalado por `scripts/92-info-carga.sh`) lo resume.

- ✅ **Carga rápida con PD**: powerbank PD con cable C-C, batería al 40 % → PD 3.0 a **9,2 V × 2,5-2,8 A ≈ 25 W**
  de entrada y **+4,7-5,3 A** a la batería (35 → 40 °C en dos minutos). Con C-A solo hay 5 V «Default USB».
- Al 77-80 % la batería ya está en tensión constante (4,48 V) y la corriente baja sola con cualquier cargador: para
  medir la carga rápida hay que descargar antes (`pruebas/energia/descargar.sh`, stress-ng con pausa por temperatura).
- ucsi_glink no publica las capacidades del cargador ni la tensión; `battmgr-usb` dice «SDP» aunque haya PD.
- ⚠️ `charge_counter` parece salir del porcentaje (≈ % × 4600 mAh), no de contar carga: no sirve de medida
  independiente del consumo.

## Wi-Fi (2026-09-14)

WCN6750 con `ath11k` (firmware WLAN.MSL.1.0.1 en el WPSS). Funciona bien: 5 GHz canal 36 a 80 MHz, −45 dBm,
650/173 Mbit/s, sin reintentos ni pérdidas de baliza. En dos días hubo un solo corte real (clave durante la primera
configuración); los demás son reinicios o la Wi-Fi apagada a mano.

- ✅ **País España**: `scripts/95-wifi.sh` instala `iw` y `device/wifi/cfg80211-pais.conf`
  (`options cfg80211 ieee80211_regdom=ES`, cfg80211 es módulo) y lo aplica en caliente con `iw reg set ES`. Antes el
  dominio era el global «00» (5 GHz con escaneo pasivo, DFS sin fijar); ahora «country ES: DFS-ETSI».
- ⏳ **Calibración de radio de fábrica**: el `board-2.bin` de la distribución solo trae la variante
  `Qualcomm_rb3gen2` para el WCN6750 (el DT pide `Nothing_Spacewar`, así que se usan datos genéricos; el chip dice
  `board_id 0xff`). Los datos de placa de Nothing están en la partición `modem_a` (vfat, montar en solo lectura):
  `image/qca6750/bdwlan.elf`, `bdwlan.bXX`/`eXX`, `regdb.bin`. Se empaquetarían con `ath11k-bdencoder`
  (qca-swiss-army-knife) como variante `Nothing_Spacewar` en `/lib/firmware/updates/`. ⚠️ Datos de fábrica: sacarlos
  del propio móvil al desplegar, nunca a un repositorio público. ⚠️ Probar solo con el cable USB a mano: unos datos
  equivocados dejarían sin Wi-Fi, y SSH va por Wi-Fi. `vendor/firmware/wlan/qca_cld/qca6750/wlan_mac.bin` es la MAC:
  privado.

## Firefox: vídeo en segundo plano (2026-09-14)

YouTube móvil (el que ve Firefox con `mobile-config-firefox`) pausa el vídeo en cuanto la web detecta que la pestaña no
se ve: al cambiar de app o apagar la pantalla.

- `scripts/97-firefox.sh` instala `device/firefox/spacewar-prefs.js` en `defaults/pref/` de firefox-esr (fichero propio:
  sobrevive a las actualizaciones): `media.suspend-background-video.enabled=false`,
  `media.block-autoplay-until-in-foreground=false` y `extensions.autoDisableScopes=14` (activar extensiones copiadas al
  perfil). Y la extensión **Video Background Play Fix** (`video-bg-play@timdream.org`, firmada por Mozilla, sin
  permisos; oculta a YouTube y Vimeo que la pestaña está en segundo plano) en el perfil activo de `installs.ini`,
  saltándosela si ya está.
- ⚠️ No usar `/etc/firefox/policies/policies.json`: Firefox lee un solo `policies.json` y ese sustituiría entero el de
  `mobile-config-firefox`.

## Cámaras (2026-09-14)

camss (C-PHY ya en 7.2.2 para sc7280) + libcamera con el pipeline simple y softISP. Las tres dan imagen en la app
Cámara (Snapshot):

| cámara | sensor | bus | kernel | estado |
|---|---|---|---|---|
| principal | Sony IMX766, C-PHY 3 trios | CCI1 bus 1 0x10, CSIPHY3 | r128: driver WIP de Danila (0045) + DT (0046) | capta y **enfoca** (r130: AK7377 como AK7375, 0048); se carga sola al arrancar |
| ultra gran angular | Samsung S5KJN1 | CCI1 bus 0 0x2d, CSIPHY2 | r127: link-frequencies 700 MHz (0044) | bien; **autoenfoque** (DW9800W + libcamera propio) |
| frontal | Sony IMX471 | CCI0 bus 0 0x1a, CSIPHY0 | r129: orden Bayer RGGB (0047) | bien |

- **S5KJN1**: el DT de 7.2.2 pedía 600 MHz y el driver solo tiene 700: no sondeaba, y camss, que espera a todos los
  sensores de su grafo, tampoco registraba la frontal.
- **IMX766**: el DT de fábrica confirma lo de Danila (CSIPHY 3, CCI máster 1, MCLK3 19,2 MHz, reset GPIO 78, VANA 79,
  VDIG 108, VIO 49, GPIO 72). Estuvo en lista negra hasta el 2026-09-14 (sin él cargado no se ve ninguna cámara); desde
  entonces se carga sola al arrancar, como los otros dos sensores.
- **IMX471**: el driver de 7.2.2 anunciaba SGRBG10; un fotograma en bruto tiene los verdes en (0,1) y (1,0), y el
  driver de mainline dice SRGGB10 sin volteo. Con GRBG salía tinte verde/magenta y cuadros de color.
- **Color**: con `uncalibrated.yaml` el nivel de negro se estima con la imagen y salen manchas de color;
  `device/camaras/libcamera/imx766.yaml` e `imx471.yaml` lo fijan en 64 (10 bits) en `/etc/libcamera/ipa/simple`.
- ⚠️ **Trasera‑1 (`s5kjn1`), el color VARÍA entre fotos** (observado por el usuario el 2026-11-22: «a veces se ve
  mejor y a veces peor»). Un tinte que cambia apunta a **balance de blancos / ganancias que derivan**, no a una
  matriz de color fija mal puesta — el parche `0006` (matriz de color) ya está upstream, así que no es eso. Lo
  primero que mirar cuando se retome: si el sensor se queda con ganancias sin reiniciar entre capturas (AWB por
  software del IPA simple sin estado inicial) y si falta su `.yaml` de calibración junto a `imx766.yaml`.
- ⚠️ wireplumber (y la app) solo ven calibraciones o cámaras nuevas al **reiniciarlo** (nunca en llamada). Si
  `cam -l` no lista cámaras con «Failed to setup link … Resource busy», otra app tiene la cámara cogida.
- **Módulos de fábrica** (`vendor_a` `lib64/camera/com.qti.sensormodule.abra_qtech_*.bin`): principal
  `abra_qtech_ak7377_actuator` + eeprom `p24c128e` + PDAF `imx766_wide_pdaf`; ultra gran angular
  `abra_qtech_dw9800w_actuator`.
- Pruebas: `scripts/93-camaras.sh`, `pruebas/camaras/probar-imx766.sh`, `fotos-prueba.sh` (con linterna),
  `raw-bayer.sh` (orden Bayer real y rejilla) y `agc-estado.sh` (exposición y ganancia).
- ✅ **Autoenfoque** (2026-09-14): libcamera propio (`packages/libcamera`, `scripts/94-libcamera.sh`) con los
  parches de surya 0009 (LensPosition/AfMode para las apps) y 0010 (nitidez en el ISP por software + escalada en el
  IPA simple); el algoritmo corre donde el fichero de ajuste lista `- Af:` y el sensor tiene lente
  (`device/camaras/libcamera/s5kjn1.yaml`). Usuario: «enfoca bien la gran angular».
- ✅ **Enfoque de la principal (r130, parche 0048)** — usuario: «ahora va perfecto y enfoca»: `actuator@c` en CCI1 bus 1 con `compatible = "asahi-kasei,ak7375"`
  (no hay driver del AK7377; se prueba como el más cercano de la familia), `vdd-supply = vreg_camw_vaf_1p8`
  (GPIO 96), `vio-supply = vreg_cam_vio_1p8`, y `lens-focus` en `camera@10`. El nombre del actuador sale del módulo
  de fábrica: `vendor_a` montado en solo lectura (`mount -o ro -t erofs /dev/mapper/vendor_a /mnt/vendor-ro`) y
  `strings lib64/camera/com.qti.sensormodule.abra_qtech_imx766_wide.bin | grep actuator`.
- Pendiente: exposición/ganancia de la IMX766 (sin sensor helper).
- ⏳ **Pendiente (decisión del usuario, 2026-09-14): mejorar la app principal (Snapshot)** en vez de usar otra.
  Probada **COSMIC Camera** (`cosmic-ext-camera` 1.3.6): usa libcamera en proceso con estas calibraciones y el
  autoenfoque, pero en las traseras pide además un flujo **en bruto a resolución máxima** (principal 7424×5568,
  ultra gran angular 8160×6144), así que el sensor trabaja en su modo grande (revelado a 54 ms/fotograma, tirones) y
  las fotos las revela la propia app desde el bruto con los metadatos que le dé libcamera. La selfie va bien (un solo
  modo). Al usuario no le gusta; se aparca.


## ★★ Cada llamada puede dejar el móvil MUDO: el enrutador de wireplumber se rompe (2026-09-18)

**Síntoma del usuario**: «en epo2 no me están sonando las llamadas entrantes y creo que
tampoco notificaciones».

**Qué pasa**: el cambio de perfil de la tarjeta que hace toda llamada
(`HiFi (…)` → `Voice Call (Earpiece)` → `HiFi (…)`) rompe el despachador de eventos de
wireplumber **si el sumidero está ACTIVO en ese momento** — que es justo lo que ocurre
mientras suena el timbre. A partir de ahí **ningún flujo nuevo se enlaza**: ni avisos, ni
timbre, ni la llamada siguiente. El móvil queda mudo hasta reiniciar wireplumber.

**Cómo se ve, sin adivinar nada**:

| Dónde | Qué aparece |
|---|---|
| `pactl list sink-inputs` | flujos `libcanberra` **`Corked: yes`** con **`Sink: 4294967295`** (= ningún sumidero). Se acumulan: había **21**. |
| `journalctl --user -t pipewire-pulse` | `[feedbackd] timeout on stream … channel:0` |
| `journalctl --user -t wireplumber` | `wp-event-dispatcher … failed: failed to activate item: Object activation aborted: proxy destroyed` seguido de `s-linking: … Link was not activated before removing` |
| cualquier cliente | `paplay` da `Stream error: Timeout` y `pw-play` se queda colgado (rc=124) |

⚠️ **No es cosa del rol ni del tema de sonido ni de feedbackd**: falla igual con
`media.role` = event / Notification / Ringtone / Multimedia / sin rol, y falla también con
`pw-play`, que es cliente nativo de PipeWire. El grafo sigue corriendo (`pcm0p` en RUNNING
con `hw_ptr` avanzando); lo que no ocurre es el **enlace** del nodo nuevo, que se queda en
`state=suspended` sin que wireplumber registre nada.

**Medido (A/B, 2026-09-18)** — ciclo de perfil `HiFi → Voice Call (Earpiece) → HiFi`:

| Estado del sumidero al cambiar de perfil | Rompe |
|---|---|
| en reposo (SUSPENDED) | **0 de 5** |
| activo (RUNNING, con silencio inyectado) | **2 de 3** |

El error `wp-event-dispatcher … failed` sale en **todos** los cambios de perfil (23 en la
tanda), pero solo deja el enrutado roto cuando el sumidero estaba activo: el mensaje por sí
solo no prueba el fallo. Confirmado por el usuario en vivo: «me ha sonado en la de antes,
pero ahora no» — justo después de que la simulación del ciclo lo rompiera.

**Explica el fallo intermitente de las llamadas** que llevaba días sin causa (una llamada
muda, otra por el altavoz): la llamada anterior dejaba el enrutado roto.

**Mitigación desplegada y VERIFICADA EN EL MÓVIL** (2026-09-18 16:41,
`device/supervisor/supervisor-llamada-bt.py`): al **colgar**, el supervisor comprueba el
enrutado y, si está roto, reinicia wireplumber. Prueba de punta a punta: se rompió el
enrutado a propósito (3 ciclos de perfil con el sumidero activo) →
`enrutado antes de reparar: False` → reinicio → `enrutado despues: True`, con la línea
`ENRUTADO ROTO tras la llamada -> wireplumber reiniciado (reinicio=ok, enrutado despues=ok)`
en `~/.local/state/spacewar/llamadas.log`. Desplegado con `SOLO_SUPERVISOR=si sh scripts/89-cadena-llamada-bt.sh`
(md5 repo = instalado `3a291e45…` **en esa versión de las 16:41**; el mismo día se corrigió cuatro
veces más — ver la sección de la sonda al final), sin `Traceback` en el diario.

- `Sistema.enrutado_vivo()` reproduce **0,2 s de silencio** (`~/.local/state/spacewar/silencio.wav`,
  que se genera solo): si el enrutado está roto, `paplay` expira; si está bien, sale en un
  pestañeo y **no se oye nada**. Instrumento silencioso, por eso se puede usar en cada llamada.
- `Supervisor._reparar_enrutado()` solo actúa **sin llamada en curso** (se revalida antes y
  después de la prueba) — ⚠️ nunca reiniciar wireplumber/pipewire en llamada — y deja
  constancia en el acta: `ENRUTADO ROTO tras la llamada -> wireplumber reiniciado`.
- Cubierto por `test_supervisor.py` (clase `Enrutado`): detecta, repara, deja constancia y no
  toca nada con llamada en curso.

⏳ **Pendiente**: la mitigación tapa el síntoma, no arregla el fallo. La causa de fondo está
en el cambio de perfil con nodos activos (wireplumber 0.5.17 + PipeWire 1.6.8). Queda por ver
si suspender el sumidero **antes** de cambiar de perfil lo evita — ojo, `device/wireplumber-llamada/suspend-node-surya.lua`
hace justo lo contrario durante la llamada, y por una razón medida (remontar el AFE con el
casco Bluetooth estrella el ADSP).

## ★★★ LA SONDA DE LLAMADAS, y el día que la sonda era el fallo (2026-09-18)

**Qué es**: un acta de cada llamada, dentro de `device/supervisor/supervisor-llamada-bt.py`
(clase `Acta`), **no** un demonio aparte: solo mira mientras hay llamada y en reposo no
ejecuta ni un mandato. Escribe en **`~/.local/state/spacewar/llamadas.log`** (recorte a 1 MB;
`/var/log` y `/var/lib` no son escribibles por `edi`, y `/var/tmp` lo limpia `systemd-tmpfiles`).

```sh
SOLO_SUPERVISOR=si sh scripts/89-cadena-llamada-bt.sh    # desplegar (md5 repo = instalado)
ssh epo2lan 'tail -25 ~/.local/state/spacewar/llamadas.log'   # leer la última acta
python3 -m pytest device/supervisor/test_supervisor.py -q     # 47 pruebas (NO están en pruebas/)
```

Verifica y fecha con `+s`: perfil de tarjeta y casco · auricular encendido con el altavoz de
abajo apagado (y al revés) · en Bluetooth las dos rutas SLIMBus y el SCO · que exista camino de
subida · el silencio del micro **contrastando el DSP con callaudiod** · volumen, calibración y
PCM de voz. Así quedan registrados el salto a manos libres y la vuelta.
⚠️ Todo **por `numid`**, nunca por nombre: 100 volumen · 101 mute micro · 102 calibración ·
105 auricular · 106 altavoz · 1313 subida micro · 1314 subida BT · 1315 bajada I2S · 1320 bajada BT.

### 🔴 La sonda dejaba muda la llamada con casco (commit `a1759ca`)

La sonda **acertó** con el fallo que el usuario oyó («la segunda con cascos y no sonaba»): el
acta lo decía a los 6,7 s, `perfil Bluetooth sin enlace SCO en pie`. Pero la causa era ella misma.
`_acta("abrir")` está en `revisar()` **antes** del montaje (`asegurar_casco`), y leía nueve
controles con `amixer` a **4 s de plazo cada uno**; **`numid=105` expira SIEMPRE con el perfil en
Bluetooth** (de ahí el `auricular=None` de todas las actas con casco) y costaba 4 s para devolver
`None`. Una llamada de 12 s salía muda porque el montaje **no había empezado**.

Arreglo, **solo en la sonda, sin tocar el montaje**: `control()` con plazo **0,6 s** (mira, no
manda) y `foto()` no pregunta por auricular ni altavoz en Bluetooth. Medido de `CallAdded` a
`CIRCUITO MONTADO`:

| tramo | antes (17:08) | después (17:13) |
|---|---|---|
| foto de la sonda | 6,8 s | **0,10 s** |
| eSCO en pie | 0,0 s | 0,4 s |
| `chip not enumerated` + sacar/meter la tarjeta | 7,3 s | **no ocurre** |
| **total** | **17,0 s** | **4,1 s** |

🔑 Los 7,3 s del `chip not enumerated` **no eran coste fijo, eran secuela del retraso**: llegando
tarde, el kernel ya había gastado sus reintentos contra un chip sin enumerar. Montando a tiempo el
flujo arranca a la primera y el apaño ni se ejecuta. Por eso bajó a 4 s y no a los ~10 estimados.
⛔ El tramo de 5 s de `_esperar_circuito(5)` **no se toca**: es margen deliberado para los
reintentos de PipeWire y es la parte del montaje con historial de romper llamadas.

### Los cuatro falsos positivos de la sonda (commits `2b670d1` y `7701a4f`)

1. Verificaba la foto del **cierre**, con la tarjeta ya de vuelta en HiFi con toda la razón ⇒ «la
   tarjeta no está en un perfil de llamada» en toda acta. Ahora `pasada(t, verificar=False)`.
2. `altavoz_visto` se activaba con `"Speaker" in perfil`, y el perfil normal **se llama**
   `HiFi (Headphones, Mic1, Speaker)` ⇒ «probado: manos libres» sin tocar el botón.
3. Imprimía `mute=True` para el micro **abierto**: se lee como lo contrario. Ahora `micro_abierto=`.
4. Marcaba el estado de **entrada** sin volver a mirar: con casco, entrar sin SCO es lo normal
   (llega en `a2dp-sink`, el enlace sube a los ~2 s), así que la primera llamada realmente buena
   cerró «CON 1 FALLO(S)». Ahora el fallo que deja de aparecer pasa a `resueltos` con su
   `✅ resuelto:` fechado y el acta cierra **`OK (N reparado(s) sobre la marcha)`**, con los
   `REPARADOS:` aparte de los `FALLOS:`.

⚠️ El mismo patrón en los cuatro y en el gate del script 89 (commit `91ba95b`, que confundía
«el móvil está dormido» con «hay una llamada» por una tubería a `grep -q`): **un estado que se
parece al que buscas no es el que buscas**.

### Secuela que conviene vigilar

Al abandonar un montaje («dejo el montaje: pactl no contesta»), la tarjeta se quedó en
**`Voice Call (Speaker)` sin llamada durante 25 min** — el móvil, mudo para todo. El supervisor
sabe corregirlo (`tarjeta_fuera_de_llamada`), pero **solo reacciona a eventos**, y sin llamadas no
llega ninguno. Reiniciar el supervisor lo arregla al instante. ⏳ Falta una red de seguridad que no
dependa de un evento.

### Conectar el casco a mitad de llamada

✅ **Ya funciona, no hace falta tocar nada**: el lector de `pactl subscribe` es **permanente** (no
solo mientras monta), así que cada `on card #` / `on sink #` dispara `revisar()` haya llamada o no;
conectar el casco cuenta además como **petición de reintento** y `objetivo()` devuelve `"casco"`.
Cubierto por `test_casco_conectado_a_mitad_mete_la_tarjeta_una_vez_y_el_enlace_despues` y
`test_casco_desconectado_y_reconectado_vuelve_al_casco_respetando_la_guarda`.
⏳ Falta probarlo en vivo (las pruebas usan un sistema simulado).

⏭️ **Abierto**: por qué el casco llega siempre en `a2dp-sink` al entrar la llamada. Si estuviera ya
en HFP no habría montaje que hacer y esos 4 s serían casi cero.

## Llamadas: el buscador de contactos que se congelaba (2026-09-21, ampliado 2026-10-15)

`scripts/43-calls.sh` compila en ia `packages/calls` (gnome-calls **50.0-r101**, la misma versión que la de serie
más cinco parches) y, con `INSTALAR=si`, la instala en el móvil y reinicia `calls-daemon.service` del usuario.
Función completa documentada en `odd/tasks/llamadas-contactos.md`; se aplican también a suria (regla del usuario:
«los cambios de las apps, a ambos»).

- **`0001-contacts-box-filtrar-a-plazos…`** — el de surya (`suria/parches/packages/calls`, 03-09), que **nunca se
  había portado**: el 21-09 spacewar llevaba `calls-50.0-r0` de Alpine `edge/community`. Activa `incremental` en
  el `GtkFilterListModel` de la pestaña Contactos: el mismo trabajo, repartido en ratos ociosos. En surya el
  congelado por tecla bajó de hasta ~25 s a unos pocos segundos (sin medida controlada).
- **`0002-contacts-box-no-filtrar-hasta-tres-caracteres`** — petición del usuario: **no filtra hasta 3
  caracteres** (sin contar los espacios de los extremos). Con 1-2 letras la lista se queda entera y teclear no
  refiltra nada; al llegar a 3 filtra como siempre y al volver a bajar de 3 se ve de nuevo la lista completa. Una
  sola letra era el peor caso: cientos de filas (avatar + un botón por número) que pintar en cada pulsación.

- **`0003-contacts-box-indice-de-busqueda-precalculado`** (2026-10-15, S1) — la causa raíz del congelado: cada
  tecla filtraba con Folks `SimpleQuery` sobre los ~2500 contactos, y el campo `phone-numbers` forzaba
  normalizar teléfonos con libphonenumber (`E.PhoneNumber`, creando objetos) **por contacto y por tecla**. El
  buscador compara ahora contra un blob precalculado por contacto (nombre, aliases, apodo, nombre estructurado,
  teléfonos crudo y normalizado, en minúsculas) y una variante de solo dígitos: cada tecla es un `g_strstr_len`
  por blob sin ninguna asignación. Conserva 0001 y 0002 y la búsqueda por número («600 12» encuentra al 600123456).
- **`0004-contacts-row-estrella-de-favorito-compartida`** (S4, mitad Calls) — cada fila de Contactos gana un botón
  plano `starred/non-starred` junto al nombre. Escribe `Individual.is-favourite` vía folks, **la misma propiedad
  (starred de EDS) que usa la Agenda**: un estado compartido, se alterna desde cualquiera de las dos apps.
- **`0005-bloqueados-tabla-pestana-rechazo-y-nota-eds`** (S3) — números bloqueados:
  - BD propia `~/.local/share/calls/blocked.db` (GOM; no toca el esquema de `records.db`): número, E.164,
    etiqueta, **razón**, boolean `blocked` y fecha. Desbloquear = interruptor a off, **la fila se conserva**.
  - Entrante bloqueada: se rechaza sin timbre y **sin notificación de perdida**, pero **queda en el historial**
    (decisiones del usuario). La comparación es por `E.PhoneNumber` (normalizado o crudo exacto): solo ese número,
    no el contacto entero.
  - Pestaña «Bloqueados» en el stack principal + bloqueo rápido desde el menú contextual de cada fila del historial.
  - Si el número es de un contacto, sus **observaciones (EDS vía folks)** ganan la línea `Bloqueado en Llamadas
    (fecha): razón`; al desbloquear se reescribe como `Desbloqueado (fecha): razón` (se conserva la info). Escrito
    de mejor esfuerzo: backend sin escritura → aviso y la tabla manda.
  ⚠️ Sin compilar todavía (permiso para `ia` pendiente): la parte de notas folks en C y los iconos de la UI son lo
  primero que se verificará al probar.

Y el compañero de agenda: `scripts/45-agenda.sh` compila `packages/gnome-contacts` (**51.0-r100**, un parche:
botón «Llamar» `tel:` en cada teléfono de la ficha y estrella visible en la cabecera — antes favoritear solo estaba
en el menú hamburguesa). ⚠️ El `pkgver` del APKBUILD debe coincidir con la versión del árbol base: comprobar
`apk info -v gnome-contacts` en el teléfono antes de compilar (el script `--ver` lo recuerda).

⚠️ **`pkgrel=100/101`, y no `r1` como en surya**: una recompilación de Alpine (`r1`…`r99`) pisaría el parche en un
`apk upgrade` sin avisar. Una versión nueva (50.1…) sí lo sustituye → comprobar con `sh scripts/43-calls.sh --ver`.
⚠️ En el `APKBUILD`, `makedepends="` va **en la columna 0**: si va indentado, pmbootstrap lo lee vacío y la
compilación muere con `abuild-meson: not found` (trampa documentada en surya).

Medir el congelado: `pruebas/calls-sonda-latencia.py` llama en bucle a `org.gtk.Actions.DescribeAll` de Calls,
que se atiende en su bucle principal; en reposo la mediana es ~15 ms y cada congelado sale como `BLOQUEO N ms`.

## Teclado: Shift+Tab en la fila de atajos (2026-09-21)

Petición del usuario: en la terminal, **`<ctrl>c`, `<ctrl>D` y `<shift>Tab` justo detrás de `<alt>`**
(`scripts/91-teclado-atajos.sh`, lista `TRAS_ALT`: los mueve, no los duplica). Los dos primeros aparecieron; **Shift+Tab
no, y no aparecía desde el 14-09**, cuando se añadió: el diario lo decía, `Invalid shortcut '<shift>Tab': (0xff09/0x1)`.

**Causa (stevia 0.57, `src/pos-shortcuts-bar.c`)**: cada atajo pasa por `gtk_accelerator_valid()` de GTK3, que
**rechaza cualquier acelerador con Tab** (lo reserva para moverse entre controles). La excepción que dibuja `Tab` como
«⭾» (`pos_accelerator_get_label`) solo cubre teclas **sin modificadores**. `ISO_Left_Tab` y `<shift>ISO_Left_Tab`
también se rechazan (probado). Enviarlo sí funcionaba: `pos_vk_driver_key_press_gdk()` pulsa Tab con Shift.

**Arreglo**: `packages/stevia` = receta de Alpine edge (0.57.0-r2, con su `emoji-db.patch`) + `0001-shortcuts-bar-
dibujar-shift-tab.patch`, que lo dibuja como «⇧⭾». `pkgrel=100`. `INSTALAR=si sh scripts/44-stevia.sh` compila en ia,
instala y reinicia `mobi.phosh.OSK.service`; `--ver` comprueba. Ajustes a la receta para pmbootstrap: sin
`$pkgname-schemas` en makedepends (subpaquete propio, solo para las pruebas), `py3-docutils` en vez de `cmd:rst2man`,
`uim-dev` directo (pmbootstrap no evalúa el `case` de arquitecturas) y `!check` (las pruebas piden xvfb).
Verificado: `0001` aplicado en el log de ia y **ningún `Invalid shortcut` desde el reinicio del teclado**.

⚠️⚠️ **Instalarlo arrastró 25 paquetes más** (21-09): stevia se compila contra el edge actual (`libgnome-desktop-3`
44.5 → 51.0) y el móvil iba por detrás (191 actualizaciones pendientes), así que `apk` subió phosh, phoc,
evolution-data-server 3.60 → 3.62, gnome-contacts y gnome-calendar 50 → 51, chatty, folks, portales… `apk fix` lo da
por coherente, pero los procesos en marcha siguen con lo viejo en memoria: **reiniciar el móvil**. Desde entonces
`43-calls.sh` y `44-stevia.sh` **simulan antes** y se paran enseñando la lista si `apk` fuera a tocar algo más que
lo nuestro (`ACTUALIZAR_OTROS=si` para seguir).

## Lo nuestro frente a las actualizaciones (2026-09-21)

**`sh scripts/verificar-instalado.sh`** comprueba, sin tocar nada, que en el móvil sigue exactamente lo nuestro:
cada fichero de **`device/MANIFIESTO.tsv`** (fichero del repo → dónde se instala → script que lo instala; 85
entradas, generado cotejando por md5 lo instalado con el repo) con su md5, que cada paquete propio lleve **nuestro
`-rN`**, la línea `KernelExperimental` de `main.conf` y el enlace de la UCM en `conf.d`. Si algo no cuadra dice qué
script lo reinstala y sale con 1. Pasarlo **después de cada `apk upgrade`**.

Resultado del 21-09 al preparar el manifiesto: **85 de 85 ficheros iguales**, ningún paquete propio sustituido.
Probado en vivo el 21-09: sale limpio en ~10 s, y con tres fallos provocados (un fichero cambiado, una entrada
inexistente y un `pkgrel` distinto) marca los tres, sale con 1 y propone el script exacto de cada uno. Lo
que corre peligro en una actualización son los ficheros nuestros que **pertenecen a un paquete** del sistema: solo
**`NP1.conf` y `HiFi.conf`** (de `alsa-ucm-conf-qcom-sc7280`): si ese paquete se actualiza, los machaca en silencio
(`sh scripts/60-llamadas.sh` los repone). ⚠️ Corrección: se llegó a decir que también 13 ficheros de la calibración
de voz eran de `firmware-nothing-spacewar`; **no**: esos 13 son el firmware del propio paquete (`adsp.mbn`,
`modem.mbn`, `cdsp.mbn`…) que comparte directorio con nuestra calibración, y ninguno de nuestros 29 es de un paquete. Lo de `/etc` no: `apk` deja
el nuevo como `.apk-new`. Nuestros paquetes llevan `-r90`…`-r134` para que las recompilaciones del repositorio no los
sustituyan; una **versión nueva** del programa sí lo haría.

⏳ **PENDIENTE (petición del usuario, 21-09)**:
1. **Repositorio de paquetes propio con más prioridad** que los oficiales: que nuestros `.apk` (kernel, ModemManager,
   NetworkManager, callaudiod, hexagonrpcd, libcamera, calls, stevia…) se sirvan desde un repositorio firmado y
   `apk upgrade` los prefiera, en vez de instalarlos sueltos con `--allow-untrusted`. Así una versión nueva del
   repositorio oficial no los pisa y la instalación limpia los trae solos.
2. **Vigilante de actualizaciones de los paquetes modificados**: que avise cuando el repositorio oficial publique una
   versión nueva de algo que llevamos parcheado (y, de paso, de `alsa-ucm-conf-qcom-sc7280`, que
   machaca nuestra UCM), para rehacer el parche sobre ella y verificar con
   `verificar-instalado.sh`.

## Casco conectado A MITAD de llamada: el montaje fallaba por una espera mal contada (2026-09-21)

Primera prueba real (21-09 13:42): la llamada empezó sin casco (`casco=None` en el acta) y el casco se conectó a los
4,5 s. El montaje falló dos veces y solo salió tras pulsar el altavoz y volver. Causa, en el diario del kernel: la
tarjeta pasó a Bluetooth **antes** que el SCO y PipeWire se puso a reintentar abrir el chip (`wcn-bt-slim: chip not
enumerated` cada ~0,6 s, el «PipeWire lo reintenta ~6,5 s» de la sección de Bluetooth). Mientras reintenta,
pipewire-pulse no contesta y `pactl list cards` expira a los 4 s; el paso esperaba **4 s**, así que **una sola
consulta colgada se comía todo el plazo** y el supervisor daba por fallido «la tarjeta no pasa a Bluetooth» aunque
la tarjeta **sí** estaba en Bluetooth.

- Descartado cambiar `pactl` por `pw-dump`: habla con el mismo PipeWire ocupado. Sin llamada no se reproduce (medido:
  forzando el cambio de perfil, `pactl` sigue en ~60 ms): solo pasa con el DSP y el chip de por medio.
- **Arreglo** (`Supervisor._esperar`): el tiempo que la propia comprobación pasa colgada **no cuenta** contra el plazo,
  con tope de 3 × plazo; queda en el diario («la comprobación estuvo colgada N s: no cuenta»). 3 pruebas nuevas
  (`EsperarConComprobacionColgada`), 50 en total. Desplegado (md5 repo = instalado `5beda25c…`).
- ✅ **Probado en vivo (21-09 15:15)**: llamada sin casco, casco conectado a mitad → `MONTAJE 1/3` → `CIRCUITO
  MONTADO en 1,2 s`, a la primera y sin tocar el altavoz (usuario: «funciona perfecto»). ⚠️ En esa llamada **no hubo
  consulta colgada** (la carrera de las 13:42 no se dio), así que el arreglo de `_esperar` **aún no se ha visto actuar
  en vivo**: cuando actúe, el diario dirá «la comprobación estuvo colgada N s: no cuenta».
- El acta ahora registra el casco conectado a mitad como `probado: casco (conectado a mitad de llamada)`; antes ponía
  «auricular/altavoz» porque lo decidía al empezar la llamada. 51 pruebas.

## La VPN, gestionada por NetworkManager (2026-09-24) — ⚠️ SUPERADO el 2026-10-02

> **Esto ya no es así.** El 02-10 se **borró el perfil `egp` de NetworkManager** y la VPN volvió a la unidad de
> systemd, encendida a mano desde el botón del panel. Ver «La VPN, a mano desde el botón del panel» al final. Lo que
> sigue se queda como histórico: explica por qué se intentó con NetworkManager y qué se midió.

Antes la llevaba `openvpn-egp.service`: el túnel vivía siempre y, al quitarle el keepalive para que no despertara al
móvil (`95-vpn-sin-keepalive.sh`), **se quedaba muerto sin avisar** cuando caducaba el NAT. Ahora la lleva
**NetworkManager** (perfil `egp`, el complemento `networkmanager-openvpn` ya estaba instalado): el túnel **baja al
suspender y sube al despertar** con el resto de la red, así que no hay keepalive que mandar ni que recibir mientras
duerme, y nunca queda un túnel viejo. La unidad de systemd queda parada y desactivada.

`sh scripts/95-vpn.sh` (y `--ver` para comprobar) deja:
- **`ipv4/ipv6.never-default = yes`** — ⚠️ sin esto la VPN **se queda la ruta por defecto** y todo el tráfico se va por
  el túnel (pasó el 24-09 al levantarla). Con ello solo añade sus rutas internas.
- **Quién la levanta**: `connection.secondaries` de las redes con salida la hacía subir **sola** ~3 s después de
  conectarse esa red. ⚠️ **Quitado el 2026-10-01 por decisión del usuario**: con la atadura puesta, **apagar la VPN
  desde phosh no se queda**. Cada sueño apaga la red (`reason 'sleeping'`) y al despertar NetworkManager la rehace y,
  en la fase «secondaries», vuelve a levantar la VPN; con este móvil durmiendo cada pocos minutos parece que «se
  arranca sola». Ahora se levanta **a mano** (phosh o `vpn-egp.sh subir`), y el script la deja así por omisión
  (`BASES=""`, que además quita la atadura si estuviera). Para volver atrás: `BASES="Default Edu"`.
  ⚠️ Consecuencia aceptada: tras cada sueño queda abajo, así que **no hay acceso remoto por la VPN** hasta levantarla.
  En surya se dejó automática.
- **`/usr/local/bin/vpn-egp.sh`** (`subir`/`bajar`/`estado`) para el resto de casos, como con el punto de acceso
  activo. ⚠️ `nmcli connection up egp` **a secas falla** («Could not find source connection»): con un Hotspot activo
  NetworkManager no elige la conexión base. Y ⚠️ **no vale la interfaz de la ruta por defecto**: con datos móviles es
  `qmapmux0.0`, que NetworkManager lista pero sin conexión activa; la suya es `qrtr0`.

⚠️ **Una conexión VPN no puede estar activa dos veces**: si subió con los datos y se quiere sobre otra red, primero
`vpn-egp.sh bajar`. Por eso se dejó **un solo perfil** y se borró el `egp-datos` que se llegó a crear.

### 2026-09-28: el otro fallo de la rotación — el servicio arrancó sin sensores y no volvió a buscarlos

Tras 14 h encendido: `HasAccelerometer=false` y **un solo arranque** del servicio. `iio-sensor-proxy` busca los
sensores **una vez** (`find_sensors`) y después solo reacciona a avisos de udev; si arranca antes de que el
concentrador del ADSP conteste (~86 s) y no llega ningún aviso, se queda sin acelerómetro **todo el arranque**. El
parche `0001` arregla el aviso *cuando el sensor aparece*, pero no sirve si nunca aparece. Arreglo inmediato:
`systemctl restart iio-sensor-proxy` (vuelve a buscar; con el parche, phosh lo recoge solo: se vio pasar de
`undefined` a `"normal"`).

**Arreglo permanente**: `device/energia/esperar-sensores-adsp.sh` + el complemento de systemd
`iio-sensor-proxy-esperar.conf` (`ExecStartPre`, hasta 150 s, `TimeoutStartSec=240`), que lo instala
`sh scripts/41-iio-sensor-proxy.sh --ajuste`. Si se agota el plazo **no falla**: arranca igual (mejor con luz y
proximidad que sin nada) y lo deja dicho en el diario. ⚠️ Cada comprobación cuesta ~6 s aunque el concentrador esté
listo: es lo que tarda `ssccli` en dar su primera lectura, no el plazo.

## Botones propios en los ajustes rápidos de phosh (2026-10-01)

El usuario quería un botón en el panel de phosh para arrancar y parar la VPN (`systemctl start|stop openvpn-egp`,
**por systemd y no por NetworkManager**, decisión suya) y otro para Waydroid (`waydroid session start|stop`).

**Los botones del panel no son configurables**: cada uno es un complemento **compilado** (`.so` en
`/usr/lib/phosh/plugins`), y los visibles se eligen en `sm.puri.phosh.plugins quick-settings`. El
`simple-custom-quick-setting` que trae phosh es solo una demostración (cambia su icono, no ejecuta nada) y **no se
puede compilar un complemento por fuera**: phosh no instala cabeceras ni `pkg-config`. Por eso hay **phosh propio**:
`packages/phosh/` (receta de pmaports + `pkgrel=100` + nuestro parche + `appstream-dev`, que meson exige y pmaports
no lista).

Para no recompilar phosh cada vez que se quiera un botón, el parche añade **un complemento genérico con cuatro
ranuras** (`mandato1`…`mandato4`): cada ranura lee de los ajustes `titulo`, `icono`, `icono-apagado`, `encender`,
`apagar`, `estado`, `intervalo` y `espera`. Son cuatro copias del mismo código porque **el nombre de un tipo de
GObject debe ser único en el proceso** y phosh carga todos los complementos en el suyo.

Tiene los mismos estados que un botón nativo: encendido/apagado según la **salida** del mandato `estado` (0 =
encendido), **texto** propio bajo el icono (su 1.ª línea), **icono** distinto por estado, **«encendiendo…»** con el
botón insensible mientras el mandato corre, y **página de detalle** al pulsar largo (el resto de líneas). El
temporizador de recomprobación corre **solo con el panel desplegado**, para no gastar batería.

⚠️ Un complemento nuevo solo se carga **al arrancar phosh**: cerrar sesión. Cambiar los mandatos de una ranura es en
vivo. ⚠️ pmaports **ya trae phosh** y pmbootstrap hace caso a *esa* receta: el script aparta la de pmaports
(**fuera** del árbol: una carpeta `phosh-aparcada` con `pkgname=phosh` dentro hace que pmbootstrap rechace todo) y la
devuelve al terminar.

**Instalado y en el móvil el 2026-10-02**: `phosh-99990.57.0-r100` (solo se sustituyeron nuestros 6 paquetes de
phosh, sin arrastrar nada más), los 4 complementos en su sitio, las ranuras 1 y 2 configuradas y añadidas a la lista
de botones visibles, y sus mandatos de estado contestando («apagada» / «parado»).

`INSTALAR=si sh scripts/96-botones-mandato.sh` · `--ver` para comprobar · `SOLO_CONFIG=si` reconfigura las ranuras
sin compilar · `INSTALAR=si SOLO_INSTALAR=si` instala los `.apk` ya compilados sin volver a compilar · cómo añadir un
botón nuevo: **`docs/BOTONES-AJUSTES-RAPIDOS.md`**.

## ⛔ El MICRÓFONO abierto no deja dormir al móvil (2026-10-02)

Toda la mañana despertándose «a cada momento» y encendiendo la pantalla. **No lo despertaba nada de fuera: no
llegaba a dormir.** Los intentos de suspensión entraban y salían **en el mismo segundo**:

```
08:13:16 PM: suspend entry (deep)
08:13:16 PM: suspend exit          ← 0 segundos dormido
08:13:54 PM: suspend entry (deep)  ← lo reintenta 38 s después, igual
```

**95 intentos a la hora** entre las 6 y las 9. Y como cada reanudación enciende la pantalla, de ahí lo que se veía.

**La causa**: `gnome-control-center --gapplication-service` llevaba **17 h 35 min** en marcha con **dos flujos de
grabación abiertos y sin pausar** (`Corked: no`). Es el medidor de nivel del panel de Sonido de «Ajustes»: una vez
abierto el panel, el servicio **sigue capturando aunque se cierre la ventana**. Con el micro abierto:

| Medida | Con el micro abierto | Tras cerrar «Ajustes» |
|---|---|---|
| PCM en marcha | `pcm0p` (reproducción) y `pcm2c` (**grabación**) RUNNING | ninguno (a los ~30 s) |
| Interrupciones del ADSP (`ipcc_0` + `glink-smem`) | **754/s** | **0/s** |
| Mensajes APR por ciclo | ~1.660, en su mayoría `0x10D99`/`0x10D9A` | — |

`0x10D99` y `0x10D9A` son **«escritura hecha»** y **«lectura hecha»** de un flujo de audio (ASM): el ADSP avisaba
unas 200 veces por segundo, esos avisos llegan por interrupción al procesador y **abortan la suspensión justo al
cerrarla**. Mismo patrón que el cuelgue de surya por el UART del Bluetooth: el despertar llega antes de acabar de
suspender.

**Descartados con medidas** (para no repetir el camino): el USB-C (`ucsi-source-psy`, 11.932 eventos, pero todos de
13 h antes y el contador quieto), la red (cero paquetes en `wlan0` y en `qmapmux0.1` entre un intento y el
siguiente), las alarmas del reloj (ninguna puesta) y las fuentes de despertar del kernel (**`wakeup_count` a cero en
todas**, que es justamente la firma de «no lo despierta nada: no cierra la suspensión»).

**Herramienta**: `pruebas/energia/audio-que-no-deja-dormir.sh` (solo lectura) deja esto en 20 segundos: PCM en
marcha, flujos sin pausar con su proceso, quién tiene abierto `/dev/snd`, interrupciones del ADSP por segundo y si
los ciclos de suspensión duermen o no.

⚠️ **Dos trampas de medida aprendidas aquí**:
- Este kernel **no emite nunca** `Timekeeping suspended for N seconds` (cero veces en todo el arranque): no sirve
  como indicador, aunque la cabecera de `50-despertar-y-sensores` lo dé por hecho. Se mide con los sellos de
  `PM: suspend entry` / `exit`.
- **Estar conectado por SSH falsea la medida**: cada mandato lo despierta nada más dormirse, así que los ciclos de
  0-1 s se siguen viendo con el audio ya cerrado. Para juzgar si duerme hay que **dejarlo en paz** unos minutos sin
  ninguna sesión y leer luego el diario.

**Comprobado tras cerrarlo** (02-10 11:45, suspensión programada y sin nadie conectado): **durmió 252 s de un
tirón** y el ADSP mandó **0 mensajes APR** en ese sueño (antes, ~1.660 por intento fallido).

**Vigilante, hecho el 02-10** (`scripts/97-vigia-microfono.sh`): temporizador **de usuario cada 5 minutos** que
avisa si hay captura en marcha con la pantalla apagada. **Solo avisa, no cierra nada** — cerrar por su cuenta podría
cortar una llamada, un mensaje de voz o una grabación. Avisa en el diario siempre y, a la **segunda vez seguida**,
con una notificación en pantalla (el diario no lo mira nadie). No avisa si hay llamada, si la pantalla está
encendida, o si no puede preguntar al módem (mejor callar que dar un falso aviso). Es de usuario porque necesita la
sesión para saber **qué aplicación** tiene el micrófono.

⚠️ Dos cosas comprobadas al probarlo con una grabación de 12 s:
- **Detecta y nombra al culpable** (`pw-record — PCM: pcm2c`); sin eso no sabríamos si el código se ejecuta.
- **Al acabar una grabación, pipewire tarda ~30 s en soltar el PCM**: en esa ventana el PCM sigue RUNNING sin
  cliente. Por eso, sin cliente identificado exige **dos pasadas** (5 minutos) antes de avisar.
- La pantalla se consulta a **Mutter** (`PowerSaveMode`, 0 = encendida), igual que `volver-a-dormir.sh`, con
  `bl_power` solo de respaldo.

`sh scripts/97-vigia-microfono.sh --ver` dice si está puesto, cuándo toca la próxima pasada, qué ve ahora mismo y
cuántos avisos hubo en 24 h.

## La VPN egp, a mano desde el botón del panel (2026-10-02)

Decisión del usuario: «**la nueva es mejor enfoque**». La VPN se maneja con la **unidad `openvpn-egp`**, que queda
**desactivada al arranque**, y se enciende y apaga desde el **botón «VPN egp»** de los ajustes rápidos (ranura 1 del
complemento «mandato»), el lanzador de la lista de aplicaciones, o `vpn-egp.sh subir|bajar|estado|alternar`.
El perfil `egp` de NetworkManager **se borró** (respaldo en el móvil, `/root/respaldos/`, que lleva claves: **nunca al
repo**). `sh scripts/95-vpn.sh` deja ese estado y `--ver` lo comprueba.

**Por qué se abandonó NetworkManager**, que es lo que no conviene olvidar:

| Lo que se intentó | Qué pasó |
|---|---|
| Atarla a la red como `connection.secondaries` (24-09) | se **relevantaba en cada despertar**: apagarla en phosh no duraba nada (diario del 01-10: `ip-check -> secondaries` + `vpn: starting openvpn`) |
| Quitar la atadura (01-10) | entonces el botón **nativo** de phosh ya no podía **encenderla** sobre datos móviles: *«Could not find source connection»* |
| ¿Era el Hotspot? | **no**: comprobado el 01-10 sin ningún Hotspot activo, falla igual. NetworkManager no sabe elegir la conexión base con el módem porque las rutas viven en `qmapmux0.0` y no en `qrtr0`, que es el dispositivo de su conexión |

Con systemd no hay base que elegir: openvpn usa la ruta que haya. **Comprobado el 02-10**: al encenderla sube `tun0`
con su dirección y **la ruta por defecto NO se la lleva el túnel** (sigue por el Wi-Fi), que era la queja del 24-09;
al apagarla no queda túnel y la ruta sigue intacta.

⚠️ **No bajar la VPN lanzando el mandato POR la propia VPN**: corta la sesión a mitad (me pasó el 01-10). Desde la
LAN, o desacoplado con `systemd-run`.

## Cliente de Signal (flare) (2026-10-05)

Petición del usuario: **el flare de la tienda no funciona**. El repositorio (Alpine `community/flare`, `0.20.4-r0`)
sirve una versión antigua y la app no conecta: Signal cambió la API. Solución: compilar **flare 0.22.2**, el git
actual del proyecto.

- `packages/flare/` = receta de Alpine `community/flare` (0.20.4-r0) **subida a 0.22.2** (tarball del tag
  `https://gitlab.com/schmiddi-on-mobile/flare/-/archive/0.22.2/…`), con los **dos parches de Alpine revalidados**
  sobre 0.22.2: `0001-no-cargo-home` (usa el `~/.cargo` del chroot, que llena `cargo fetch`) y
  `0002-use-cargo-auditable` (`cargo auditable build` + `--frozen`, offline). Las dependencias de 0.22.2 son las
  mismas que pedía la receta de Alpine (`gtk4`, `libadwaita`, `gtksourceview5`, `libspelling`,
  `blueprint-compiler`, `libsecret`, `openssl`, `protobuf`, `cargo-auditable`).
- `pkgrel=100`: una recompilación de Alpine (r1..r99) no la pisa; una **versión nueva** del programa (0.23…) sí
  -> `sh scripts/48-flare.sh --ver`.
- `INSTALAR=si sh scripts/48-flare.sh` compila en ia (es Rust: tarda), trae `flare` y `flare-lang` a
  `~/compilados-ia/spacewar/flare-<ver>/` con `SHA256SUMS` e instala **simulando antes**, como `43-calls.sh` y
  `44-stevia.sh`: si `apk` fuera a tocar algo más que lo nuestro, se para y enseña la lista (`ACTUALIZAR_OTROS=si`
  para seguir). `--ver` comprueba que sigue instalada la nuestra.
- ⚠️ flare guarda las credenciales con **libsecret**: hace falta el servicio de secretos (gnome-keyring) en marcha
  (en epo2 lo está). Al abrirla se vincula como dispositivo de Signal (código QR).
- ⚠️ **Tras enlazar puede salir vacía, y no es un fallo**: hay que abrir el menú principal y pulsar
  **«Sincronizar contactos»** (con el otro dispositivo encendido) y esperar. Signal **no reenvía el historial
  antiguo** a un dispositivo recién enlazado: solo llegan los contactos y los mensajes **nuevos**. Comprobado con
  `RUST_LOG=debug`: el diario muestra cómo descifra (`decrypted Whisper/PreKey message`) y crea los canales
  (`Channel with id Contact(…) changed; reloading`).
- 🔔 **Recepción en segundo plano**: flare la soporta (ajuste `run-in-background` + correr como servicio
  `flare --gapplication-service`; cerrar la ventana **oculta**, no sale). ⚠️ El portal
  `org.freedesktop.portal.Background` está **desactivado a propósito** en phosh/pmOS
  (`/usr/share/xdg-desktop-portal/phosh-portals.conf`: `org.freedesktop.impl.portal.Background=none`), así que el
  interruptor «Background Notifications» pide permiso, **falla** (`A portal frontend implementing … was not found`)
  y **no deja autostart**. Solución (hecha el 05-10): el lanzador a mano
  `~/.config/autostart/de.schmidhuberj.Flare.desktop` (`Exec=/usr/bin/flare --gapplication-service`), que systemd
  convierte en `app-de.schmidhuberj.Flare@autostart.service`. ⚠️ **No hay push**: mientras el móvil duerme no llega
  nada; al despertar, flare reconecta y **vacía la cola**.
- ✅ **Verificado (2026-10-05)**: compilado en ia en ~30 min (es Rust y va **cruzado, crossdirect + qemu-aarch64**:
  paciencia) e instalado en epo2. El guardián de deriva salió **limpio**: `apk` solo instaló `flare` y
  `flare-lang`, sin tocar nada más. Binario `aarch64` musl, `ldd` sin faltantes, `.desktop` en su sitio, y
  `sh scripts/48-flare.sh --ver` da `OK: instalada la nuestra (flare-0.22.2-r100)`. Los `.apk` quedan en
  `~/compilados-ia/spacewar/flare-0.22.2-r100/` con `SHA256SUMS`.

## ★★ La PRIMERA llamada de cada arranque no iba al casco (2026-11-10)

Síntoma que trajo el usuario: «no me conecta los cascos en las llamadas». El acta del supervisor lo dejaba
escrito, pero el fallo no era de esa llamada:

```
supervisor: acta: FALLO: perfil Bluetooth sin bajada por SLIMBus
supervisor: acta: FALLO: perfil Bluetooth sin subida por SLIMBus
supervisor: acta: FALLO: perfil Bluetooth sin enlace SCO en pie
```

- **Causa**: el WCN6750 **no está en el bus SLIMbus** (el del audio de llamada) hasta que se ha montado **una
  vez** un SCO descargado desde que el chip arrancó. Mientras no está, el kernel da `chip not enumerated` y
  `ASoC error (-19)` (ENODEV) en `wcn-bt-sco-tx/rx` y `SLIMBUS_7`; el supervisor cuenta 3 fallos y se rinde,
  dejando la llamada en el móvil.
- **Medido**: en el arranque del 09-11 19:12 → 10-11 12:19, **36 `chip not enumerated` y 0 reservas del canal
  157 en 17 h**. Ninguna llamada podía funcionar. Se abrió un SCO real a mano (`parec` del micro del casco) y
  acto seguido: `enumerated at stream startup after 0 ms: pgd laddr 0x86, ifd laddr 0x85` + `bus channel 157
  reserved`. La llamada siguiente montó el circuito en **1,2 s**.
  - ⚠️ **No basta con pedir el camino del vendor**: con `Input/Output Data Path: Vendor Specific` en btmon y el
    eSCO en pie, el chip seguía sin aparecer. Lo que lo levanta es el SCO **con datos** (un `parec`, no solo
    `bluetoothOffloadActive`).
  - ⚠️ Tampoco era la actualización del 04-11: aquella pisó el UCM (ver `62-reparacion.sh`), pero este fallo es
    de todos los arranques desde siempre.
- ⚠️ **Hacen falta TRES piezas**, comprobadas una a una: (1) casco al perfil de voz **y**
  `bluetoothOffloadActive=true` (sin el offload, `parec` no levanta nada); (2) el SCO **con datos** (grabar del
  micro); (3) **abrir el CS-Voice con la tarjeta del móvil en el perfil Bluetooth** — la enumeración la hace el
  kernel al buscar el chip en el arranque del `SLIMBUS_7`, y sin ese arranque no busca. Cambiar solo el perfil de
  la tarjeta no basta: hay que abrir el PCM (`arecord -D hw:0,3`). Con las tres: `enumerated at stream startup
  after 0 ms` a la primera.
- ✅ **Arreglo** (`device/supervisor/supervisor-llamada-bt.py`): `engrasar_chip()` corre al empezar el montaje,
  **una vez por proceso** y **solo si** el chip aún no está en el bus en este arranque
  (`Sistema.chip_en_el_bus()` mira `enumerated at stream startup` o `bus channel 157 reserved` en el diario del
  kernel de este arranque). `Sistema.calentar_sco()` hace la secuencia de las tres piezas (perfil de voz +
  offload + `parec` del `bluez_input.<MAC>`, y con el eSCO en pie abre el CS-Voice con la tarjeta en Bluetooth);
  después lo deja todo como estaba. Cuesta ~3 s **una sola vez por arranque**.
- ⚠️ **El momento importa**: se hace **al conectar el casco**, no en mitad de la llamada. Con la llamada en
  curso `q6voiced` tiene abierto el CS-Voice, el paso 3 no puede abrirlo y el chip no aparece (12:46: el SCO
  subió en 0,8 s y no enumeró). Al conectar, en cambio, está libre: `eSCO en pie en 1.3 s` y `chip en el bus tras
  el SCO de calentamiento (1.4 s)` → `enumerated at stream startup after 0 ms` + canal 159. Dos intentos como
  mucho por proceso: al conectar el casco y, si aún no está, al empezar el montaje.
- ✅ 5 pruebas nuevas en `device/supervisor/test_supervisor.py` (56 en total, todas pasan). Desplegado con
  `SOLO_SUPERVISOR=si scripts/89-cadena-llamada-bt.sh`.
- ⚠️ **Nombre de la fuente** (el fallo que costó dos arranques, 10-11): PipeWire llama a la tarjeta
  `bluez_card.B0_38_E2_23_71_AD` (guiones bajos) pero a la fuente SCO `bluez_input.B0:38:E2:23:71:AD`
  (**dos puntos**). Con el nombre mal, `parec` cae en la fuente por defecto (el micro del móvil), el SCO no se
  abre y el chip nunca aparece (`NO subio en 8.3 s`, `NO subio en 32.5 s`). Ahora lo busca con
  `Sistema.fuente_casco()`.
- ⚠️ **Se reintenta** (3 veces, 3 s de espera la primera): al conectar el casco el A2DP aún se está asentando y
  el eSCO puede no subir al primer intento.
- ✅✅ **CONFIRMADO en un arranque limpio (10-11)**: la primera llamada tras reiniciar va al casco. Secuencia real
  del móvil: `casco conectado` → `el chip BT aun no esta en el SLIMbus; lo despierto con un SCO` →
  `SCO de calentamiento: eSCO en pie en 1.3 s` → `chip en el bus tras el SCO de calentamiento (1.4 s)` →
  `enumerated at stream startup after 0 ms` + `bus channel 159 reserved`.

## El módem «se para»: ModemManager lo pierde y no lo vuelve a buscar (2026-11-13)

Síntoma: `mmcli -L` → «No modems were found», sin llamadas ni datos, **sin ningún aviso** en el diario de
ModemManager. No fue ninguna actualización (`apk` no tocaba nada desde el 11-11 15:27 y
`verificar-instalado.sh` daba 100/100): el DSP del módem seguía `running` con su firmware cargado.

- **Qué pasó** (12-11 23:48-23:49): el móvil se iba a dormir con datos; durante la espera de 15 s del gancho
  se pulsó el botón y la suspensión se **canceló** (`suspend_stats`: `fail 1`, `last_failed_errno -16`). A partir
  de ahí ModemManager perdió el puerto QMI y **no volvió a probarlo nunca**. `systemctl restart ModemManager` lo
  encontró a la primera.
- ✅ **`vigia-modem`** (`device/cuelgues/vigia-modem.{sh,service}`, lo instala `85-cuelgues.sh`): cada 60 s mira
  que el remoteproc del módem siga `running` y que `mmcli -L` lo vea. A la **segunda** comprobación seguida sin
  verlo, reinicia ModemManager (nunca con una llamada en curso) y lo anota en `journalctl -t vigia-modem`.
  Probado parando ModemManager a mano: detecta, reinicia y recupera.
- ✅ **Fallo nuestro encontrado de paso**: cuando la suspensión se **cancela**, systemd-sleep ejecuta igualmente
  `post`, y el gancho se creía despierto: escribía `/run/despertar-origen: automatico` y apagaba el panel sin que
  hubiera pasado nada. Ahora guarda `suspend_stats/success` en `pre` y, si no ha subido, anota
  «suspensión CANCELADA» y no toca pantalla ni marcador. Además, en esa misma rama mira si ModemManager se ha
  quedado sin el módem y, si es así, lo reinicia ahí mismo (es el caso que lo provocó). Comprobado forzando la
  rama con el contador de suspensiones igual: anota «suspensión CANCELADA» y el módem vuelve.

## Antes de cambiar de kernel: respaldo en la ranura B y entrada del kernel anterior (2026-11-22)

El arranque lo decide el **ABL de Qualcomm** con ranuras A/B (`androidboot.slot_suffix=_a`); no hay U-Boot
ni menú. Para poder volver atrás hay dos cosas, y las dos son baratas:

1. **Respaldo en la ranura B** (`scripts/46-instalar-kernel-ab.sh`, y a mano antes de nada): copia `boot_a`
   → `boot_b`. El ABL arranca la ranura activa y, si el kernel nuevo no llega al sistema, agota los
   reintentos y cae a la otra. Comprobado: `sha256` de `boot_a` y `boot_b` idénticos.
2. **Entrada del kernel anterior en el gestor EFI** (`scripts/47-entrada-kernel-anterior.sh`): copia
   `linux.efi`, `initramfs` y el dtb con el *release* en el nombre y escribe
   `/boot/loader/entries/pmos-anterior.conf`. La entrada normal (`pmos.conf`) sigue siendo la que reescribe
   boot-deploy, así que tras instalar el kernel nuevo el menú ofrece **el nuevo (pmos) y el anterior
   (pmos-anterior)**.

   ```sh
   sh scripts/47-entrada-kernel-anterior.sh          # deja /boot/linux-7.2.2-r135.efi + su entrada
   ```

## Rebase del kernel 7.2.2-r135 → 7.2.9-r136 (2026-11-22)

El repositorio pasó a ofrecer `linux-postmarketos-qcom-sc7280-7.2.9-r3`. Lo que había que hacer y lo que se
encontró, parche a parche:

- **7.2.9 ya ha absorbido parte de nuestro trabajo** (es el mismo árbol de la comunidad, sc7280-mainline):
  - trae **q6voice** completo (`q6voice.c`, `-common`, `-dai`, `q6cvp`, `q6cvs`, `q6mvm`) y el
    `include/dt-bindings/sound/qcom,q6voice.h`;
  - trae el **registro de topologías personalizadas** en `q6core.c` (`AVCS_CMD_REGISTER_TOPOLOGIES`);
  - trae los **servicios MVM/CVS/CVP** en `kodiak.dtsi` con las etiquetas `q6mvm`, `q6cvs`, `q6cvp`;
  - trae `s5kjn1`, el driver `dw9719` y parte del DTS de spacewar.
- Pero el q6voice de 7.2.9 es **otro**: 334 líneas frente a las 1.294 nuestras y **sin** calibración de voz del
  vendor, sin control de volumen de llamada, sin rutas de grabación/reproducción en llamada y sin los enganches
  de **SLIMBUS_7**. Por eso:

| parche | qué se hizo |
|---|---|
| **0008** | ya no "importa" la pila de surya: **sustituye** los 11 ficheros de q6voice de 7.2.9 por los nuestros |
| **0009** | **recortado**: fuera el trozo de `q6core.c` (ya upstream); se quedan SLIMBUS_7 y el routing de voz |
| **0013** | **recortado**: los servicios de voz ya están en `kodiak.dtsi`; queda solo el enlace hostless `CS-Voice` |
| resto | aplican tal cual |

- **Tropiezos del rebase** (todos por cambios de 7.2.9, todos resueltos):
  1. `qcom,q6voice.h` sin `VOICEMMODE1` → rompía el DTS del **Fairphone 5** (`qcm6490-fairphone-fp5.dts`). La
     cabecera de 7.2.9 se deja como está (tiene todos nuestros defines y uno más).
  2. Nodos `service@9/@a/@b` duplicados en el DTS → `duplicate_label` y el DTB no compilaba.
  3. `CS_VOICE` sin `#include <dt-bindings/sound/qcom,q6voice.h>` → error léxico.
  4. `CONFIG_SND_SOC_QDSP6_Q6VOICE=m` con `CONFIG_SND_SOC_QDSP6_ROUTING=y` → `undefined symbol
     q6voice_incall_record_route` al enlazar: vuelve a `=y`, como en r135.
- Config: la de 7.2.9 más nuestras 29 claves (glyph LED, SLIMBus, iio, haptics, watchdog de Gunyah, ramoops,
  detectores de cuelgue, `CONFIG_EXPERT`…). `pkgrel=136` y `LOCALVERSION=-r136`, así que cada kernel tiene su
  `/lib/modules`.
- **Respaldo antes de instalar** (no hay U-Boot: manda el ABL con ranuras A/B):
  `boot_a` → `boot_b` copiado y verificado (sha256 idéntico), más `scripts/47-entrada-kernel-anterior.sh`, que
  deja el kernel actual como entrada `pmos-anterior` en el gestor EFI.

## ★★★ AUTOENFOQUE EN LIBRACAMERA 0.8 (2026-11-22)

Funciona: `Autofocus settled at 2558 (fom 9.63) after 12 measurements`, con la lente movida de
verdad (`focus_absolute: 2558`). La escalada mide nitidez, encuentra el máximo y refina partiendo el
paso: `2047: 1.60 · 2558: 9.77 · 3069: 3.48 · 2814: 2.02 · 2941: 2.52`.

El port a 0.8 (`src/ipa/simple` → **`src/ipa/softisp`**) trajo seis tropiezos, todos con su porqué en
los parches:

1. **`0009`** — el pipeline simple tiene que **buscar la lente** en el dispositivo de medios: el kernel
   solo la enlaza al sensor como «ancillary» en algunos drivers. ⚠️ Solo se acepta si hay **una**
   lente y el sensor no tiene la suya; quedarse con «la primera» le daba a la trasera‑1 el actuador de
   la principal, con otro recorrido (habría podido llevarlo al tope).
2. **`0010`** — el algoritmo `Af` y la figura de mérito. Tres fallos encadenados, cada uno tapando al
   siguiente:
   - la nitidez se calculaba por hilo y **la fusión de estadísticas no la copiaba** (solo `sum_`,
     `numPixels_` e histograma): se tiraba, y el algoritmo veía 0 con cualquier imagen;
   - el rango del actuador se guardaba **antes** de `context_.configuration = {}`, que lo borraba;
   - la IPA recibía el mapa de controles del pipeline (sin lente) en vez del que construye el ISP.
3. **`0012`** — `/dev/udmabuf` primero: con la CMA de 16 MB la captura moría (`dma-heap allocation
   failure`) y no había ni un fotograma.
4. **`0014`** — *sensor helpers* de `s5kjn1` (lineal, código/32 por `S5KJN1_AGAIN_SHIFT = 5`) e
   `imx766` (1/640 dB por código: 0..15360 con 24 dB máx). Sin ellos el AGC dejaba la IMX766 en
   ganancia 0 y las imágenes salían negras; con ellos converge (medido: `exposure 1438 → 2828`,
   `gain 0 → 13280` en 25 fotogramas).
5. **Calibraciones**: 0.8 las busca en **`ipa/softisp`**, no en `ipa/simple` — sin eso se usaba la
   genérica (`s5kjn1.yaml not found`), con color raro y sin el `- Af:` del sensor.
6. Receta: parches en orden numérico (0012 y 0010 tocan el mismo fichero), los `.yaml` en `source=`,
   fuera `qcam.desktop` (0.8 no lo trae) y `splash-timeout` (ya upstream), y el `ln -fsrT` de meson
   que necesita el `ln` de coreutils con `argv[0]` correcto (`0013` crea el directorio antes).

✅ **Probado por el usuario en la app (2026-11-22): «ahora sí enfoca bien».**

Y un detalle de uso que costó un rato: si la app se quedó colgada de un intento fallido, **hay que
cerrarla y volver a abrirla**; con la instancia vieja viva sigue diciendo «no se puede reproducir el
flujo» aunque el portal ya esté bien.

⚠️ **Para verlo hay que tener luz**: con la escena oscura la nitidez es 0 *y es correcto*. Con un
fotograma casi negro (media 20/255) el autoenfoque no tiene nada que medir; con la linterna o luz
natural la métrica sube a 9,6 y elige posición.

## ★★★ PHOSH 0.59 CON NUESTROS DOS PARCHES (2026-11-22)

Compilado e instalado `phosh-99990.59.0-r100`. Los dos parches van dentro:

- **0002** — la pantalla no se enciende en un despertar automático (`power_save_mode_changed_cb` sigue igual en
  0.59: se corta la petición de PowerSaveMode 0 y se consume la marca de `/run/despertar-origen`).
- **0001** — el complemento «mandato» con sus cuatro ranuras: vuelven los botones de **VPN** y **Waydroid**.

✅ **Probado por el usuario el 2026-11-22: los dos botones funcionan.** Queda por ver en una noche completa que
la pantalla no se encienda en los despertares automáticos (el gasto debería volver a ~0,5 %/h).

Cosas que cambiaron al portar (y quedan en la receta):
- La lista de complementos activos ya no está en `sm.puri.phosh.plugins quick-settings` sino en
  **`mobi.phosh.shell.plugins quick-settings`** (subesquema `plugins/`, ver `migrate_gsettings()` de
  `src/shell.c`). `scripts/96-botones-mandato.sh` prueba los dos para valer en ambas versiones.
- `splash-timeout-flatpak-dbus.patch` **sobra**: ese MR ya está en 0.59 (`check_flatpak_state()` en
  `src/app-tracker.c`).
- `appstream-dev` **sobra**: la receta de pmaports ya lo lista.
- Los `.so` van a `/usr/lib/phosh/plugins/` y el esquema `mobi.phosh.plugins.mandato` a
  `/usr/share/glib-2.0/schemas`; si el botón no sale, `sudo glib-compile-schemas /usr/share/glib-2.0/schemas`
  y **cerrar sesión y volver a entrar** (el cargador de complementos solo explora el directorio al arrancar).

**El bloqueo del buildroot**, resuelto: el paquete `systemd 262.2` de `systemd-edge` trae el mismo fichero en
`sbin/` y `usr/sbin/` (y `bin/` y `usr/bin/`), y con `bin`/`sbin` enlazados a `usr/` el *commit* falla
(`failed to commit usr/sbin/init`) y `apk` sale con 2 dejando el estado tocado. `apk fix` dentro del chroot lo
deja sano y el siguiente `apk add` devuelve 0; `scripts/96-botones-mandato.sh` compila con `--lax` y reintenta
solo tras `pmbootstrap chroot -b aarch64 -- apk fix`.

## ✅ LIBRECAMERA 0.8: parches rebasados (2026-11-22)

Al principio de la sesión esto era un pendiente grande; ya está hecho y probado en el móvil. Lo que
había pasado y cómo quedó:

- **La app dejó de ver las cámaras** porque faltaba `/usr/lib/spa-0.2/libcamera/libspa-libcamera.so`
  (el `pipewire-spa-libcamera` instalado era un marcador `0-r0`): el plugin real necesita `libcamera.so.0.8`
  y aquí estaba la 0.7.2 pinneada. Se quitaron los *pins* de `/etc/apk/world` (copia en
  `/etc/apk/world.bak-20261122`) y se instaló el plugin; ahora todo esto lo hace
  `scripts/93-camaras-pipewire.sh`, que detecta el marcador y lo arregla solo.
- **Los parches de libcamera** (`packages/libcamera/`) están rebasados a 0.8 y **aplican limpios**:
  0001/0002 (softISP), 0009 (la lente y el autoenfoque en el pipeline), 0010 (autoenfoque por contraste),
  0011 (la lente solo encendida mientras se usa), 0012 (udmabuf antes que la CMA), 0013 (python: el
  directorio antes de los enlaces) y 0014 (*sensor helpers* de s5kjn1 e imx766).
- Lo que ya venía en 0.8 y por eso se quitó: límite de tamaños del softISP, CFA quad‑Bayer,
  `splash-timeout-flatpak-dbus`, preferencia por udmabuf dentro del ISP y `qcam.desktop`.
- **La app (Snapshot) ya abre y enfoca**: su flujo va por el **portal de cámara**
  (`org.freedesktop.portal.Camera`), que necesita `xdg-desktop-portal-gnome` y que
  `xdg-desktop-portal-wlr` no esté (se caía con SIGSEGV y arrastraba al portal). Las dos cosas las deja
  hechas `93-camaras-pipewire.sh`.

**Pendiente de cámara** (nada urgente):
1. **Zoom digital**: el pipeline ignora `ScalerCrop`; hay que atenderlo y recortar+escalar en el ISP.
2. `AfMode` se publica pero no aparece en la lista de controles (`LensPosition` sí, y el manual funciona).
3. Afinar la CCM de la trasera‑1 (`device/camaras/libcamera/s5kjn1.yaml`) si aún se ve verdosa.
4. **El brillo da saltos al abrir la cámara** (2026-11-22). **Causa encontrada**: el AGC de libcamera
   0.8 corre a **velocidad 1.0 durante los 10 primeros fotogramas** (`kNumStartupFrames`, «adapt instantly
   if we are in startup phase») y solo después baja a 0.2, así que el arranque da un salto grande (y a veces
   un fotograma oscuro) antes de estabilizarse. Medido con 12 fotogramas justo al abrir: gran angular
   `93 129 132 22 135 135 133 133 133 133 132 132` (estable a partir del 5º) y principal
   `106 133 137 30 188 188 190 190 126 126 128 127`. Si se quiere suavizar más: sembrar exposición/ganancia
   iniciales en la `.yaml` (para que el primer cálculo no tenga que pegar el salto) o reducir
   `kNumStartupFrames`. Ya están puestos los retardos de sensor (`0015`) y los *helpers* de ganancia (`0014`).

## El PCM de voz no tiene número fijo: se detecta (2026-11-22)

Al actualizar el kernel a 7.2.9, **`CS-Voice` pasó de `hw:0,3` a `hw:0,6`** (cambia el orden de los DAI links)
y `q6voiced` seguía abriendo el 3: la llamada no tenía sesión de voz y el audio no llegaba al casco, **sin
ningún error visible**.

- `device/llamadas/cs-voice-device.sh`: encuentra el PCM **por su nombre** (`aplay -l` → «device N: CS-Voice»),
  nunca por un número escrito. Sin argumentos imprime el número; `--esperar [s]` escribe
  `/run/q6voiced/q6voiced.conf` reintentando hasta que la tarjeta aparezca.
- `q6voiced-device.service` (Before=q6voiced.service) lo ejecuta en cada arranque.
- `q6voiced.service.d/cs-voice.conf` cambia el `EnvironmentFile` a `/run/q6voiced/q6voiced.conf`.
- `supervisor-llamada-bt.py`: fuera el `PCM_VOZ = "…/pcm3p/…"` fijo; ahora `sesion_dsp()` resuelve la ruta a
  partir del PCM detectado (`ruta_pcm("hw:0,6")` → `pcm6p`) y la vuelve a buscar si el número cambia.

Comprobado: `cs-voice-device.sh` → `6`; `/run/q6voiced/q6voiced.conf` con `q6voice_device=6`; `systemctl cat
q6voiced.service` muestra el `EnvironmentFile` de `/run`.

## ★★★ VOZ EN 7.2.9: los enlaces acabaron dentro del nodo del DSI (2026-11-22)

Tras el rebase, las llamadas no pasaban al casco. El síntoma del kernel era `CS-Voice: ASoC: no backend DAIs
enabled for CS-Voice`, y el DTS vivo lo explicaba:

```
/proc/device-tree/soc@0/display-subsystem@ae00000/dsi@ae94000/slim7-rx-dai-link
/proc/device-tree/soc@0/display-subsystem@ae00000/dsi@ae94000/slim7-tx-dai-link
```

Los parches `0019` y `0022` insertaban con contexto `@@ … platform {`, que **no es único** en el DTS, y `patch`
los colocó dentro del nodo del panel. La tarjeta se quedaba con 7 enlaces en vez de 12, sin backends de voz:
de ahí el `no backend DAIs enabled` y el silencio, aunque los mezcladores estuvieran a 1 y el DSP tuviera la
sesión de voz creada.

- Arreglo: `kernel/0060-…mover-los-enl.patch`, generado desde el árbol ya parcheado (contexto exacto), que mueve
  los cinco enlaces (`voice-rec-dl`, `voice-rec-ul`, `voice-farend`, `slim7-rx`, `slim7-tx`) dentro de `&sound`.
- Comprobado tras instalar y reiniciar: `/proc/device-tree/sound/` tiene los 12 enlaces y **0** quedan en `dsi@ae94000`.
- Al abrir `CS-Voice` ahora el camino **sí llega al chip** y falla en lo conocido y esperado:
  `wcn-bt-slim … chip not enumerated` (E-19). Eso lo resuelve el calentamiento del supervisor al conectar el casco.
- `verificar-instalado.sh` avisa si los enlaces vuelven a salir de `/sound`.

✅ **Probado por el usuario el 2026-11-22 15:00: la llamada pasa al casco y suena.**

Y al probarlo salió un SEGUNDO fallo, este del supervisor: al conectar el casco la tarjeta bluez aún no tiene
perfil de voz ni fuente SCO, así que el SCO de calentamiento no subía (`perfil de voz=None, fuente=None`) y
**el intento se daba por gastado**. La llamada llegaba con el WCN6750 fuera del SLIMbus, el primer montaje
fallaba y el calentamiento solo acertaba cuando ya se había colgado (acta de 14:57:21: 11,3 s, «CON 1
FALLO(S)»). Ahora un SCO que no sube **no cuenta** como intento y, tras ver el casco, se reintenta durante
20 s en cada vuelta del bucle (sin bloquearlo).

⚠️ Lección para los parches del DTS: anclar siempre en texto único (un `link-name`, el nombre de un nodo), nunca
en `platform {`, que aparece en cada enlace.
