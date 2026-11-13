# Wi-Fi y datos móviles

## Wi-Fi

WCN6750 con `ath11k` (firmware del WPSS). Funciona bien: 5 GHz canal 36 a 80 MHz, −45 dBm, sin
reintentos ni pérdidas de baliza.

- ✅ **País España**: `device/wifi/cfg80211-pais.conf` (`options cfg80211 ieee80211_regdom=ES`) y
  `iw reg set ES`; antes el dominio era el global «00».
- ⏳ **Calibración de radio de fábrica (pendiente)**: el `board-2.bin` de la distribución solo trae la
  variante `Qualcomm_rb3gen2` para el WCN6750 (el DT pide `Nothing_Spacewar`, así que se usan datos
  genéricos). Los datos de placa de Nothing están en la partición `modem` del propio teléfono
  (`image/qca6750/bdwlan.*`, `regdb.bin`) y se empaquetarían con `ath11k-bdencoder` como variante
  `Nothing_Spacewar` en `/lib/firmware/updates/`.
  ⚠️ Datos de fábrica: sacarlos del propio teléfono al desplegar, **nunca** a un repositorio público.
  ⚠️ Probar solo con el cable USB a mano: unos datos equivocados dejarían sin Wi-Fi, y SSH va por
  Wi-Fi.

## Datos móviles y operador

`packages/mobile-broadband-provider-info` corrige la entrada de un operador español (MCC/MNC y APN
actualizados); la base del sistema estaba desfasada.

Tras cambiar de SIM, NetworkManager puede quedarse con dos perfiles «Default» (uno con el `sim-id` de
la SIM anterior, otro con `autoconnect=no`); el script de datos deja el perfil de la SIM puesta con el
APN correcto y conexión automática, **leyendo el ICCID en el teléfono** (no se guarda en el repo).

## Módem

- `packages/modemmanager/0002`: ModemManager dejaba de usar los avisos `WDS Event Report` del módem,
  que lo despertaban cada pocos minutos sin aportar nada (su manejador solo hacía `mm_obj_dbg`).
- `packages/networkmanager/0002`: la conexión WWAN desconecta **solo su propio bearer**, sin
  arrastrar los demás (el de IMS, que hace falta para las llamadas VoLTE).
- La IP del enlace de USB es la de postmarketOS (`172.16.42.1`); el USB solo entra en modo
  dispositivo si el cable está puesto al arrancar.

## Si el módem «desaparece»: ModemManager lo pierde y no lo busca (2026-11-13)

Síntoma: `mmcli -L` dice **«No modems were found»**, sin llamadas ni datos, y en el diario de ModemManager
**no hay ningún aviso**. No es una actualización: comprueba primero versiones y ficheros
(`scripts/verificar-instalado.sh`) y el estado del DSP:

```sh
for r in /sys/devices/platform/soc@0/4080000.remoteproc/remoteproc/remoteproc*; do cat $r/state; done
```

Caso real (12-11 23:48-23:49): el móvil se iba a dormir con datos móviles; **se pulsó el botón durante la espera
de 15 s** del gancho de sueño y la suspensión se canceló (`suspend_stats`: `fail 1`, `last_failed_errno -16`).
ModemManager perdió el puerto QMI y no volvió a probarlo, con el remoteproc del módem todavía en `running` y su
firmware cargado. `systemctl restart ModemManager` lo encontró a la primera.

Desde entonces hay un **vigía** (`device/cuelgues/vigia-modem.{sh,service}`): cada 60 s comprueba que el
remoteproc siga `running` y que `mmcli -L` lo vea; a la segunda comprobación seguida sin verlo reinicia
ModemManager (nunca con una llamada en curso) y lo anota:

```sh
journalctl -t vigia-modem
```

A mano: `sudo vigia-modem.sh una` (una comprobación) o `sudo vigia-modem.sh` (bucle).

⚠️ De paso se arregló un fallo del gancho de sueño: cuando la suspensión **se cancela**, systemd-sleep ejecuta
igual la fase `post` y el gancho se creía despierto (escribía el «origen del despertar» y apagaba la pantalla sin
que hubiera pasado nada). Ahora compara `suspend_stats/success` entre `pre` y `post` y, si no ha subido, anota
`suspensión CANCELADA` y no toca nada. En esa misma rama mira además si ModemManager se ha quedado sin el módem
y, si es así, lo reinicia en el acto: es exactamente el caso que lo dejó sin módem el 12-11.
