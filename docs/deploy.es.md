# Cómo se construye y se despliega

Este repo es una **capa** sobre postmarketOS y el fork de kernel de sc7280. Nada se edita en el
teléfono a mano: todo sale de aquí.

## El kernel

`kernel/` es el aport `linux-postmarketos-qcom-sc7280` completo: los 52 parches, el `APKBUILD` y la
configuración. Se copia sobre el aport de pmaports y se compila como cualquier paquete:

```sh
PMAPORTS=$(pmbootstrap config aports)
cp kernel/*.patch kernel/APKBUILD kernel/config-* \
   "$PMAPORTS/device/community/linux-postmarketos-qcom-sc7280/"
pmbootstrap checksum linux-postmarketos-qcom-sc7280
pmbootstrap shutdown     # checksum deja el chroot montado
pmbootstrap build --force linux-postmarketos-qcom-sc7280
```

⚠️ El `pkgrel` va alto a propósito: una actualización oficial del mismo `pkgver` no lo sustituye.
⚠️ Cada kernel lleva su `LOCALVERSION -rN`, así que cada uno tiene su `/lib/modules/7.2.2-rN` y se
pueden tener **dos kernels en las ranuras A/B** sin que uno pise los módulos del otro.

## Las ranuras A/B

El bootloader arranca `boot_<ranura activa>` sin menú. La rutina segura:

1. el kernel que funciona se copia a la **otra** ranura, y sus módulos se guardan aparte (el paquete
   nuevo borra los del anterior);
2. se instala el nuevo (boot-deploy escribe la ranura actual) y se deja **sin confirmar**;
3. si arranca, `qbootctl.service` la confirma; si no, el bootloader agota los reintentos y vuelve
   solo al kernel anterior.

## La configuración del dispositivo

`device/` + `scripts/install-on-device.sh <host>`:

- **UCM** de ALSA en `/usr/share/alsa/ucm2/Nothing/spacewar/`;
- **wireplumber** en `~/.config/wireplumber/wireplumber.conf.d/` y los Lua en
  `~/.local/share/wireplumber/scripts/{device,node}/` (⚠️ en otro sitio, wireplumber no arranca);
- **reglas udev**, unidades de systemd, el **tema de feedbackd** y los ayudantes de `/usr/local`.

Después, **reiniciar**, para que todo arranque en orden (SLIMBus antes que Bluetooth, el perfil de
voz antes de la primera llamada, etc.).

## Verificar sin romper nada

- **Gate de llamada**: nunca reiniciar ni tocar PipeWire con una llamada en curso.
- El **instrumento silencioso** para saber si el enrutado de audio vive: 0,2 s de silencio por
  `paplay`; si expira, el enrutador de wireplumber está roto (ver
  [`wireplumber.es.md`](wireplumber.es.md)).
- Para las medidas de energía: el `charge_counter` salta a saltos de ~1 %, así que se comparan
  **ventanas largas en %/hora**, nunca sumando mAh de ratos cortos.
- ⚠️ En la máquina de desarrollo, un bucle que sondea el teléfono por SSH **lo despierta** y
  contamina las medidas.
