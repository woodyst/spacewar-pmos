#!/bin/sh
# consumo-reposo-muestra.sh — una muestra del estado de la batería y de la suspensión (spacewar, 2026-09-13)
#
# La lanza un temporizador de systemd SIN WakeSystem: solo corre cuando el móvil ya está despierto, así que no
# perturba el reposo que se quiere medir (un bucle por SSH lo despertaría). Añade una línea a
# /var/lib/consumo-reposo/muestras.csv:
#   epoch;uptime_s;capacidad_%;tension_uV;corriente_uA;estado;temp_dC;usb_online;susp_ok;susp_fallo;hw_sleep_total_us
# La carga la gestiona el firmware del DSP (pmic_glink, qcom-battmgr): no expone current_avg ni charge_now, por eso
# el consumo se estima con la caída del porcentaje en el tiempo.
set -u
D=/var/lib/consumo-reposo
B=/sys/class/power_supply/qcom-battmgr-bat
U=/sys/class/power_supply/qcom-battmgr-usb
S=/sys/power/suspend_stats
mkdir -p "$D"
leer() { cat "$1" 2>/dev/null || echo ""; }
[ -s "$D/muestras.csv" ] || echo "epoch;uptime_s;capacidad;tension_uV;corriente_uA;estado;temp_dC;usb_online;susp_ok;susp_fallo;hw_sleep_total_us;contador_uAh;carga_llena_uAh;potencia_uW;tiempo_vacio_s" > "$D/muestras.csv"
E=$(date +%s)
# Columnas 12-15 (desde 2026-09-13): el contador de carga del medidor (charge_counter, µAh que quedan) y compañía.
# Restando el contador entre dos muestras sale la carga gastada de verdad, dormido incluido: medir desde el chip,
# como en surya con current_avg. ⚠️ En surya el medidor informaba ~2,5× menos que un medidor USB externo: contrastar.
echo "$E;$(cut -d. -f1 /proc/uptime);$(leer $B/capacity);$(leer $B/voltage_now);$(leer $B/current_now);$(leer $B/status);$(leer $B/temp);$(leer $U/online);$(leer $S/success);$(leer $S/fail);$(leer $S/total_hw_sleep);$(leer $B/charge_counter);$(leer $B/charge_full);$(leer $B/power_now);$(leer $B/time_to_empty_avg)" >> "$D/muestras.csv"
# Fuentes de despertar con eventos (acumulados desde el arranque): la diferencia entre la primera y la última muestra
# dice qué ha despertado al móvil durante la medida. Con el cable puesto mandan qcom-battmgr y ucsi.
for w in /sys/class/wakeup/wakeup*; do
	n=$(leer "$w/event_count"); [ "${n:-0}" != 0 ] && echo "$E;$n;$(leer "$w/name")"
done >> "$D/despertares.log"
