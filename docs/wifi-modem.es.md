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
