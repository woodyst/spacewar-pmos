# Suspensión, despertares y consumo

El Nothing Phone (1) no dormía: había varias fuentes que abortaban la suspensión o la despertaban
cada pocos minutos. Lo que se hizo, por orden de peso:

| Fuente | Qué pasaba | Arreglo |
|---|---|---|
| **UART del Bluetooth** | La línea de wakeup del UART del WCN6750 **abortaba cada intento de suspender** | `91-bt-uart-sin-despertar.rules` apaga `power/wakeup` del UART |
| **Avisos de batería del PMIC** | El ADSP avisa del estado de batería ~**una vez por cada 1 %** de carga y despertaba | `92-bateria-sin-despertar.rules` + servicio; el kernel `qcom_battmgr` además expone los contadores |
| **ModemManager / WDS** | ModemManager pedía ``WDS Event Report`` al módem y cada aviso lo despertaba | `packages/modemmanager/0002` deja de pedirlos |
| **VPN** | El `ping 5` del cliente OpenVPN mandaba tráfico cada 5 s y reconectaba en cada despertar | keepalive fuera (`95-vpn-sin-keepalive.sh` en el repo de trabajo) |
| **Datos móviles** | Con la red arriba, cualquier paquete (IPA, IRQ) despierta | NetworkManager corta sus bearers al dormir |
| **Sensores/pantalla** | `console_suspend=N` mataba phosh en cada suspensión; el brillo se perdía | Console suspend, `sleep-solo-deep.conf` (solo `deep`, no `s2idle`), `volver-a-dormir.sh` |

Resultado medido: de ~3 %/h se bajó a menos de 1 %/h, con el ADSP y el módem ya sin despertar. Lo que
queda son los avisos de batería del ADSP (el firmware ignora los umbrales que se le pidan) y algo de
tráfico del IMS, necesario para poder recibir llamadas VoLTE.

⚠️ **Cómo se mide**, porque es fácil engañarse: el `charge_counter` salta a saltos de ~45 mAh (1 %),
así que **nunca** hay que sumar los mAh de ratos cortos; se comparan ventanas largas en **%/hora**.
El «mA medio» de los instrumentos se queda corto. En la máquina de desarrollo el arnés mata las tareas largas en segundo
plano, así que las medidas se hacen en primer plano y con el móvil despierto.

⚠️ **El micrófono abierto no deja dormir**: una ventana de «Ajustes» de GNOME con el medidor de
sonido abierto mantenía dos flujos de captura y **abortaba la suspensión en el mismo segundo** (95
intentos/h). `vigia-microfono` avisa cuando pasa.
