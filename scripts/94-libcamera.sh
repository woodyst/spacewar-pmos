#!/bin/sh
# 94-libcamera.sh — libcamera propio con enfoque y AUTOENFOQUE (2026-09-14): compila en ia e instala.
#
#   Receta: packages/libcamera = temp/libcamera de pmaports + 0009 (enfoque manual para las apps) y 0010 (autoenfoque
#   por contraste en el IPA simple), traídos de surya (allí: «enfoca rápido y reenfoca al cambiar distancia»).
#   1. copia packages/libcamera/ al pmaports PROPIO de spacewar en ia (temp/libcamera)
#   2. pmbootstrap checksum + shutdown + build (aarch64) y trae el APKBUILD con las sumas
#   3. trae los .apk a ~/compilados-ia/spacewar/libcamera-<ver>/ con SHA256SUMS
#   4. con INSTALAR=si: instala en el móvil (libcamera, libcamera-ipa, libcamera-tools, los que usa spacewar) SOLO si
#      no hay llamada, instala las calibraciones con «- Af:» (scripts/93-camaras.sh) y reinicia wireplumber, que es
#      quien carga libcamera para las apps
#
# El algoritmo solo corre en las cámaras cuyo fichero de ajuste lista «- Af:» y que tienen lente en el DT: hoy la
# ultra gran angular (DW9800W). La principal necesita su actuador AK7377 descrito en el kernel.
#
# Uso: [INSTALAR=si] [MOVIL=phone] [SSH_OPTS=…] sh scripts/94-libcamera.sh
set -eu
HERE="$(cd "$(dirname "$0")/.." && pwd)"
IA_SSH=${IA_SSH:-ia}
BASE=/home/edi/postmarketos-spacewar
MOVIL=${MOVIL:-phone}
SSH_OPTS=${SSH_OPTS:-}
PKG=libcamera
P="$HERE/packages/$PKG"
APORT=$BASE/pmaports/temp/$PKG
# py3-libcamera (enlaces de Python, sin servicio ni consumo): para probar la cámara sin app ni PipeWire, p. ej.
# pruebas/camaras/fuga-buferes-libcamera.py. Tiene que ser de la misma versión que libcamera. (2026-09-14)
SUBPAQ="libcamera libcamera-ipa libcamera-tools py3-libcamera"

if [ "${SOLO_INSTALAR:-no}" != si ]; then
	echo ">> 0. espacio"
	ssh "$IA_SSH" "df -h ~ | tail -1 | awk '{print \"   ia: \" \$4 \" libres\"}'"

	echo ">> 1. copia a $IA_SSH:$APORT"
	ssh "$IA_SSH" "mkdir -p $APORT"
	rsync -a --delete "$P"/ "$IA_SSH:$APORT/"

	echo ">> 2. checksum y compilación"
	sh "$HERE/scripts/pmb.sh" checksum $PKG
	sh "$HERE/scripts/pmb.sh" shutdown          # checksum deja el chroot montado y el build fallaría
	# ⚠️ 2026-11-22: el buildroot aarch64 no se crea bien con el systemd 262.2 de systemd-edge (duplica
	# ficheros entre bin/ y usr/bin/ y el commit falla, apk sale con 2). `--lax` evita que pmbootstrap lo
	# zampe y `apk fix` deja el estado sano; el segundo intento compila. Ver README.
	# ⚠️ si el build falla (p. ej. el umount de qemu que deja pmbootstrap), NO se sigue: instalar
	# los .apk viejos hace creer que se probó lo nuevo (pasó el 2026-11-22 tres veces).
	if ! sh "$HERE/scripts/pmb.sh" build --lax --force --arch aarch64 $PKG; then
		echo ">> buildroot con errores de apk (systemd 262.2): apk fix y reintento"
		sh "$HERE/scripts/pmb.sh" chroot -b aarch64 -- apk fix || true
		sh "$HERE/scripts/pmb.sh" build --lax --force --arch aarch64 $PKG || {
			echo "ERROR: la compilación falló; NO se instala nada (los .apk serían viejos)"; exit 1; }
	fi
	scp -q "$IA_SSH:$APORT/APKBUILD" "$P/APKBUILD"
fi

echo ">> 3. traer los .apk"
# pkgver=9999$_pkgver → 99990.7.2
V=9999$(sed -n 's/^_pkgver=//p' "$P/APKBUILD")
R=$(sed -n 's/^pkgrel=//p' "$P/APKBUILD")
D="$HOME/compilados-ia/spacewar/$PKG-$V-r$R"; mkdir -p "$D"
for s in $SUBPAQ; do
	rsync -a "$IA_SSH:$BASE/work/packages/edge/aarch64/$s-$V-r$R.apk" "$D/"
done
( cd "$D" && sha256sum *.apk > SHA256SUMS && cat SHA256SUMS )

[ "${INSTALAR:-no}" = si ] || { echo ">> Hecho: $D  (instalar: INSTALAR=si SOLO_INSTALAR=si sh scripts/94-libcamera.sh)"; exit 0; }

echo ">> 4. instalar en $MOVIL"
ssh $SSH_OPTS "$MOVIL" 'mmcli -m any --voice-list-calls 2>&1' | grep -q "No calls" \
	|| { echo "ERROR: hay una llamada (o el módem no contesta): no instalo"; exit 1; }
ssh $SSH_OPTS "$MOVIL" 'df -h / | tail -1'
scp -q $SSH_OPTS "$D"/*.apk "$MOVIL:/tmp/"
LISTA=""; for s in $SUBPAQ; do LISTA="$LISTA /tmp/$s-$V-r$R.apk"; done
ssh $SSH_OPTS "$MOVIL" "sudo -n apk add --allow-untrusted $LISTA && rm -f $LISTA && apk list -I 2>/dev/null | grep -E '^libcamera'"
MOVIL="$MOVIL" SSH_OPTS="$SSH_OPTS" sh "$HERE/scripts/93-camaras.sh" | grep -E "yaml|>> 1b|imx766"
ssh $SSH_OPTS "$MOVIL" 'mmcli -m any --voice-list-calls 2>&1' | grep -q "No calls" \
	|| { echo "ERROR: hay una llamada: wireplumber NO se reinicia (hacerlo al colgar)"; exit 1; }
# qcam: la herramienta de libcamera con deslizadores (enfoque manual, exposición). Sale de este mismo
# paquete y es la única forma de tocar los controles desde el móvil: Snapshot no los expone.
ssh $SSH_OPTS "$MOVIL" 'sudo -n apk add qcam 2>&1 | tail -1; command -v qcam'
# ⚠️ pipewire también: el plugin spa-libcamera vive en su proceso y hay que recargarlo tras cambiar libcamera.
ssh $SSH_OPTS "$MOVIL" 'export XDG_RUNTIME_DIR=/run/user/$(id -u); systemctl --user restart wireplumber pipewire pipewire-pulse 2>/dev/null; echo "   pipewire y wireplumber reiniciados"; sleep 6; timeout 30 cam -l 2>&1 | grep -iE "tuning file|^[0-9]+:"'
echo ">> Instalado. Prueba: app Cámara, ultra gran angular, acercar y alejar algo; debería reenfocar."
