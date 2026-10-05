#!/bin/sh
# /usr/local/sbin/volver-a-dormir.sh — spacewar (2026-09-14)
#
# POR QUÉ: tras un despertar AUTOMÁTICO (sin que el usuario toque nada: un aviso del ADSP, de la batería…) gsd-power no
# vuelve a contar la inactividad y el móvil se queda despierto con la pantalla apagada hasta que alguien lo usa. Medido
# el 2026-09-14: 35 y 81 min despierto seguidos, batería del 53 al 29 % en 2 h 40 min con solo 3 suspensiones.
#
# QUÉ HACE: lo lanza el gancho 50-despertar-y-sensores 15 s después de cada despertar (systemd-run, unidad
# volver-a-dormir; eran 300 s hasta el 2026-09-14 22:45 y 60 s hasta el 2026-09-15 19:00). Vuelve a suspender SOLO si
# se cumple todo:
#   - con batería (con cargador gsd-power tampoco suspende)
#   - sin llamada en curso
#   - NADIE lo ha tocado desde que despertó: no han subido las interrupciones del táctil (fts_ts) ni de los botones
#     (pmic_pwrkey, pmic_resin, Volume up) respecto a lo que guardó el gancho al despertar (/run/volver-a-dormir.entrada).
#     ⚠️ La pantalla NO sirve de señal (probado 2026-09-14 23:07): phosh la enciende sola al despertar y la apaga a los
#     300 s de inactividad; a los 15 s siempre está encendida. Se anota solo como dato.
#   - hay una sesión gráfica activa
#   - ninguna aplicación inhibe la suspensión ni la inactividad (org.gnome.SessionManager.IsInhibited 4|8: vídeo,
#     música…)
# Si no puede leer algo, NO suspende. Suspende con `systemctl suspend` sin -i: los bloqueos de logind se respetan.
#
# MODO --apagar-pantalla (2026-09-15): el gancho lo lanza 3 s después de un despertar que NO vino del botón de
# encendido ni del volumen. Al despertar se encendía la pantalla cada vez (el usuario lo veía de noche y gasta): la
# pone en ahorro (PowerSaveMode 3) si no hay llamada y nadie ha tocado el móvil. Si el usuario pulsa el botón, phosh la
# enciende como siempre.
#
# Cada decisión queda en el diario: journalctl -t volver-a-dormir
set -u
MODO=${1:-dormir}
motivo() { logger -t volver-a-dormir -p user.info "$*"; }

if [ "$MODO" = dormir ]; then
	[ "$(cat /sys/class/power_supply/qcom-battmgr-usb/online 2>/dev/null)" = 0 ] || { motivo "no: con cargador"; exit 0; }
fi
mmcli -m any --voice-list-calls 2>&1 | grep -q "No calls" || { motivo "no ($MODO): llamada en curso (o el módem no contesta)"; exit 0; }

# sesión gráfica activa (phosh): id, uid y usuario
ses=""
for id in $(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}'); do
	if [ "$(loginctl show-session "$id" -p Type --value 2>/dev/null)" = wayland ] \
		&& [ "$(loginctl show-session "$id" -p Active --value 2>/dev/null)" = yes ] \
		&& [ "$(loginctl show-session "$id" -p Class --value 2>/dev/null)" = user ]; then
		ses=$id; break
	fi
done
[ -n "$ses" ] || { motivo "no ($MODO): no hay sesión gráfica de usuario activa"; exit 0; }
uid=$(loginctl show-session "$ses" -p User --value)
usuario=$(loginctl show-session "$ses" -p Name --value)

dbus_usuario() {
	# gdbus en el bus de sesión del usuario (como él: el bus rechaza a root)
	if command -v runuser >/dev/null 2>&1; then
		runuser -u "$usuario" -- env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" gdbus call --session "$@"
	else
		sudo -n -u "$usuario" env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" gdbus call --session "$@"
	fi
}

entrada0=$(cat /run/volver-a-dormir.entrada 2>/dev/null)
entrada=$(awk '/fts_ts|pmic_pwrkey|pmic_resin|Volume up/ { n = 0; for (i = 2; i <= NF; i++) if ($i ~ /^[0-9]+$/) n += $i; else break
	t += n } END { print t + 0 }' /proc/interrupts)
case "$entrada0" in
	''|*[!0-9]*) motivo "no ($MODO): no sé si lo han tocado (falta /run/volver-a-dormir.entrada)"; exit 0 ;;
esac
[ "$entrada" -eq "$entrada0" ] || { motivo "no ($MODO): lo han tocado desde que despertó (táctil/botones +$((entrada - entrada0)))"; exit 0; }
pantalla=$(dbus_usuario --dest org.gnome.Mutter.DisplayConfig --object-path /org/gnome/Mutter/DisplayConfig \
	--method org.freedesktop.DBus.Properties.Get org.gnome.Mutter.DisplayConfig PowerSaveMode 2>/dev/null | tr -dc '0-9')

if [ "$MODO" = --apagar-pantalla ]; then
	if [ "$pantalla" = 3 ]; then
		motivo "pantalla: ya estaba apagada tras el despertar automático"
	elif dbus_usuario --dest org.gnome.Mutter.DisplayConfig --object-path /org/gnome/Mutter/DisplayConfig \
		--method org.freedesktop.DBus.Properties.Set org.gnome.Mutter.DisplayConfig PowerSaveMode '<int32 3>' >/dev/null 2>&1; then
		motivo "pantalla: apagada tras el despertar automático (estaba en PowerSaveMode ${pantalla:-?})"
	else
		motivo "pantalla: no pude apagarla (PowerSaveMode ${pantalla:-?})"
	fi
	exit 0
fi

inhibido=$(dbus_usuario --dest org.gnome.SessionManager --object-path /org/gnome/SessionManager \
	--method org.gnome.SessionManager.IsInhibited 12 2>/dev/null)
case "$inhibido" in
	*false*) ;;
	*true*) motivo "no: una aplicación inhibe la suspensión o la inactividad"; exit 0 ;;
	*) motivo "no: no sé si hay aplicaciones inhibiendo"; exit 0 ;;
esac

motivo "sí: batería, sin llamada, nadie lo ha tocado (PowerSaveMode ${pantalla:-?}) y sin inhibidores: vuelvo a suspender"
systemctl suspend || motivo "systemctl suspend falló (¿bloqueo de logind?)"
exit 0
