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

## La pantalla no debe encenderse en un despertar automático

El móvil se despierta solo a menudo (el firmware lo saca de la suspensión; ver abajo por qué no se
puede evitar desde Linux). Cada despertar automático **iluminaba la pantalla**, algo que se ve de
noche y cuesta batería.

**Quién la enciende, medido**: con `rtcwake -m mem -s 20` y la pantalla ya apagada, `bl_power`
sigue en 4 al reanudar. `rtcwake` escribe `/sys/power/state` y se salta logind, así que ni
`PrepareForSleep` ni los ganchos de `system-sleep` corren: **el kernel no reenciende el panel**. Lo
enciende el espacio de usuario por la señal `PrepareForSleep(resume)` de logind. Emitir
`org.gnome.ScreenSaver.WakeUpScreen` a mano no la enciende: phosh solo emite esa señal; lo que
manda es la propiedad `org.gnome.Mutter.DisplayConfig PowerSaveMode`, implementada por phosh en
`src/monitor-manager.c` (`power_save_mode_changed_cb` → `zwlr_output_power_v1_set_mode`).

**El parche** (`packages/phosh/0002-despertar-automatico-no-enciende-la-pantalla.patch`): el gancho
de systemd-sleep escribe `/run/despertar-origen` al reanudar — `usuario` si lo provocó un botón
(IRQ 116/117/165) o el táctil (170), `automatico` si no—. phosh convierte la **primera** petición
de encender la pantalla tras ese despertar en mantenerla apagada, y consume la marca: la siguiente
petición (un toque o el botón) ya enciende. Sin el fichero, comportamiento de upstream.

Detalle que costó un rato: con una simple ventana de 10 s el usuario pulsaba el botón varias veces
sin que encendiera. Por eso la marca se **consume** en lugar de caducar.

Comprobado (phosh 99990.57.0-r102, muestreo de `bl_power` cada 50 ms):

| despertar | `bl_power` al reanudar | resultado |
|---|---|---|
| automático (alarma RTC, `pm_wakeup_irq=115`) | 4 | sigue apagada; `PowerSaveMode` llega a leer 0 pero el panel nunca se ilumina |
| botón (`116`) | 4 → 0 | se enciende |
| automático con la pantalla encendida al dormir | 0 → 4 | el kernel sí reactiva el CRTC; el gancho la apaga a los ~60 ms |

Para cazar cualquier encendido posterior: `pruebas/energia/vigia-pantalla.sh` (lee `bl_power` cada
0,5 s y solo anota cambios; `journalctl -t vigia-pantalla`).
