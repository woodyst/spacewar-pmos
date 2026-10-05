#!/bin/sh
# vigia-ipa.sh — vigila que IPA (datos móviles) no se quede atascado al suspenderse (spacewar, 2026-09-14)
#
# EL CUELGUE DEL 2026-09-14
#   A las 05:20, con el móvil inactivo, el driver IPA quiso suspenderse (autosuspensión de 500 ms): pidió al módem que
#   parara un canal (ipa_runtime_suspend → ipa_modem_suspend → gsi_channel_suspend → __gsi_channel_stop) y se quedó
#   esperando para siempre una confirmación que no llegó (tarea en estado D, «blocked for more than 120 seconds» cada
#   2 min). A las 07:01 el sistema intentó suspenderse, se topó con ese IPA atascado y se congeló DENTRO de la
#   suspensión: con el perro guardián ya detenido por la suspensión, nadie reinició el móvil. Sin ningún aviso previo
#   del módem, ModemManager ni NetworkManager en el diario.
#
# QUÉ HACE
#   Cada CADA segundos busca una tarea en estado D con ipa_runtime_suspend o __gsi_channel_stop en su pila. La primera
#   vez que la ve:
#     1. lo anota en el diario y en /dev/kmsg (sobrevive en ramoops) y guarda una foto del estado en
#        /var/lib/cuelgues/ipa-<fecha>.txt: pila de la tarea, energía de IPA, remoteprocs, módem (sin números),
#        interfaces rmnet, NetworkManager y las últimas líneas del kernel
#     2. BLOQUEA la suspensión (systemd-inhibit --what=sleep) para que el móvil no se congele
#     3. avisa en pantalla: los datos móviles no volverán sin reiniciar
#   No intenta recuperar IPA ni el módem (parar remoteprocs en vivo es peligroso).
#
# PRUEBA=1: recorre el camino de aviso sin atasco real (foto, inhibidor 20 s, aviso marcado como prueba).
set -u
CADA=${CADA:-30}
DIR=${DIR:-/var/lib/cuelgues}
PRUEBA=${PRUEBA:-0}
KMSG=/dev/kmsg
USUARIO=${USUARIO:-$(id -un)}

a_kmsg() { [ -w "$KMSG" ] && printf '<%s>vigia-ipa: %s\n' "$1" "$2" > "$KMSG" 2>/dev/null; true; }
log_grave() { echo "vigia-ipa: $*"; a_kmsg 2 "$*"; }

buscar() {
	for p in /proc/[0-9]*; do
		# campo 3 de stat = estado; el nombre va entre paréntesis y puede tener espacios: quitarlo antes
		e=$(sed 's/^.*) //' "$p/stat" 2>/dev/null | cut -d" " -f1)
		[ "$e" = D ] || continue
		grep -qE "ipa_runtime_suspend|__gsi_channel_stop" "$p/stack" 2>/dev/null && { echo "${p#/proc/}"; return 0; }
	done
	return 1
}

foto() {
	pid=$1
	mkdir -p "$DIR"
	f="$DIR/ipa-$(date +%Y%m%d-%H%M%S).txt"
	d=$(ls -d /sys/bus/platform/devices/*.ipa 2>/dev/null | head -1)
	{
		echo "== $(date '+%F %T') uptime $(cut -d' ' -f1 /proc/uptime) prueba=$PRUEBA"
		echo "== tarea $pid: $(tr -d '\0' < /proc/$pid/comm 2>/dev/null)"; cat "/proc/$pid/stack" 2>/dev/null
		echo "== energía de IPA ($d)"; for x in runtime_status runtime_active_time runtime_suspended_time autosuspend_delay_ms control; do printf '%s=%s\n' "$x" "$(cat "$d/power/$x" 2>/dev/null)"; done
		echo "== remoteprocs"; for r in /sys/class/remoteproc/remoteproc*; do echo "$(cat "$r/name") $(cat "$r/state")"; done
		echo "== módem (sin números)"; mmcli -m any 2>/dev/null | grep -E "state|power state|access tech|signal quality|packet service|registration" \
			| sed -E 's/\+?[0-9]{9,}/<núm>/g'
		echo "== rmnet"; ip -s link 2>/dev/null | grep -A5 -E "rmnet|qmapmux" | sed -E 's/([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}/xx:xx:xx:xx:xx:xx/g'
		echo "== NetworkManager"; nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null
		echo "== kernel (últimas 80)"; dmesg 2>/dev/null | tail -80 | sed -E 's/([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}/xx:xx:xx:xx:xx:xx/g'
	} > "$f" 2>&1
	sync "$f" 2>/dev/null
	echo "$f"
}

avisar() {
	u=$(id -u "$USUARIO" 2>/dev/null) || return 0
	[ -S "/run/user/$u/bus" ] || return 0
	sudo -u "$USUARIO" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$u/bus" \
		notify-send -u critical -a "Vigía de datos móviles" "$1" "$2" 2>/dev/null || true
}

log_grave "vigilando IPA cada ${CADA}s (prueba=$PRUEBA)"
avisado=0
while :; do
	if [ "$PRUEBA" = 1 ]; then pid=$$; else pid=$(buscar) || pid=""; fi
	if [ -n "$pid" ] && [ $avisado -eq 0 ]; then
		avisado=1
		f=$(foto "$pid")
		log_grave "IPA ATASCADO al suspenderse (tarea $pid): foto en $f; bloqueo la suspensión"
		if [ "$PRUEBA" = 1 ]; then
			systemd-inhibit --what=sleep --who=vigia-ipa --why="prueba del vigía de IPA" --mode=block sleep 20 &
			avisar "Vigía de datos móviles (PRUEBA)" "Así avisaría si los datos móviles se atascan. No pasa nada."
			wait; log_grave "prueba terminada"; exit 0
		fi
		systemd-inhibit --what=sleep --who=vigia-ipa --why="IPA atascado: suspender congelaría el móvil" --mode=block \
			sleep infinity &
		avisar "Datos móviles atascados" "El módem no responde. No se suspenderá para no congelarse: reinicia cuando puedas."
	fi
	sleep "$CADA"
done
