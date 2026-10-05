# Estabilidad: cuelgues, perro guardián y disco

Hubo varios cuelgues y cada uno dejó una lección. La instrumentación (ramoops + detectores + perro
guardián) y las mitigaciones están en `device/cuelgues/`.

## Instrumentación

| Pieza | Qué hace |
|---|---|
| **ramoops** | consola y pmsg del kernel en memoria reservada; tras reiniciar, `systemd-pstore` lo archiva en `/var/lib/systemd/pstore/` |
| **Detectores** | bloqueo blando y duro (variante *buddy*: este SoC no tiene NMI) con pánico; tareas colgadas > 120 s **con traza y sin pánico** (en el POCO el pánico por tarea colgada hacía bucles de reinicio) |
| **perro guardián** | `/dev/watchdog` es el de **Gunyah** (margen 32 s). El firmware anuncia SMCCC v1.0 y `qcom_scm` no lo registraba: `0032`. `perro-vivo` solo lo acaricia si el teléfono **crea procesos y escribe en disco con fsync** — una prueba de vida de verdad, no «PID 1 vive» |
| **Diario** | persistente, 2 G, volcado cada 30 s |

Tras un cuelgue: `ls /var/lib/systemd/pstore/`, `journalctl -b -1`, `journalctl -u perro-vivo`. Y
⚠️ **esperar ~2 min antes de forzar el apagado** (pánico del detector + 10 s, o mordisco del perro).

## Los tres cuelgues que se entendieron

1. **La GPU (no el audio).** La GMU deja de responder, falla el anillo, salta la interrupción global
   del SMMU en bucle y el `recover_worker` espera a la GMU sin plazo con el cerrojo cogido: bloqueo
   mutuo y pantalla congelada. El sistema seguía vivo por SSH, así que **ni el perro ni los detectores
   reiniciaron**: miran procesos y disco, no el compositor. Decisión: dejarlo como está y conservar la
   traza.
2. **El disco (UFS).** Tras volver a la sesión, tormenta de E/S y el diario deja de escribir con el
   kernel vivo: el **abrazo mortal del UFS** (visto entero en el POCO): `ufshcd_devfreq_scale` quiere
   `clk_scaling_lock`, que el manejador de eventos tiene como lector esperando al chip. Mitigación:
   `99-ufs-sin-escalado.rules` apaga el escalado de reloj de la UFS.
3. **La IPA en suspensión.** Con datos, IPA se autosuspende y pide al módem parar un canal; la
   confirmación no llega, una tarea queda en D y el sistema se congela dentro de la suspensión.
   `vigia-ipa` lo detecta, **bloquea la suspensión** y avisa en pantalla para reiniciar, en vez de
   dejar el teléfono congelado.

## La trampa grande: `console_suspend=N` mata phosh

`console_suspend=N` (puesto para que ramoops viera la suspensión) **fuerza el cambio de consola
virtual al suspender**; logind ve la sesión inactiva, retira el DRM a phoc, phoc rehace la salida y
**phosh pierde la conexión y muere** → pantalla de entrada. Correlación exacta con cada suspensión con
sesión abierta.

**Arreglo**: `console_suspend=Y` (se retiró el fichero de tmpfiles). Para un dispositivo que no
termine de suspenderse queda `DPM_WATCHDOG`, que provoca un pánico con su pila en vez de un teléfono
congelado. ⚠️ **No usar `no_console_suspend` ni `console_suspend=N` con sesión gráfica.**
