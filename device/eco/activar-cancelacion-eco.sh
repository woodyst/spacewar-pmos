#!/bin/sh
# activar-cancelacion-eco.sh — cancelación de eco de las llamadas en cada arranque (spacewar, 2026-09-12).
# Adaptado de surya (parches/audio/eco/activar-cancelacion-eco.sh).
#
# Qué hace falta para que el DSP cancele el eco:
#   1. el PD de audio del ADSP servido (hexagonrpcd-adsp-audiopd.service): la canceladora es un módulo
#      dinámico que ese PD carga por fastrpc
#   2. las topologías propias del fabricante registradas en el DSP (q6core custom_topologies) y sus módulos
#      cargados (load_topology)
#   3. los parámetros del kernel: directorio de la calibración (cal_dir, r113), CREATE V3, topologías TX/RX
#      del fabricante, preparación del vocproc con calibración (vendor_steps=15, cal_set) y mapeo con
#      is_cached=1 (map_cached)
#
# ⚠️ Los parámetros SOLO se ponen si 1 y 2 salieron bien. Con la topología del fabricante y sin ellos, el
#    vocproc no confirma y la llamada queda MUDA. Si algo falla se dejan los de paso directo (la llamada
#    funciona, sin cancelar el eco) y queda escrito en el diario.
#
# Topologías de fábrica de Nothing (calibraciones/captura-2026-09-12): manos libres TX 0x10000003 /
# RX 0x10010F8B (las mismas que surya); auricular TX 0x1000BFF1 (2 canales) / RX 0x1000BFF2, con módulos propios
# 0x1000B500/0x1000B501 sin comprobar. Por defecto las de manos libres.
#
# Ajustes (opcional) en /etc/default/cancelacion-eco (⚠️ pmOS no trae /etc/default: lo crea 76-cancelacion-eco.sh;
# tras cambiarlo, `systemctl restart cancelacion-eco` y comprobar /sys/module/q6cvp/parameters/create_v3):
#   ECO=0                 no activar nada (paso directo)
#   CAL_SET=speaker       juego de calibración (handset|speaker|handset-aec|speaker-aec)
#   TX=0x10000003 RX=0x10010F8B
#
# CAL_SET=speaker por defecto (2026-09-13): las topologías son las de manos libres, y los datos del auricular son
# para las de Nothing (0x1000BFF1/0x1000BFF2). Con 'handset' sobre estas topologías el micro volvía a la salida
# (el usuario se oía a sí mismo y acoplaba; pruebas/sidetone-medida.sh: ruido entre pulsos 7990 frente a 26). El
# UCM también pone Speaker en el auricular; con esto la llamada ya arranca con ella, sin rehacer el vocproc.
set -u
ECO=1; CAL_SET=speaker; TX=0x10000003; RX=0x10010F8B
[ -f /etc/default/cancelacion-eco ] && . /etc/default/cancelacion-eco
M=/sys/module
DIR=qcom/sm7325/nothing/spacewar/
FW=${DIR}acdb-custom-topologies.bin
log() { logger -t cancelacion-eco "$*"; echo "$*"; }

paso_directo() {
	echo N > $M/q6cvp/parameters/create_v3 2>/dev/null
	echo 0x10F70 > $M/q6cvp/parameters/tx_topology 2>/dev/null
	echo 0x10F77 > $M/q6cvp/parameters/rx_topology 2>/dev/null
	echo 0 > $M/q6voice/parameters/vendor_steps 2>/dev/null
}
falla() { log "⛔ $* -> llamadas en paso directo, SIN cancelación de eco"; paso_directo; exit 1; }

[ "$ECO" = 1 ] || { log "ECO=0 en /etc/default/cancelacion-eco: paso directo"; paso_directo; exit 0; }

# Los parámetros existen cuando la tarjeta ha cargado los módulos de voz.
n=0
until [ -e $M/q6voice/parameters/vendor_steps ] && [ -e $M/q6core/parameters/custom_topologies ] \
      && [ -e $M/q6mvm/parameters/map_cached ]; do
	n=$((n + 1)); [ $n -gt 120 ] && falla "los módulos de voz no aparecen"
	sleep 1
done
[ -e $M/q6voice/parameters/cal_dir ] || falla "el kernel no tiene q6voice cal_dir (hace falta r113)"
[ -f /lib/firmware/$FW ] || falla "falta /lib/firmware/$FW (scripts/75-calibracion-voz.sh)"
for p in handset speaker; do
	[ -f /lib/firmware/${DIR}voice-$p-static.bin ] || falla "falta la calibración voice-$p-* (scripts/75-calibracion-voz.sh)"
done
printf '%s' "$DIR" > $M/q6voice/parameters/cal_dir

# 1. el PD de audio
n=0
until systemctl is-active -q hexagonrpcd-adsp-audiopd.service; do
	n=$((n + 1)); [ $n -gt 60 ] && falla "hexagonrpcd-adsp-audiopd no está activo"
	sleep 1
done

# 2. topologías del fabricante (el resultado del DSP solo sale en el registro del kernel)
MARCA="cancelacion-eco: registro $(date +%s)"
echo "$MARCA" > /dev/kmsg
echo $FW > $M/q6core/parameters/custom_topologies || falla "no se pudo pedir el registro de topologías"
sleep 2
dmesg | sed -n "/$MARCA/,\$p" | grep -q "register custom topologies .*): 0$" \
	|| falla "el DSP no aceptó las topologías propias"
for t in $TX $RX; do
	echo $t > $M/q6core/parameters/load_topology || falla "no se cargaron los módulos de la topología $t"
done

# 3. parámetros
echo Y > $M/q6cvp/parameters/create_v3
echo $TX > $M/q6cvp/parameters/tx_topology
echo $RX > $M/q6cvp/parameters/rx_topology
echo Y > $M/q6mvm/parameters/map_cached
printf '%s' "$CAL_SET" > $M/q6voice/parameters/cal_set
echo 15 > $M/q6voice/parameters/vendor_steps
log "✓ cancelación de eco lista: TX $TX, RX $RX, calibración $CAL_SET ($DIR)"
