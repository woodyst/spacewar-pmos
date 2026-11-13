#!/bin/sh
# vigia-modem.sh — si ModemManager pierde el módem sin que el módem se haya caído, lo recupera (2026-11-13)
#
# EL CASO DEL 2026-11-12 23:49
#   El móvil se fue a dormir con datos móviles; durante la espera de 15 s del gancho de sueño se pulsó el
#   botón y la suspensión se canceló (errno -16 en suspend_stats). A partir de ahí ModemManager dejó de ver
#   el módem: `mmcli -L` decía «No modems were found», y en su diario no había ni un aviso. El DSP del módem
#   seguía `running` con su firmware cargado y QMI sobre QRTR no volvía a probarse nunca, así que el móvil se
#   quedó sin llamadas ni datos. `systemctl restart ModemManager` lo encontró a la primera.
#
# QUÉ HACE
#   Cada CADA segundos mira dos cosas:
#     · el remoteproc del módem sigue en `running` (si no, no hay nada que recuperar: está arrancando o caído)
#     · `mmcli -L` no ve ningún módem
#   A la segunda comprobación seguida (2 min) con esa combinación, reinicia ModemManager y lo anota. No toca
#   nada si hay una llamada en curso.
#
# Por qué dos comprobaciones: al arrancar, ModemManager tarda unos segundos en crear el módem y no queremos
# reiniciarlo justo entonces.
#
# Prueba sin esperar: `sudo /usr/local/sbin/vigia-modem.sh una` fuerza una comprobación y cuenta el resultado.
set -u
CADA=${CADA:-60}
SEGUIDAS=${SEGUIDAS:-2}
MODEM_RP=${MODEM_RP:-/sys/devices/platform/soc@0/4080000.remoteproc/remoteproc/remoteproc0}
fallos=0

log() { echo "vigia-modem: $*"; logger -t vigia-modem -p user.warning "$*"; }

hay_llamada() {
	mmcli -m any --voice-list-calls 2>/dev/null | grep -q '/Call/'
}

modem_vivo() {
	[ "$(cat "$MODEM_RP/state" 2>/dev/null)" = running ]
}

mm_lo_ve() {
	! mmcli -L 2>/dev/null | grep -q '/Modem/'
}

comprobar() {
	if ! modem_vivo; then
		fallos=0
		return
	fi
	if ! mm_lo_ve; then
		if [ "$fallos" -gt 0 ]; then
			log "ModemManager vuelve a ver el módem; no hago nada"
		fi
		fallos=0
		return
	fi
	fallos=$((fallos + 1))
	if [ "$fallos" -lt "$SEGUIDAS" ]; then
		log "ModemManager no ve el módem ($fallos/$SEGUIDAS)"
		return
	fi
	if hay_llamada; then
		log "hay una llamada en curso: espero a que termine"
		return
	fi
	log "ModemManager lleva $fallos comprobaciones sin ver el módem con el DSP en marcha: lo reinicio"
	systemctl restart ModemManager 2>/dev/null
	# margen: ModemManager tarda unos segundos en crear el módem (medido: >10 s en frío)
	i=0
	while [ $i -lt 6 ] && mm_lo_ve; do
		sleep 5
		i=$((i + 1))
	done
	if mm_lo_ve; then
		log "AVISO: tras reiniciar y esperar $((i * 5)) s, ModemManager sigue sin ver el módem"
	else
		log "recuperado: ModemManager vuelve a ver el módem ($((i * 5)) s)"
	fi
	fallos=0
}

case "${1:-bucle}" in
una) comprobar ;;
bucle)
	log "vigilando el módem cada ${CADA}s (se reinicia ModemManager tras $SEGUIDAS avisos seguidos)"
	while :; do
		comprobar
		sleep "$CADA"
	done
	;;
*) echo "uso: vigia-modem.sh [bucle|una]" >&2; exit 2 ;;
esac
