#!/bin/sh
# pruebas/energia/vigia-pantalla.sh — vigía de la pantalla: anota CADA cambio de encendido (2026-10-13)
#
# POR QUÉ: para saber si el parche 0002 de phosh funciona de verdad hay que coger los cambios de
# estado, no mirar de vez en cuando. El panel se enciende y apaga en segundos; una comprobación
# cada 5 min se pierde casi todos.
#
# QUÉ HACE: lee /sys/class/backlight/*/bl_power cada 0,5 s y escribe al diario SOLO cuando cambia
# (etiqueta «vigia-pantalla»): hora, valor y —si coincide— el origen del despertar
# (/run/despertar-origen, que escribe el gancho de systemd-sleep).
#
# Se lanza como unidad transitoria (no se instala permanentemente: es una prueba).
#   sudo systemd-run --unit=vigia-pantalla --no-block /usr/local/sbin/vigia-pantalla.sh 1800
# Leer: journalctl -t vigia-pantalla
#
# Uso: vigia-pantalla.sh [SEGUNDAS]   (por defecto 600)
set -u
SEGUNDAS=${1:-600}
B=/sys/class/backlight/ae94000.dsi.0
prev=""
i=0
while [ $i -lt $((SEGUNDAS * 2)) ]; do
	i=$((i + 1))
	v=$(cat "$B/bl_power" 2>/dev/null)
	if [ "$v" != "$prev" ]; then
		origen=$(cat /run/despertar-origen 2>/dev/null)
		logger -t vigia-pantalla -p user.info "bl_power ${prev:-?} -> ${v:-?} (origen del último despertar: ${origen:-sin marca})"
		prev="$v"
	fi
	sleep 0.5
done
logger -t vigia-pantalla "vigía terminada tras $SEGUNDAS s"
