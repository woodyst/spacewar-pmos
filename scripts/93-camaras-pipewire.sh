#!/bin/sh
# 93-camaras-pipewire.sh — que las cámaras lleguen a PipeWire (y a las apps) tras cualquier actualización
# (2026-11-22)
#
# EL PROBLEMA
#
# El 2026-11-22, tras actualizar 388 paquetes, `cam -l` veía las tres cámaras pero ni el portal ni las apps:
# faltaba /usr/lib/spa-0.2/libcamera/libspa-libcamera.so. El paquete `pipewire-spa-libcamera` instalado era un
# simulacro (0-r0) porque la versión de verdad (1.6.11-r0) necesita `libcamera.so.0.8` y en /etc/apk/world
# teníamos libcamera *pinneada* a la 0.7.2. Con la pin puesta, apk no podía resolver el plugin y dejaba el
# simulacro: las cámaras existían en el kernel y no en PipeWire.
#
# QUÉ HACE
#
#   1. Mira si el plugin de verdad está (fichero .so y versión distinta de 0-r0). Si está, no toca nada.
#   2. Si no: guarda /etc/apk/world, quita las pins de libcamera* (las `paquete><hash`), instala el
#      pipewire-spa-libcamera que corresponda a la versión de pipewire y reinicia wireplumber y pipewire.
#   3. Comprueba y dice cuántas cámaras ve PipeWire.
#
# Es idempotente: con todo en su sitio solo dice «ya está».
#
# Uso: [MOVIL=epo2lan] [SSH_OPTS=…] sh scripts/93-camaras-pipewire.sh
# Revertir: sudo cp /etc/apk/world.bak-<fecha> /etc/apk/world && sudo apk fix
set -eu
MOVIL=${MOVIL:-epo2lan}
SSH_OPTS=${SSH_OPTS:-}

echo ">> 1. estado en $MOVIL"
ssh $SSH_OPTS "$MOVIL" 'set -u
PLUGIN=$(apk info -v 2>/dev/null | sed -n "s/^pipewire-spa-libcamera-\(.*\)$/\1/p" | head -1)
SO=/usr/lib/spa-0.2/libcamera/libspa-libcamera.so
PW=$(apk info -v 2>/dev/null | sed -n "s/^pipewire-\([0-9].*\)$/\1/p" | head -1)
echo "   pipewire:                ${PW:-NO INSTALADO}"
echo "   pipewire-spa-libcamera:  ${PLUGIN:-NO INSTALADO}"
echo "   $SO: $([ -f $SO ] && echo sí || echo NO)"
case "${PLUGIN:-}" in
	""|0-r0) echo "   -> el plugin es un simulacro o falta: hay que arreglarlo" ;;
	*)       [ -f $SO ] && echo "   -> el plugin de verdad está: nada que hacer" ;;
esac'

echo ">> 2. arreglo (solo si hace falta)"
# ⚠️ si ya estaba, NO se reinicia nada: PipeWire y wireplumber se llevan el audio por delante (una llamada
# en curso incluida) y este script tiene que poder pasarse siempre sin consecuencias.
ARREGLO=$(ssh $SSH_OPTS "$MOVIL" 'set -eu
SO=/usr/lib/spa-0.2/libcamera/libspa-libcamera.so
PLUGIN=$(apk info -v 2>/dev/null | sed -n "s/^pipewire-spa-libcamera-\(.*\)$/\1/p" | head -1)
if [ -f $SO ] && [ -n "${PLUGIN:-}" ] && [ "$PLUGIN" != 0-r0 ]; then
	echo "   ya está"; exit 0
fi
PW=$(apk info -v 2>/dev/null | sed -n "s/^pipewire-\([0-9][^-]*-r[0-9]*\)$/\1/p" | head -1)
[ -n "$PW" ] || { echo "ERROR: no sé qué versión de pipewire hay"; exit 1; }
BAK=/etc/apk/world.bak-$(date +%Y%m%d-%H%M%S)
sudo -n cp /etc/apk/world "$BAK"
echo "   copia del world en $BAK"
# Las pins se ven como «libcamera><hash»; se dejan como «libcamera».
if grep -q "^libcamera.*><" /etc/apk/world; then
	sudo -n sed -i "s/^\(libcamera[a-z0-9-]*\)><.*$/\1/" /etc/apk/world
	# y la del plugin, si la hubiera, para poder fijar la versión buena
	sudo -n sed -i "s/^\(pipewire-spa-libcamera\)[<=>~].*$/\1/" /etc/apk/world
	echo "   pins de libcamera quitadas (el plugin necesita la versión que pide pipewire)"
fi
sudo -n apk add "pipewire-spa-libcamera=$PW" 2>&1 | tail -4
sudo -n apk fix 2>&1 | tail -2')
printf "%s\n" "$ARREGLO"

if printf "%s" "$ARREGLO" | grep -qx "   ya está"; then
	echo ">> 3. no reinicio nada (estaba bien)"
else

	echo ">> 3. reiniciar pipewire y wireplumber"
	ssh $SSH_OPTS "$MOVIL" 'export XDG_RUNTIME_DIR=/run/user/$(id -u)
	systemctl --user restart wireplumber pipewire pipewire-pulse 2>/dev/null || true
	sleep 3'
fi

echo ">> 4. comprobar"
ssh $SSH_OPTS "$MOVIL" 'set -u
export XDG_RUNTIME_DIR=/run/user/$(id -u)
SO=/usr/lib/spa-0.2/libcamera/libspa-libcamera.so
[ -f $SO ] && echo "   ✅ plugin: $SO" || { echo "   ❌ sigue sin $SO"; exit 1; }
N=$(pw-cli ls Node 2>/dev/null | grep -c "api.libcamera\|camera" || true)
echo "   nodos de cámara en PipeWire: ${N:-0}"
echo "   sensores en el kernel: $(ls /dev/video* 2>/dev/null | wc -l) /dev/video*"
[ "${N:-0}" -ge 1 ] && echo "   ✅ las cámaras llegan a PipeWire" || echo "   ⚠️ PipeWire no ve ninguna cámara (¿sesión gráfica cerrada?)"'
