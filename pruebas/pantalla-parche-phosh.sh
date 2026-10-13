#!/bin/sh
# pruebas/energia/pantalla-parche-phosh.sh — comprueba el parche 0002 de phosh SIN suspender (2026-10-13)
#
# QUÉ HACE, en la sesión gráfica del usuario:
#   1. apaga la pantalla (org.gnome.Mutter.DisplayConfig PowerSaveMode = 3)
#   2. escribe /run/despertar-origen = "automatico" (como hace el gancho al despertar)
#   3. pide encenderla (PowerSaveMode = 0)
#   4. mira bl_power: con el parche debe SEGUIR apagada (4); sin él, se enciende (0)
#   5. repite con el marcador "usuario": debe encenderse
#
# Uso: [MOVIL=epo2lan] sh pruebas/energia/pantalla-parche-phosh.sh
set -u
MOVIL=${MOVIL:-epo2lan}
ssh -o ConnectTimeout=8 "$MOVIL" "sudo -n sh -s" <<'FIN'
set -u
B=/sys/class/backlight/ae94000.dsi.0
UID_USER=$(loginctl list-sessions --no-legend | awk '$4=="seat0" {print $2; exit}')
[ -n "$UID_USER" ] || UID_USER=10000
ask() { # PowerSaveMode: 0 = encendida, 3 = apagada
	runuser -u edi -- env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$UID_USER/bus" \
		gdbus call --session --dest org.gnome.Mutter.DisplayConfig \
		--object-path /org/gnome/Mutter/DisplayConfig \
		--method org.freedesktop.DBus.Properties.Set org.gnome.Mutter.DisplayConfig PowerSaveMode "<int32 $1>" >/dev/null 2>&1
}
estado() { printf "bl_power=%s PSM=%s" "$(cat $B/bl_power 2>/dev/null)" \
	"$(runuser -u edi -- env DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$UID_USER/bus gdbus call --session \
		--dest org.gnome.Mutter.DisplayConfig --object-path /org/gnome/Mutter/DisplayConfig \
		--method org.freedesktop.DBus.Properties.Get org.gnome.Mutter.DisplayConfig PowerSaveMode 2>/dev/null | tr -dc 0-9)"; }

echo "phosh instalado: $(apk info -v 2>/dev/null | grep -E '^phosh-[0-9]')"
echo "phosh en marcha: PID $(pgrep -x phosh | head -1)"

echo "1) apago la pantalla            -> $(estado)"
ask 3; sleep 1
echo "   tras apagar                 -> $(estado)"

echo "2) marcador 'automatico' y petición de encender"
echo automatico > /run/despertar-origen
ask 0; sleep 1
echo "   CON marcador automatico      -> $(estado)   (esperado: bl_power=4)"

echo "3) marcador 'usuario' y petición de encender"
echo usuario > /run/despertar-origen
ask 0; sleep 1
echo "   CON marcador usuario         -> $(estado)   (esperado: bl_power=0)"

echo "4) marcador viejo (12 s) y petición de encender"
echo automatico > /run/despertar-origen
touch -d '12 seconds ago' /run/despertar-origen
ask 3; sleep 1; ask 0; sleep 1
echo "   marcador viejo               -> $(estado)   (esperado: bl_power=0, la ventana es de 10 s)"

echo "5) la marca se CONSUME: dos peticiones seguidas con marcador 'automatico'"
echo automatico > /run/despertar-origen
ask 3; sleep 1
ask 0; sleep 1
echo "   1ª petición                  -> $(estado)   (esperado: bl_power=4, se bloquea)"
ask 0; sleep 1
echo "   2ª petición (un toque)       -> $(estado)   (esperado: bl_power=0, ya no bloquea)"
echo "   contenido del marcador: $(cat /run/despertar-origen 2>/dev/null)"

ask 3
echo "listo. Diario de phosh (si G_MESSAGES_DEBUG está activado): journalctl -t phosh-monitor-manager"
FIN
