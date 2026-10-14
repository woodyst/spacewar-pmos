#!/bin/sh
# 97-usb-al-reposo.sh — deja que el controlador USB3 se suspenda cuando no hay nada enchufado (2026-10-14)
#
# Instala device/energia/93-usb-al-reposo.rules (el porqué y las medidas están ahí) y lo aplica en caliente.
#
# Uso: [MOVIL=epo2lan] sh scripts/97-usb-al-reposo.sh
# Revertir: sudo rm /etc/udev/rules.d/93-usb-al-reposo.rules
#           echo on | sudo tee /sys/bus/platform/devices/a600000.usb/power/control
set -eu
HERE="$(cd "$(dirname "$0")/.." && pwd)"
MOVIL=${MOVIL:-epo2lan}
R=93-usb-al-reposo.rules

scp -q "$HERE/device/energia/$R" "$MOVIL:/tmp/$R"
ssh "$MOVIL" "sudo -n sh -c '
	set -e
	install -m644 /tmp/$R /etc/udev/rules.d/$R
	rm -f /tmp/$R
	udevadm control --reload-rules 2>/dev/null || true
	C=/sys/bus/platform/devices/a600000.usb/power/control
	echo auto > \$C
	echo \"   USB power/control: \$(cat \$C)\"
	sleep 3
	P=/sys/bus/platform/devices/a600000.usb/power
	echo \"   USB runtime: \$(cat \$P/runtime_status), suspendido \$(cat \$P/runtime_suspended_time) ms\"
'"
