#!/bin/sh
# 62-reparacion.sh — que una actualización no vuelva a dejarnos sin llamadas por el casco (2026-11-04)
#
# Instala la autorreparación de los ficheros nuestros que viven en /usr/share y que, por tanto, apk NO protege:
#   /usr/local/sbin/reparar-spacewar.sh        (el que repara; explica el porqué)
#   /etc/systemd/system/reparar-spacewar.service  (al arrancar)
#   /etc/systemd/system/reparar-spacewar.path     (cuando un paquete toca el directorio)
#   /usr/local/lib/spacewar/ref/*                 (copias de referencia)
#   /usr/local/lib/spacewar/reparables.tsv        (qué copiar y dónde)
#
# Contexto: el 2026-11-04, tras actualizar, el paquete alsa-ucm-conf-qcom-sc7280 sobrescribió
# /usr/share/alsa/ucm2/Nothing/spacewar/{HiFi,NP1}.conf y se perdió la ruta «Voice Call (Bluetooth)»: las
# llamadas dejaron de ir al casco («tarjeta del movil sin perfil Bluetooth»). Los ficheros de /etc no corren
# ese riesgo: apk los deja como .apk-new y no los pisa.
#
# Uso: [MOVIL=epo2lan] sh scripts/62-reparacion.sh
# Revertir: sudo systemctl disable --now reparar-spacewar.path reparar-spacewar.service
#           sudo rm /etc/systemd/system/reparar-spacewar.{path,service} \
#                   /usr/local/sbin/reparar-spacewar.sh /usr/local/lib/spacewar/reparables.tsv
set -eu
HERE="$(cd "$(dirname "$0")/.." && pwd)"
MOVIL=${MOVIL:-epo2lan}
S=reparar-spacewar.sh
U=reparar-spacewar.service
P=reparar-spacewar.path
UCM="$HERE"/device/ucm/Nothing/spacewar

sh -n "$HERE/device/reparacion/$S"
scp -q "$HERE/device/reparacion/$S" "$HERE/device/reparacion/$U" "$HERE/device/reparacion/$P" \
	"$UCM/HiFi.conf" "$UCM/NP1.conf" "$UCM/VoiceCall.conf" "$MOVIL:/tmp/"
ssh "$MOVIL" "sudo -n sh -s" <<'FIN'
set -e
UCM=/usr/share/alsa/ucm2/Nothing/spacewar
install -m755 /tmp/reparar-spacewar.sh /usr/local/sbin/reparar-spacewar.sh
install -m644 /tmp/reparar-spacewar.service /etc/systemd/system/reparar-spacewar.service
install -m644 /tmp/reparar-spacewar.path /etc/systemd/system/reparar-spacewar.path
mkdir -p /usr/local/lib/spacewar/ref
: > /usr/local/lib/spacewar/reparables.tsv
for f in HiFi.conf NP1.conf VoiceCall.conf; do
	install -m644 "/tmp/$f" "/usr/local/lib/spacewar/ref/$f"
	printf '%s\t%s\n' "/usr/local/lib/spacewar/ref/$f" "$UCM/$f" >> /usr/local/lib/spacewar/reparables.tsv
done
rm -f /tmp/reparar-spacewar.sh /tmp/reparar-spacewar.service /tmp/reparar-spacewar.path \
      /tmp/HiFi.conf /tmp/NP1.conf /tmp/VoiceCall.conf
systemctl daemon-reload
systemctl enable -q reparar-spacewar.service reparar-spacewar.path
systemctl restart reparar-spacewar.path
/usr/local/sbin/reparar-spacewar.sh
echo "   reparables:"; sed 's/^/     /' /usr/local/lib/spacewar/reparables.tsv
echo "   servicio=$(systemctl is-enabled reparar-spacewar.service)  vigilante=$(systemctl is-active reparar-spacewar.path)"
FIN
