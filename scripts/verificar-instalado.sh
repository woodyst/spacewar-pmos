#!/bin/sh
# verificar-instalado.sh — ¿sigue instalado en el móvil exactamente lo nuestro? (2026-09-21)
#
# Para después de un `apk upgrade` (o cuando algo deja de funcionar). Solo LEE: no cambia nada en el móvil.
#
#   1. Cada fichero de device/MANIFIESTO.tsv: md5 del repo = md5 instalado. Si no, dice qué script lo reinstala.
#   2. Nuestros paquetes (packages/*, kernel/): lo instalado tiene que llevar NUESTRO -rN. Si lleva otro, una
#      actualización lo ha sustituido por el de Alpine/pmOS y el parche se ha perdido.
#   3. Casos que no son un fichero entero: la línea de device/bluetooth/offload-codecs.conf dentro de
#      /etc/bluetooth/main.conf, y el enlace conf.d/sm8250/NP1.conf de la UCM.
#   4. Aviso: qué ficheros nuestros PERTENECEN a un paquete del sistema. Esos se machacan en silencio si ese paquete
#      se actualiza (21-09: la UCM es de alsa-ucm-conf-qcom-sc7280, parte de la calibración de firmware-nothing-spacewar).
#
# Lo de /etc no suele correr peligro: apk no pisa un fichero de configuración modificado (deja el nuevo como .apk-new).
# Al añadir a device/ algo que se instale, añadirlo a device/MANIFIESTO.tsv.
#
# Uso: [MOVIL=epo2lan] sh scripts/verificar-instalado.sh        Sale con 1 si algo no cuadra.
set -eu
HERE="$(cd "$(dirname "$0")/.." && pwd)"
MOVIL=${MOVIL:-epo2lan}
SSH_OPTS=${SSH_OPTS:-}
MAN="$HERE/device/MANIFIESTO.tsv"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

ssh $SSH_OPTS "$MOVIL" true 2>/dev/null || { echo "ERROR: $MOVIL no responde por ssh"; exit 2; }

# ── 1. ficheros ──────────────────────────────────────────────────────────────────────────────────────────────────
grep -v '^#' "$MAN" | cut -f2 > "$T/rutas"
# ⚠️ md5 como root: parte de /etc no es legible por el usuario. Una ruta por línea; FALTA si no existe.
ssh $SSH_OPTS "$MOVIL" 'sudo -n sh -c '\''while IFS= read -r p; do
	if [ -e "$p" ]; then md5sum "$p"; else echo "FALTA  $p"; fi
	case "$p" in /usr/*|/lib/*) o=$(apk info -W "$p" 2>/dev/null | sed -n "s/.* is owned by //p"); [ -n "$o" ] && echo "DUENO $o $p";; esac
done
# ⚠️ 24-09: sin este «true» el bucle acaba con el codigo del ultimo `[ -n "$o" ]`; si el ultimo fichero del
# manifiesto no pertenece a ningun paquete, sale 1, y con `set -e` este script se abortaba SIN IMPRIMIR NADA.
true'\''' < "$T/rutas" > "$T/movil"

mal=0; ok=0; : > "$T/scripts"
while IFS="$(printf '\t')" read -r repo dest script; do
	case "$repo" in '#'*|'') continue;; esac
	r=$(md5sum "$HERE/$repo" | cut -d' ' -f1)
	m=$(awk -v p="$dest" '$1!="FALTA" && $1!="DUENO" && $2==p {print $1}' "$T/movil")
	if grep -qxF "FALTA  $dest" "$T/movil"; then
		echo "❌ FALTA       $dest   (repo: $repo)"; mal=$((mal+1)); echo "$script" >> "$T/scripts"
	elif [ "$r" != "$m" ]; then
		echo "❌ DISTINTO    $dest   (repo: $repo)"; mal=$((mal+1)); echo "$script" >> "$T/scripts"
	else ok=$((ok+1)); fi
done < "$MAN"
echo "== ficheros: $ok iguales, $mal con problemas (de $(grep -vc '^#' "$MAN"))"

# ── 2. paquetes ──────────────────────────────────────────────────────────────────────────────────────────────────
ssh $SSH_OPTS "$MOVIL" 'apk info -v 2>/dev/null' > "$T/apk"
pmal=0
# Qué script reinstala cada paquete propio. ⚠️ Al añadir un paquete a packages/, añadirlo aquí.
script_de() {
	case "$1" in
		callaudiod) echo "INSTALAR=si sh scripts/42-callaudiod.sh" ;;
		calls) echo "INSTALAR=si sh scripts/43-calls.sh" ;;
		flare) echo "INSTALAR=si sh scripts/48-flare.sh" ;;
		stevia) echo "INSTALAR=si sh scripts/44-stevia.sh" ;;
		hexagonrpcd) echo "sh scripts/76-cancelacion-eco.sh" ;;
		iio-sensor-proxy) echo "INSTALAR=si SOLO_INSTALAR=si sh scripts/41-iio-sensor-proxy.sh" ;;
		modemmanager) echo "sh scripts/81-modemmanager.sh" ;;
		networkmanager) echo "sh scripts/83-networkmanager.sh" ;;
		mobile-broadband-provider-info) echo "INSTALAR=si sh scripts/84-base-operadores.sh" ;;
		libcamera) echo "sh scripts/94-libcamera.sh" ;;
		phosh) echo "INSTALAR=si sh scripts/96-botones-mandato.sh" ;;
		kernel) echo "sh scripts/40-compilar-kernel.sh && sh scripts/46-instalar-kernel-ab.sh" ;;
		*) echo "(packages/$1: SIN SCRIPT en la tabla de verificar-instalado.sh)" ;;
	esac
}
for d in "$HERE"/packages/* "$HERE/kernel"; do
	[ -f "$d/APKBUILD" ] || continue
	n=$(sed -n 's/^pkgname=//p' "$d/APKBUILD" | head -1)
	f=$(sed -n 's/^_flavor=//p' "$d/APKBUILD" | head -1 | tr -d '"')
	[ -n "$f" ] && n=$(echo "$n" | sed "s/\$_flavor/$f/")
	r=$(sed -n 's/^pkgrel=//p' "$d/APKBUILD" | head -1)
	i=$(grep -E "^$n-[0-9]" "$T/apk" | grep -vE "^$n-(dev|doc|lang|libs|dbg|systemd|udev|openrc|schemas|tools|ipa)-" | head -1)
	# PENDIENTES (2026-11-22): paquetes cuyo reemplazo por el de upstream es DELIBERADO y está anotado en
	# el README (se perdió el parche a propósito). No cuentan como problema, pero sí se avisan.
	case "$n" in
		phosh|libcamera) pendiente=si ;;
		*) pendiente=no ;;
	esac
	if [ -z "$i" ]; then echo "·  $n: no instalado (ignorado)"
	elif [ "${i##*-r}" = "$r" ]; then echo "✅ $i"
	elif [ "$pendiente" = si ]; then
		echo "⏳ $i  — sustituido A PROPÓSITO (nuestro era -r$r): parche pendiente de rebasar, ver README"
	else
		echo "❌ $i  — el nuestro es -r$r: una actualización lo ha SUSTITUIDO"; pmal=$((pmal+1)); echo "@$(script_de "$(basename "$d")")" >> "$T/scripts"
	fi
done

# ── 3. casos especiales ──────────────────────────────────────────────────────────────────────────────────────────
emal=0
L=$(grep -v '^#' "$HERE/device/bluetooth/offload-codecs.conf" | grep .)
if ssh $SSH_OPTS "$MOVIL" "grep -qxF '$L' /etc/bluetooth/main.conf"; then echo "✅ main.conf: $L"
else echo "❌ /etc/bluetooth/main.conf sin «$L» (88-bluetooth-llamada.sh)"; emal=$((emal+1)); echo scripts/88-bluetooth-llamada.sh >> "$T/scripts"; fi
E=$(ssh $SSH_OPTS "$MOVIL" 'readlink /usr/share/alsa/ucm2/conf.d/sm8250/NP1.conf')
if [ "$E" = "../../Nothing/spacewar/NP1.conf" ]; then echo "✅ enlace UCM conf.d/sm8250/NP1.conf -> $E"
else echo "❌ enlace UCM conf.d/sm8250/NP1.conf -> «$E» (esperado ../../Nothing/spacewar/NP1.conf)"; emal=$((emal+1)); fi
# ⚠️ 2026-11-22: los enlaces de voz acabaron colgando del nodo del panel (DSI) porque los parches 0019/0022
# insertaban con el contexto «platform {», que no es único. La tarjeta se quedaba con 7 enlaces y ASoC decía
# «no backend DAIs enabled for CS-Voice»: las llamadas no pasaban al casco aunque todo lo demás estuviera bien.
# ⚠️ 2026-11-22: tras actualizar, `pipewire-spa-libcamera` puede quedar en el simulacro 0-r0 (si libcamera está
# pinneada) y entonces las cámaras existen en el kernel y no en PipeWire: ni portal ni apps.
PL=$(ssh $SSH_OPTS "$MOVIL" '[ -f /usr/lib/spa-0.2/libcamera/libspa-libcamera.so ] && apk info -v 2>/dev/null | sed -n "s/^pipewire-spa-libcamera-\\(.*\\)$/\\1/p" | head -1' || true)
case "${PL:-}" in
	""|0-r0) echo "❌ falta el plugin de libcamera en PipeWire (pipewire-spa-libcamera «${PL:-ninguno}»): las apps no verán cámaras (93-camaras-pipewire.sh)"; emal=$((emal+1)); echo scripts/93-camaras-pipewire.sh >> "$T/scripts" ;;
	*)       echo "✅ plugin de libcamera en PipeWire ($PL)" ;;
esac
F=$(ssh $SSH_OPTS "$MOVIL" 'ls /proc/device-tree/sound/ 2>/dev/null' | grep -c "slim7-.*-dai-link" || true)
if [ "${F:-0}" -ge 2 ]; then echo "✅ enlaces SLIMBUS_7 dentro de /sound ($F)"
else echo "❌ los enlaces SLIMBUS_7 no están bajo /sound (hay ${F:-0}): la voz no tendrá backend (kernel, parche 0060)"; emal=$((emal+1)); fi

# ── 4. riesgo: ficheros nuestros que son de un paquete ───────────────────────────────────────────────────────────
if grep -q '^DUENO ' "$T/movil"; then
	echo "== ⚠️ ficheros nuestros que PERTENECEN a un paquete (se machacan si ese paquete se actualiza):"
	awk '$1=="DUENO"{c[$2]++} END{for(k in c) printf "   %-40s %d fichero(s)\n", k, c[k]}' "$T/movil" | sort
fi

total=$((mal+pmal+emal))
if [ "$total" -eq 0 ]; then echo "== ✅ TODO EN SU SITIO"; exit 0; fi
echo "== ❌ $total problema(s). Para reinstalar:"
sort -u "$T/scripts" | sed -e '/^@/!s/^/   sh /' -e 's/^@/   /'
exit 1
