#!/bin/sh
# /usr/local/sbin/reparar-spacewar.sh — reinstala los ficheros nuestros que un paquete haya pisado (2026-11-04)
#
# POR QUÉ: no todos nuestros ficheros están a salvo de una actualización. apk protege lo que está en /etc
# (deja el nuevo como .apk-new), pero **/usr/share no**: ahí el paquete sobrescribe sin avisar. El 2026-11-04 una
# actualización de alsa-ucm-conf-qcom-sc7280 borró nuestra ruta «Voice Call (Bluetooth)» del UCM y el móvil dejó
# de pasar las llamadas al casco («tarjeta del movil sin perfil Bluetooth» en el supervisor).
#
# CÓMO: /usr/local/lib/spacewar/reparables.tsv tiene una línea por fichero, «copia de referencia<TAB>dónde va».
# Si el destino no es idéntico a la referencia, se reinstala y se anota en el diario. Lo llama:
#   - reparar-spacewar.service al arrancar (por si el paquete se actualizó con el móvil apagado),
#   - reparar-spacewar.path cuando alguien toca el directorio vigilado (una actualización en caliente).
# El servicio se puede lanzar a mano: sudo /usr/local/sbin/reparar-spacewar.sh
#
# ⚠️ No hace falta para los ficheros de /etc (udev, systemd, main.conf del Bluetooth): apk los protege.
set -u
L=/usr/local/lib/spacewar/reparables.tsv
[ -r "$L" ] || exit 0
tab=$(printf '\t')
tocado=

recargar_audio() {
	# PipeWire lee el UCM al crear la tarjeta: hay que reiniciar WirePlumber para que vea los perfiles nuevos.
	u=$(id -u edi 2>/dev/null) || u=1000
	if command -v runuser >/dev/null 2>&1; then
		runuser -u edi -- env XDG_RUNTIME_DIR=/run/user/$u systemctl --user restart wireplumber
	elif command -v setpriv >/dev/null 2>&1; then
		setpriv --reuid=$u --regid=$u --clear-groups env XDG_RUNTIME_DIR=/run/user/$u systemctl --user restart wireplumber
	else
		su edi -c "XDG_RUNTIME_DIR=/run/user/$u systemctl --user restart wireplumber"
	fi
}

while IFS="$tab" read -r ref dst; do
	case "${ref:-}" in ''|'#'*) continue ;; esac
	[ -r "$ref" ] || continue
	cmp -s "$ref" "$dst" 2>/dev/null && continue
	if install -Dm644 "$ref" "$dst" 2>/dev/null; then
		logger -t reparar-spacewar -p user.warning "reinstalado $dst (un paquete lo había pisado)"
		case "$dst" in
			/usr/share/alsa/ucm2/*) tocado=ucm ;;
		esac
	else
		logger -t reparar-spacewar -p user.err "NO he podido reinstalar $dst"
	fi
done < "$L"

if [ "${tocado:-}" = ucm ]; then
	if mmcli -m any --voice-list-calls 2>/dev/null | grep -q '/Call/'; then
		logger -t reparar-spacewar -p user.warning "hay una llamada en curso: el UCM nuevo se leerá al reiniciar WirePlumber"
	elif recargar_audio 2>/dev/null; then
		logger -t reparar-spacewar "WirePlumber recargado para releer el UCM"
	else
		logger -t reparar-spacewar -p user.warning "no pude recargar WirePlumber (se leerá al reiniciar la sesión)"
	fi
fi
