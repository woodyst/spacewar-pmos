#!/bin/sh
# /usr/local/bin/vigia-microfono.sh — avisa si algo deja el MICRÓFONO ABIERTO con la pantalla apagada (2026-10-02)
#
# POR QUÉ: el 02-10 el móvil estuvo toda la mañana sin dormir. «Ajustes» de GNOME llevaba 17 h con dos flujos de
# grabación abiertos (el medidor de nivel del panel de Sonido sigue capturando con la ventana cerrada). Con el micro
# abierto el ADSP manda ~200 avisos APR por segundo y la suspensión se aborta en el mismo segundo: 95 intentos a la
# hora, cero sueño, y la pantalla encendiéndose en cada reanudación. Ver README y project_microfono_abierto_no_duerme.
#
# QUÉ HACE: cada 5 minutos (vigia-microfono.timer, de usuario). SOLO AVISA, no cierra nada: cerrar por su cuenta
# podría cortar una llamada, un mensaje de voz o una grabación. Avisa en el diario siempre, y además con una
# notificación en pantalla a la SEGUNDA vez seguida, que el diario nadie lo mira.
#
# NO avisa si: hay llamada en curso, la pantalla está encendida, o no se puede saber si hay llamada (mejor callar que
# dar un aviso falso). Leer: journalctl --user -u vigia-microfono
#
# Uso: vigia-microfono.sh            (lo llama el temporizador)
#      vigia-microfono.sh --probar   (dice lo que ve y por qué avisaría o no, sin tocar el contador ni notificar)
set -u
PROBAR=no; [ "${1:-}" = --probar ] && PROBAR=si
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
VECES=$XDG_RUNTIME_DIR/vigia-microfono.veces

decir() { [ "$PROBAR" = si ] && echo "$@" || echo "$@"; }
salir_tranquilo() { decir "sin aviso: $1"; [ "$PROBAR" = si ] || echo 0 > "$VECES" 2>/dev/null; exit 0; }

# ── 1. ¿hay llamada? Es un GATE de verdad: se cuentan los objetos de llamada, no se mira el código de salida ──
if ! LLAM=$(sudo -n mmcli -m any --voice-list-calls 2>/dev/null); then
	salir_tranquilo "no puedo preguntar al módem si hay llamada (no aviso para no dar un falso positivo)"
fi
if [ "$(printf '%s\n' "$LLAM" | grep -c '/Call/')" -gt 0 ]; then
	salir_tranquilo "hay llamada en curso: el audio abierto es normal"
fi

# ── 2. ¿pantalla encendida? Capturar con la pantalla encendida es normal (videollamada, grabadora, dictado) ──
# Se pregunta a Mutter, igual que volver-a-dormir.sh: PowerSaveMode 0 = encendida, 3 = apagada. `bl_power` queda
# como respaldo por si el bus no contesta (4 = apagada), porque de él no me fío yo solo.
PSM=$(gdbus call --session --dest org.gnome.Mutter.DisplayConfig --object-path /org/gnome/Mutter/DisplayConfig \
	--method org.freedesktop.DBus.Properties.Get org.gnome.Mutter.DisplayConfig PowerSaveMode 2>/dev/null | tr -dc '0-9')
if [ -n "$PSM" ]; then
	[ "$PSM" = 0 ] && salir_tranquilo "la pantalla está encendida (PowerSaveMode 0)"
else
	for b in /sys/class/backlight/*; do
		[ "$(cat "$b/bl_power" 2>/dev/null)" = 0 ] && salir_tranquilo "la pantalla está encendida (bl_power 0)"
	done
fi

# ── 3. ¿hay captura en marcha de verdad, en el PCM? ──
PCM=""
for s in /proc/asound/card*/pcm*c/sub*/status; do
	[ -e "$s" ] || continue
	[ "$(awk '/^state:/ {print $2}' "$s" 2>/dev/null)" = RUNNING ] || continue
	PCM="$PCM $(echo "$s" | cut -d/ -f5)"
done
[ -n "$PCM" ] || salir_tranquilo "ningún PCM de captura en marcha"

# ── 4. ¿quién lo tiene? (nombre, proceso y desde cuándo) ──
QUIEN=$(pactl list source-outputs 2>/dev/null | awk '
	/^Source Output #/ {id=$3; corked="?"; app=""; pid=""}
	/Corked:/ {corked=$2}
	/application.name = / {gsub(/"/,""); app=""; for (i=3;i<=NF;i++) app=app (i>3?" ":"") $i}
	/application.process.id = / {gsub(/[";]/,""); pid=$3}
	/^$/ {if (id!="" && corked=="no") {printf "%s (pid %s) ", (app==""?"sin nombre":app), (pid==""?"?":pid); id=""}}
	END {if (id!="" && corked=="no") printf "%s (pid %s) ", (app==""?"sin nombre":app), (pid==""?"?":pid)}')
# ⚠️ Probado el 02-10: al acabar una grabación, pipewire tarda ~30 s en soltar el PCM. En esa ventana el PCM sigue
# RUNNING pero YA NO HAY CLIENTE, y avisar ahí sería un falso positivo. Por eso, sin cliente se exige que el aviso
# se repita (dos pasadas = 5 min, mucho más que esos 30 s).
SIN_CLIENTE=no
if [ -z "$QUIEN" ]; then
	SIN_CLIENTE=si
	QUIEN="(sin cliente: ningún flujo sin pausar)"
fi

EDAD=""
for p in $(printf '%s' "$QUIEN" | grep -oE 'pid [0-9]+' | awk '{print $2}'); do
	[ -d "/proc/$p" ] && EDAD="$EDAD $(ps -o etime= -p "$p" 2>/dev/null | tr -d ' ')"
done

N=$(cat "$VECES" 2>/dev/null || echo 0); N=$((N+1))

if [ "$SIN_CLIENTE" = si ] && [ "$N" -lt 2 ]; then
	[ "$PROBAR" = si ] || echo "$N" > "$VECES" 2>/dev/null
	decir "de momento no aviso: PCM$PCM en marcha pero sin cliente; pipewire tarda ~30 s en soltarlo tras grabar"
	exit 0
fi

decir "⚠️ MICRÓFONO ABIERTO con la pantalla apagada: $QUIEN— PCM:$PCM${EDAD:+ — el proceso lleva$EDAD}"
decir "   esto impide que el móvil duerma (la suspensión se aborta en el mismo segundo). Diagnóstico completo:"
decir "   sh pruebas/energia/audio-que-no-deja-dormir.sh   ·   se arregla cerrando esa aplicación"
[ "$PROBAR" = si ] && exit 0

echo "$N" > "$VECES" 2>/dev/null
if [ "$N" -ge 2 ] && command -v notify-send >/dev/null 2>&1; then
	notify-send -u critical -i audio-input-microphone-symbolic \
		"Micrófono abierto" "$QUIEN está grabando con la pantalla apagada: el móvil no puede dormir." 2>/dev/null || true
fi
exit 0
