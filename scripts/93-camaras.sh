#!/bin/sh
# 93-camaras.sh — herramientas de cámara en spacewar y comprobación de los sensores (2026-09-14)
#
# Instala de la distribución v4l-utils (media-ctl, v4l2-ctl), libcamera-tools (cam) y gstreamer-tools (gst-launch-1.0,
# para probar la cámara por PipeWire sin app: pruebas/camaras/fuga-buferes.sh). Comprueba con el kernel r127 o
# posterior (parche 0044: S5KJN1 a 700 MHz): los sensores ligados a su driver, el grafo de camss y lo que ve
# libcamera. Cámaras: trasera ultra gran angular S5KJN1 (cci1 0x2d, csiphy2, motor de enfoque DW9800W en 0x0c) y
# frontal IMX471 (cci0 0x1a, csiphy0). Desde el r128 (0045-0046) también la principal IMX766 (C-PHY, cci1 bus 1 0x10,
# csiphy3), con el driver WIP de Danila Tikhonov. Hasta el 2026-09-14 iba en lista negra; ahora la quita si la
# encuentra y la IMX766 se carga sola al arrancar. ⚠️ Sin ella camss no completa el grafo y no se ve ninguna cámara.
#
# Uso: [MOVIL=epo2lan] [SSH_OPTS=…] sh scripts/93-camaras.sh
set -eu
MOVIL=${MOVIL:-epo2lan}
SSH_OPTS=${SSH_OPTS:-}
HERE="$(cd "$(dirname "$0")/.." && pwd)"

# calibraciones propias de libcamera (simple/softISP): /etc/libcamera/ipa se busca antes que /usr/share/libcamera/ipa
scp -q $SSH_OPTS "$HERE"/device/camaras/libcamera/*.yaml "$MOVIL:/tmp/"
YAMLS=$(cd "$HERE/device/camaras/libcamera" && ls *.yaml | sed 's|^|/tmp/|' | tr '\n' ' ')
# ⚠️ 2026-11-22: 0.8 renombró la carpeta del IPA de «simple» a «softisp». Se instala en las dos
# para que valga con las dos versiones (libcamera busca /etc/libcamera/ipa/<nombre del IPA>).
ssh $SSH_OPTS "$MOVIL" "for d in softisp simple; do sudo -n mkdir -p /etc/libcamera/ipa/\$d && for f in $YAMLS; do sudo -n install -m644 \"\$f\" /etc/libcamera/ipa/\$d/ && echo \"   /etc/libcamera/ipa/\$d/\${f##*/}\"; done; done; rm -f $YAMLS"
ssh $SSH_OPTS "$MOVIL" 'set -u
echo ">> 1. paquetes"
faltan=""
for p in v4l-utils libcamera-tools gstreamer-tools; do apk info -e $p >/dev/null 2>&1 || faltan="$faltan $p"; done
if [ -n "$faltan" ]; then df -h / | tail -1; sudo -n apk add $faltan | tail -1; else echo "   ya instalados"; fi
echo ">> 1b. imx766 sin lista negra (desde 2026-09-14 se carga sola al arrancar, como los otros sensores)"
if [ -e /etc/modprobe.d/imx766.conf ]; then sudo -n rm -f /etc/modprobe.d/imx766.conf && echo "   quitada /etc/modprobe.d/imx766.conf"; else echo "   no había lista negra"; fi
lsmod | grep -q "^imx766" || { sudo -n modprobe imx766 && echo "   imx766 cargado ahora"; }
echo ">> 2. sensores (kernel $(uname -r))"
for d in 18-002d 16-001a 18-000c; do
	printf "   %s %s: %s\n" "$d" "$(cat /sys/bus/i2c/devices/$d/name 2>/dev/null)" "$(basename "$(readlink /sys/bus/i2c/devices/$d/driver 2>/dev/null)" 2>/dev/null || echo "SIN DRIVER")"
done
dmesg 2>/dev/null | grep -E "s5kjn1.*(failed|no matching)" | tail -1 | sed "s/^/   ⚠️ /"
echo ">> 3. grafo de camss"
media-ctl -d /dev/media0 -p 2>/dev/null | grep -A10 -E "^- entity .*(s5kjn1|imx471|dw9719)" | grep -E "^- entity|\->|subtype" | sed "s/^/   /"
echo ">> 4. libcamera"
timeout 30 cam -l 2>/dev/null | sed "s/^/   /"'
