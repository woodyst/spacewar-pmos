#!/bin/sh
# cs-voice-device.sh — dice en qué PCM está «CS-Voice», sin números fijos (2026-11-22)
#
# POR QUÉ: el número de PCM de la voz depende del orden de los DAI links del kernel y CAMBIA al actualizarlo
# (el 22-11 pasó de hw:0,3 a hw:0,6 al pasar a 7.2.9). q6voiced lee /usr/share/q6voiced/q6voiced.conf con
# `q6voice_device=N`, así que un número fijo se queda obsoleto y las llamadas se quedan sin voz (y el casco sin
# audio) sin ningún error visible.
#
# QUÉ HACE
#   sin argumentos   imprime el número de dispositivo («6»); código 1 si no lo encuentra
#   --escribir       escribe /run/q6voiced/q6voiced.conf con lo que ha encontrado (lo lee q6voiced.service)
#   --esperar [seg]  como --escribir, reintentando hasta `seg` segundos (por defecto 20) si la tarjeta aún no está
#
# La detección se hace por el NOMBRE del PCM (`aplay -l`: «card 0: … device N: CS-Voice»), no por suposición.
set -u
CONF=/run/q6voiced/q6voiced.conf
SEGUNDOS=${2:-20}

detectar() {
	# aplay -l tarda un poco; con la tarjeta aún sondeándose puede no aparecer
	aplay -l 2>/dev/null | sed -n 's/^card \([0-9]*\): .*device \([0-9]*\): CS-Voice.*/\1 \2/p' | head -1
}

case "${1:-}" in
"")
	leer=$(detectar)
	[ -n "$leer" ] || exit 1
	echo "${leer#* }"
	;;
--escribir|--esperar)
	i=0
	leer=""
	while [ -z "$leer" ] && [ "$i" -lt "$SEGUNDOS" ]; do
		leer=$(detectar)
		[ -n "$leer" ] || { sleep 1; i=$((i + 1)); }
	done
	if [ -z "$leer" ]; then
		logger -t cs-voice-device -p user.err "no encuentro el PCM CS-Voice; dejo q6voiced sin configurar"
		exit 1
	fi
	card=${leer% *}; dev=${leer#* }
	mkdir -p /run/q6voiced
	printf 'q6voice_card=%s\nq6voice_device=%s\n' "$card" "$dev" > "$CONF"
	logger -t cs-voice-device -p user.info "CS-Voice está en hw:$card,$dev (detectado, no fijo)"
	cat "$CONF"
	;;
*)	echo "uso: cs-voice-device.sh [--escribir|--esperar [segundos]]" >&2; exit 2 ;;
esac
