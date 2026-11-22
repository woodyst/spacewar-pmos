#!/bin/sh
# 96-botones-mandato.sh — BOTONES PROPIOS en los ajustes rápidos de phosh (2026-10-01).
#
# Los botones del panel de phosh no son configurables: son COMPLEMENTOS COMPILADOS (.so en /usr/lib/phosh/plugins,
# con su .plugin para que «Ajustes móviles» los liste), y los activos se eligen en la clave de ajustes
# `quick-settings` (en 0.59 vive en «mobi.phosh.shell»; antes, en «sm.puri.phosh.plugins»). El «simple-custom-quick-setting» que trae phosh es solo una demostración:
# cambia su icono y no ejecuta nada. Y no hay forma de compilar un complemento por fuera, porque phosh no instala
# cabeceras ni pkg-config. De ahí este camino: phosh propio con UN complemento genérico.
#
# packages/phosh/0001-* añade el complemento «mandato»: CUATRO RANURAS iguales (mandato1..mandato4) que leen de los
# ajustes qué hacer. Por eso phosh se compila UNA VEZ y añadir o cambiar un botón es solo gsettings, sin recompilar:
#   titulo · icono · icono-apagado · encender · apagar · estado · intervalo · espera
# El mandato de «estado» manda: salida 0 = encendido, su primera línea se dibuja bajo el icono y el resto va a la
# página de detalle (pulsación larga). Mientras corre un mandato el botón queda insensible con «encendiendo…».
# Documentación y cómo añadir más: docs/BOTONES-AJUSTES-RAPIDOS.md
#
# Este script deja configuradas dos ranuras:
#   1) VPN egp  — por systemctl (openvpn-egp), no por NetworkManager: es como la usa el usuario (decisión suya,
#      01-10). La unidad sigue DESACTIVADA al arranque: el botón solo la arranca y la para a mano.
#   2) Waydroid — waydroid session start/stop; el start va con systemd-run --user para que NO sea hijo de phosh.
#
# ⚠️ Un complemento nuevo solo se carga al arrancar phosh (el cargador explora el directorio una vez), así que
# después de instalar hay que CERRAR SESIÓN y volver a entrar. Cambiar los mandatos de una ranura, no: es en vivo.
# ⚠️ pmaports YA TRAE phosh (extra-repos/systemd/phosh) y pmbootstrap hace caso a ESA receta, no a la nuestra de
# temp/: el paso 2 la aparta mientras compilamos y la devuelve al terminar, pase lo que pase.
#
# Uso: [INSTALAR=si] [MOVIL=epo2lan] sh scripts/96-botones-mandato.sh   |   sh scripts/96-botones-mandato.sh --ver
#      SOLO_CONFIG=si sh scripts/96-botones-mandato.sh      (no compila: solo reconfigura las ranuras)
#      INSTALAR=si SOLO_INSTALAR=si sh scripts/96-botones-mandato.sh   (no compila: instala los .apk ya compilados)
set -eu
HERE="$(cd "$(dirname "$0")/.." && pwd)"
IA_SSH=${IA_SSH:-ia}
BASE=/home/edi/postmarketos-spacewar
MOVIL=${MOVIL:-epo2lan}
SSH_OPTS=${SSH_OPTS:-}
PKG=phosh
P="$HERE/packages/$PKG"
APORT=$BASE/pmaports/temp/$PKG
DE_PMAPORTS=$BASE/pmaports/extra-repos/systemd/$PKG
# ⚠️ se aparca FUERA de pmaports: pmbootstrap exige que la carpeta se llame igual que el paquete, y una
# carpeta «phosh-aparcada» con pkgname=phosh dentro le hace rechazar el árbol entero (probado el 01-10).
APARCADA=$BASE/phosh-de-pmaports-aparcada
V="9999$(sed -n 's/^_pkgver=//p' "$P/APKBUILD")"
R=$(sed -n 's/^pkgrel=//p' "$P/APKBUILD")
SUB="phosh libphosh phosh-lang phosh-portalsconf phosh-schemas phosh-systemd"
RANURAS="mandato1-quick-setting mandato2-quick-setting"

# Cada ranura: NUMERO|titulo|icono|icono-apagado|encender|apagar|estado  (el estado, con \n escapados, va aparte)
config_ranuras() {
	ssh $SSH_OPTS "$MOVIL" 'export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
E="mobi.phosh.plugins.mandato:/mobi/phosh/plugins/mandato"

# --- ranura 1: VPN egp por systemctl ---------------------------------------------------------------------------
gsettings set $E/1/ titulo "VPN egp"
gsettings set $E/1/ icono "network-vpn-symbolic"
gsettings set $E/1/ icono-apagado "network-vpn-disabled-symbolic"
gsettings set $E/1/ encender "sudo -n systemctl start openvpn-egp"
gsettings set $E/1/ apagar "sudo -n systemctl stop openvpn-egp"
gsettings set $E/1/ estado "systemctl is-active --quiet openvpn-egp || { echo apagada; exit 1; }; d=\$(ip -br -4 addr show tun0 2>/dev/null | awk \"{print \\\$3}\"); echo \"egp\"; echo \"dirección: \${d:-levantando…}\"; systemctl show -p ActiveEnterTimestamp --value openvpn-egp"
gsettings set $E/1/ intervalo 5
gsettings set $E/1/ espera 25

# --- ranura 2: Waydroid ----------------------------------------------------------------------------------------
# systemd-run --user: la sesión de Waydroid NO debe ser hija de phosh (si phosh se reinicia, se la llevaría)
gsettings set $E/2/ titulo "Waydroid"
gsettings set $E/2/ icono "phone-symbolic"
gsettings set $E/2/ icono-apagado "phone-symbolic"
gsettings set $E/2/ encender "systemd-run --user --collect --unit=waydroid-sesion waydroid session start"
gsettings set $E/2/ apagar "waydroid session stop"
gsettings set $E/2/ estado "s=\$(waydroid status 2>/dev/null | sed -n \"s/^Session:[[:space:]]*//p\"); [ \"\$s\" = RUNNING ] || { echo parado; exit 1; }; echo \"en marcha\"; waydroid status 2>/dev/null | head -4"
gsettings set $E/2/ intervalo 5
gsettings set $E/2/ espera 30

echo "   ranuras configuradas"'
}

activar_ranuras() {
	ssh $SSH_OPTS "$MOVIL" "export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$(id -u)/bus
python3 - '$RANURAS' <<'PY'
import subprocess, sys, ast
nuevas = sys.argv[1].split()

# ⚠️ 0.59 movió la lista de complementos activos: estaba en «sm.puri.phosh.plugins quick-settings» y ahora
# está en «mobi.phosh.shell.plugins quick-settings» (subesquema plugins/, ver migrate_gsettings() de
# src/shell.c). Se prueban las dos para
# que el script valga en las dos versiones.
ESQ = None
for esq in ('mobi.phosh.shell.plugins', 'sm.puri.phosh.plugins'):
    if subprocess.run(['gsettings', 'get', esq, 'quick-settings'],
                      capture_output=True, text=True).returncode == 0:
        ESQ = esq
        break
if ESQ is None:
    print('   AVISO: no encuentro el esquema de la lista de complementos'); raise SystemExit(1)
actual = subprocess.run(['gsettings', 'get', ESQ, 'quick-settings'],
                        capture_output=True, text=True, check=True).stdout.strip()
lista = ast.literal_eval(actual) if actual.startswith('[') else []
antes = list(lista)
for n in nuevas:
    if n not in lista:
        lista.append(n)
if lista != antes:
    valor = '[' + ', '.join(\"'%s'\" % x for x in lista) + ']'
    subprocess.run(['gsettings', 'set', ESQ, 'quick-settings', valor], check=True)
    print('   activadas: %s' % ', '.join(x for x in lista if x not in antes))
else:
    print('   ya estaban activadas')
PY"
}

verificar() {
	echo ">> verificación"
	ssh $SSH_OPTS "$MOVIL" 'set -u
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
echo "   phosh instalado: $(apk info -v 2>/dev/null | grep -E "^phosh-[0-9]")"
echo "   complementos:    $(ls /usr/lib/phosh/plugins/libphosh-plugin-mandato*.so 2>/dev/null | wc -l) de 4"
echo "   esquema:         $(gsettings list-keys mobi.phosh.plugins.mandato:/mobi/phosh/plugins/mandato/1/ 2>/dev/null | tr "\n" " " || echo FALTA)"
echo "   activos:         $(gsettings get mobi.phosh.shell.plugins quick-settings 2>/dev/null || gsettings get sm.puri.phosh.plugins quick-settings 2>/dev/null)"
for n in 1 2; do
	E="mobi.phosh.plugins.mandato:/mobi/phosh/plugins/mandato/$n/"
	echo "   ranura $n: $(gsettings get $E titulo) -> encender=$(gsettings get $E encender)"
	m=$(gsettings get $E estado); m=$(printf "%s" "$m" | sed "s/^.//;s/.$//")
	if sh -c "$m" >/tmp/.ranura.$n 2>&1; then echo "      estado: ENCENDIDO ($(head -1 /tmp/.ranura.$n))"
	else echo "      estado: apagado ($(head -1 /tmp/.ranura.$n))"; fi
	rm -f /tmp/.ranura.$n
done
# ¿está cargado el complemento en el phosh que corre ahora?
if grep -q mandato /proc/$(pgrep -x phosh | head -1)/maps 2>/dev/null; then
	echo "   ✅ phosh en marcha YA tiene cargado el complemento"
else
	echo "   ⚠️ el phosh en marcha NO lo tiene cargado: cerrar sesión y volver a entrar"
fi'
}

if [ "${1:-}" = --ver ]; then verificar; exit 0; fi

if [ "${SOLO_CONFIG:-no}" = si ]; then
	echo ">> solo configuración (sin compilar)"
	config_ranuras; activar_ranuras; verificar; exit 0
fi

if [ "${SOLO_INSTALAR:-no}" = si ]; then
	echo ">> sin compilar: uso los .apk ya compilados"
else
echo ">> 1. copia a $IA_SSH:$APORT"
ssh "$IA_SSH" "mkdir -p $APORT"
rsync -a --delete "$P"/ "$IA_SSH:$APORT/"

echo ">> 2. aparto la receta de pmaports (pmbootstrap le haría caso a ella)"
ssh "$IA_SSH" "[ -d $DE_PMAPORTS ] && mv $DE_PMAPORTS $APARCADA || true"
devolver() { ssh "$IA_SSH" "[ -d $APARCADA ] && mv $APARCADA $DE_PMAPORTS && echo '   receta de pmaports devuelta' || true"; }
trap devolver EXIT INT TERM

echo ">> 3. checksum y compilación (phosh es grande: tarda)"
sh "$HERE/scripts/pmb.sh" checksum $PKG
sh "$HERE/scripts/pmb.sh" shutdown
# ⚠️ 2026-11-22: el buildroot aarch64 NO se crea bien con el systemd 262.2 de systemd-edge: el paquete
# trae el mismo fichero en «sbin/init» y «usr/sbin/init» (y «bin/udevadm» y «usr/bin/udevadm»), y con
# bin/sbin enlazados a usr/ el commit falla («failed to commit usr/sbin/init: No such file or directory»);
# apk sale con 2 y deja el estado tocado.
#   1. `--lax`: sin él pmbootstrap zampa el buildroot y vuelve a empezar.
#   2. `apk fix` en el buildroot lo deja sano y el segundo intento ya instala todo y compila.
sh "$HERE/scripts/pmb.sh" build --lax --force --arch aarch64 $PKG || {
	echo ">> el buildroot quedó con errores de apk (systemd 262.2 duplica bin/ y usr/bin/): apk fix y reintento"
	sh "$HERE/scripts/pmb.sh" chroot -b aarch64 -- apk fix || true
	sh "$HERE/scripts/pmb.sh" build --lax --force --arch aarch64 $PKG
}
scp -q "$IA_SSH:$APORT/APKBUILD" "$P/APKBUILD"

# ⚠️ 02-10: la primera versión NO SE CARGABA («Custom quick setting 'mandatoN-quick-setting' not found») porque
# llamaba a tres funciones que están en las cabeceras de phosh pero NO en la biblioteca:
# phosh_status_page_placeholder_new, ..._set_extra_widget y phosh_quick_setting_set_status_icon. Los complementos de
# serie no se enteran porque crean esos objetos desde su plantilla .ui. Este paso lo caza al compilar, no en el móvil.
echo ">> 3b. ¿exporta libphosh todo lo que usa el complemento?"
ssh "$IA_SSH" "BASE=$BASE V=$V R=$R sh -s" <<'EOF'
set -eu
T=$(mktemp -d); cd "$T"
tar xzf "$BASE/work/packages/edge/aarch64/phosh-$V-r$R.apk" usr/lib/phosh/plugins/libphosh-plugin-mandato1-quick-setting.so
tar xzf "$BASE/work/packages/edge/aarch64/libphosh-$V-r$R.apk" 2>/dev/null
SO=usr/lib/phosh/plugins/libphosh-plugin-mandato1-quick-setting.so
L=$(ls usr/lib/libphosh-*.so.[0-9] 2>/dev/null | head -1)
[ -n "$L" ] || { echo "ERROR: no encuentro libphosh en el .apk"; exit 1; }
FALTA=""
for s in $(nm -D --undefined-only "$SO" | grep -oE "phosh_[a-z_0-9]+" | sort -u); do
	nm -D --defined-only "$L" | grep -qw "$s" || FALTA="$FALTA $s"
done
cd /; rm -rf "$T"
if [ -n "$FALTA" ]; then
	echo "ERROR: libphosh NO exporta:$FALTA"
	echo "   un complemento que las llame NO SE CARGA y phosh solo dice «not found»."
	echo "   Usar la propiedad equivalente (g_object_set) o widgets GTK normales."
	exit 1
fi
echo "   todos los símbolos que usa están exportados"
EOF

echo ">> 4. traer los .apk"
D="$HOME/compilados-ia/spacewar/$PKG-$V-r$R"; mkdir -p "$D"
A=$BASE/work/packages/edge/aarch64
for s in $SUB; do rsync -a "$IA_SSH:$A/$s-$V-r$R.apk" "$D/"; done
( cd "$D" && sha256sum *.apk > SHA256SUMS && cat SHA256SUMS )
[ "${INSTALAR:-no}" = si ] || { echo ">> Hecho: $D  (instalar: INSTALAR=si sh scripts/96-botones-mandato.sh)"; exit 0; }
fi
D="$HOME/compilados-ia/spacewar/$PKG-$V-r$R"
[ -d "$D" ] || { echo "ERROR: no están los .apk en $D (compilar sin SOLO_INSTALAR)"; exit 1; }

echo ">> 5. instalar en $MOVIL"
ssh $SSH_OPTS "$MOVIL" true 2>/dev/null || { echo "ERROR: $MOVIL no responde por ssh"; exit 1; }
ssh $SSH_OPTS "$MOVIL" 'df -h / | tail -1'
F=""; for s in $SUB; do F="$F /tmp/$s-$V-r$R.apk"; done
for s in $SUB; do scp -q $SSH_OPTS "$D/$s-$V-r$R.apk" "$MOVIL:/tmp/"; done
# guardia: se compila contra el edge de hoy y el móvil va por detrás; si apk fuera a tocar algo más, se para
PAT=$(echo $SUB | tr ' ' '|')
OTROS=$(ssh $SSH_OPTS "$MOVIL" "sudo -n apk add --simulate --allow-untrusted $F 2>&1" | grep -E 'Upgrading|Installing' | grep -vE "(Upgrading|Installing) ($PAT) " || true)
if [ -n "$OTROS" ] && [ "${ACTUALIZAR_OTROS:-no}" != si ]; then
	echo "ERROR: además de lo nuestro, apk actualizaría esto (repetir con ACTUALIZAR_OTROS=si si se acepta):"
	echo "$OTROS" | sed 's/^/   /'; ssh $SSH_OPTS "$MOVIL" "rm -f $F"; exit 1
fi
ssh $SSH_OPTS "$MOVIL" "sudo -n apk add --allow-untrusted $F && rm -f $F && apk info -v 2>/dev/null | grep -E '^phosh-[0-9]'"

echo ">> 6. configurar las ranuras"
config_ranuras
activar_ranuras
verificar
echo ">> ⚠️ para que phosh CARGUE el complemento hay que cerrar sesión y volver a entrar (o reiniciar)."
