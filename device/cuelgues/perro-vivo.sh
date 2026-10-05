#!/bin/sh
# Perro guardián por HARDWARE que exige que el móvil SIRVA, no sólo que respire.
# (spacewar, 2026-09-13: copiado de surya, suria/parches/cuelgues/. En spacewar el perro es el de Gunyah,
#  /dev/watchdog de CONFIG_GUNYAH_WATCHDOG, margen máximo 32 s.)
#
# EL PROBLEMA
#   systemd acaricia /dev/watchdog desde PID 1. Eso sólo prueba que PID 1 existe.
#   El 2026-08-23 el móvil estuvo minutos congelado -- pantalla muerta, teclas sin
#   respuesta, sin red -- con systemd vivo acariciando tan tranquilo. El perro no
#   ladró hasta que systemd tambien murió, a los 6009 s. Y sin poder reiniciar en
#   caliente, hubo que apagar con el botón: eso BORRA la RAM y con ella ramoops.
#   Resultado: cero evidencia de un cuelgue de varios minutos.
#
#   Medido: cuando PID 1 deja de acariciar, el perro ladra en ~5 s. Funciona. Lo
#   que falla es el criterio.
#
# QUÉ HACE ESTE
#   Coge el perro y sólo lo acaricia si supera una prueba de vida DE VERDAD:
#   crear un proceso, escribir y leer un fichero, y leer /proc. Son justo las
#   cosas que dejan de funcionar en un congelado aunque PID 1 siga en pie.
#   Si la prueba falla varias veces seguidas, deja de acariciar -> reinicio POR
#   HARDWARE en caliente -> la RAM se conserva -> **ramoops queda intacto**.
#
# ⚠️ PARA QUE FUNCIONE hay que soltarle el perro a systemd:
#      /etc/systemd/system.conf ->  RuntimeWatchdogSec=0
#    Si no, systemd lo tiene abierto y este no puede cogerlo.
#
# ⚠️ RIESGO: una prueba de vida demasiado estricta reinicia el móvil sin motivo.
#    Por eso: prueba barata, plazo generoso, y hacen falta VARIOS fallos seguidos.
#    Con los valores de serie, un congelado real reinicia en ~40-60 s.
#
# ⚠️ Al parar el servicio se escribe 'V' (cierre mágico) para desarmar el perro.
#    Sin eso, el móvil se reiniciaría solo tras un apagado limpio.
set -u

# Se puede sobrescribir SOLO para probar: apuntandolo a un fichero normal se
# ejercita el guion entero -- autodiagnostico, caricias, camino de fallo y avisos
# a kmsg -- sin tocar el perro de verdad. Sin esto no habia forma de probar la
# rama de fallo sin arriesgarse a un reinicio.
DISPOSITIVO=${DISPOSITIVO:-/dev/watchdog}
PLAZO=${PLAZO:-30}          # margen del perro, en segundos (max 32 en este SoC)
CADA=${CADA:-5}             # cada cuanto se comprueba la vida
FALLOS=${FALLOS:-2}         # fallos seguidos antes de dejar de acariciar
ESPERA_PRUEBA=${ESPERA_PRUEBA:-8}
# ⚠️ El plazo del disco tiene que caber HOLGADAMENTE en el margen del perro (30 s):
#    mientras la prueba de disco esta bloqueada NO se acaricia, asi que un plazo
#    largo se come el margen y provoca un mordisco por accidente. Con 10 s y
#    acariciando ANTES de la prueba, el peor caso es 10+5 = 15 s sin caricia.
ESPERA_DISCO=${ESPERA_DISCO:-10}
# Cada cuantas vueltas se toca el almacenamiento de verdad. Cada vuelta seria
# despertar el UFS cada 5 s, y este movil ha costado mucho en consumo.
CADA_DISCO=${CADA_DISCO:-6}
DIR_DISCO=${DIR_DISCO:-/var/lib/perro-vivo}
# Gracia antes de dejar que muerda: da tiempo a que la marca llegue al disco y a
# que journald vuelque sus ultimos apuntes. Se acaricia una vez mas justo antes,
# asi que estos segundos NO se comen el margen del perro.
GRACIA=${GRACIA:-5}
# ★ MODO SOLO COMPROBAR (SOLO_COMPROBAR=1): hace las mismas pruebas, con el mismo
#   ritmo y los mismos contadores, PERO NO ABRE /dev/watchdog. Sin abrirlo no hay
#   perro armado, asi que es IMPOSIBLE que reinicie el movil pase lo que pase.
#   Solo anota lo que HABRIA hecho.
#
#   Sirve para responder la pregunta que de otro modo cuesta un reinicio: ¿falla
#   de verdad la prueba de vida —o la de disco— en la tormenta del arranque y del
#   login? Se lanza a mano:
#       sudo SOLO_COMPROBAR=1 /usr/local/sbin/perro-vivo.sh 2>&1 | tee /tmp/perro.log
SOLO_COMPROBAR=${SOLO_COMPROBAR:-0}
MARCAS=${MARCAS:-$DIR_DISCO/mordiscos.log}

# ⚠️⚠️ DOS DESTINOS, Y EL SEGUNDO ES EL QUE IMPORTA.
#
# El diario no sirve para lo unico que este guion tiene que contar. Si el movil
# se muere de golpe, journald no llega a volcar sus ultimos apuntes y el aviso se
# pierde: eso paso el 2026-08-25, con dos muertes subitas y ni una linea del
# perro para saber si habia actuado o si el movil se murio solo.
#
# El anillo del kernel si sobrevive: con `console_loglevel` en 7 (el de este
# movil) todo lo que se escribe en /dev/kmsg sale por la consola, y la consola la
# graba ramoops en su region persistente. Tras reiniciar aparece en
# /var/lib/systemd/pstore/console-ramoops-0.
#
# ⚠️ Cada escritura tiene que ser UN solo write: /dev/kmsg guarda un registro por
#    escritura, asi que nada de construir la linea a trozos.
# ⚠️ El prefijo <N> es la prioridad. Se usa 4 (aviso) para lo rutinario y 2
#    (critico) para lo que no se puede perder, por si algun dia baja el
#    console_loglevel de este movil: 2 pasa practicamente siempre.
KMSG=/dev/kmsg

a_kmsg() {
	[ -w "$KMSG" ] || return 0
	printf '<%s>perro-vivo: %s\n' "$1" "$2" > "$KMSG" 2>/dev/null || true
}

log()       { echo "perro-vivo: $*"; a_kmsg 4 "$*"; }
# Para lo que TIENE que sobrevivir al reinicio.
log_grave() { echo "perro-vivo: $*"; a_kmsg 2 "$*"; }

# ⚠️ `[ -w ]` NO basta: para root da verdadero aunque el dispositivo este OCUPADO.
#    Y ojo: un `exec` con redireccion fallida MATA el interprete, asi que el
#    intento de apertura va en un SUBINTERPRETE y el de verdad despues.
if [ "$SOLO_COMPROBAR" = 1 ]; then
	log "MODO SOLO COMPROBAR: no se abre $DISPOSITIVO, es IMPOSIBLE que reinicie."
elif ! ( exec 3>"$DISPOSITIVO" ) 2>/dev/null; then
	log "no puedo abrir $DISPOSITIVO."
	log "  Casi seguro lo tiene systemd. Sueltaselo con:"
	log "    RuntimeWatchdogSec=0 en /etc/systemd/system.conf  +  systemctl daemon-reexec"
	exit 1
fi

# La prueba de vida: crear proceso, escribir, leer, y mirar /proc. Barata, y toca
# justo lo que se muere en un congelado.
vivo() {
	timeout "$ESPERA_PRUEBA" sh -c '
		f=/run/perro-vivo.marca
		echo $$ > "$f" 2>/dev/null || exit 1
		read -r _ < "$f"           || exit 1
		read -r _ < /proc/uptime   || exit 1
		exit 0
	' 2>/dev/null
}

# ⚠️ Solo se anota UNA vez: las rutas de error llaman a `desarmar` y ademas salta
#    la trampa de EXIT, asi que sin este cerrojo la linea aparece por duplicado en
#    ramoops -- y ahi, donde se lee un cadaver, un mensaje repetido es una pista
#    falsa de que algo paso dos veces.
DESARMADO=0
# ⚠️⚠️ LA PRUEBA DE ARRIBA TIENE UN PUNTO CIEGO, Y ES EL IMPORTANTE.
#
# Crear un proceso, escribir en /run y leer /proc funciona PERFECTAMENTE durante
# un congelado del UFS: /run es memoria y /proc es virtual, no tocan disco. Es
# decir, en el fallo que este perro existe para cubrir —el abrazo mortal del
# almacenamiento, con el kernel vivo y ocioso— la prueba pasa tan contenta, el
# perro sigue acariciando y el movil se queda congelado PARA SIEMPRE.
#
# Asi que hay una segunda prueba que escribe en el disco DE VERDAD y fuerza el
# volcado con `conv=fsync`. Si el UFS esta bloqueado, esto se queda colgado, el
# `timeout` lo corta, y el perro por fin muerde.
#
# ⚠️ No en cada vuelta: eso despertaria el almacenamiento cada 5 s.
# ⚠️ Y se acaricia ANTES de llamarla, nunca despues: mientras esta bloqueada no
#    se acaricia, y el margen corre.
vivo_disco() {
	timeout "$ESPERA_DISCO" sh -c '
		d=$1; f="$d/latido"
		mkdir -p "$d" 2>/dev/null || exit 1
		echo "$$ $(cut -d" " -f1 /proc/uptime)" | dd of="$f" conv=fsync 2>/dev/null || exit 1
		read -r _ < "$f" || exit 1
		exit 0
	' _ "$DIR_DISCO" 2>/dev/null
}

# ★ PILAS ANTES DE REINICIAR (spacewar, 2026-09-14).
#
# El 2026-09-14 11:16 el disco dejó de responder y este perro reinició el móvil
# a los ~70 s. El detector de tareas colgadas avisa a los 120 s: llegó TARDE, y
# el volcado de ramoops no tenía ni una pila. Sin pilas no se distingue el
# abrazo mortal del UFS de surya de cualquier otra cosa.
#
# Así que, al PRIMER fallo de cada racha, se piden al kernel las tareas en
# estado D con su pila (SysRq w). Van por la consola a ramoops. `echo` es interno
# del intérprete y /proc no toca disco: funciona con el almacenamiento muerto.
# Una sola vez por racha: el volcado ocupa decenas de KB y ramoops es pequeño.
volcar_bloqueadas() {
	log_grave "volcando tareas bloqueadas (SysRq w) a ramoops: $1"
	echo w > /proc/sysrq-trigger 2>/dev/null || log_grave "AVISO: no pude escribir en /proc/sysrq-trigger"
}

desarmar() {
	[ "$SOLO_COMPROBAR" = 1 ] && return 0
	printf 'V' > "$DISPOSITIVO" 2>/dev/null || return 0
	[ $DESARMADO -eq 1 ] && return 0
	DESARMADO=1
	log_grave "perro desarmado (cierre mágico)"
}
trap 'desarmar; exit 0' INT TERM EXIT

# ★ AUTODIAGNOSTICO ANTES DE ARMAR NADA. Armar un perro cuya prueba de vida esta
#   rota es la forma mas rapida de meter al movil en un bucle de reinicios. Si la
#   prueba no pasa con el sistema SANO, no se arma y se dice por que.
n=0
for i in 1 2 3 4 5; do vivo && n=$((n+1)); done
if [ $n -lt 5 ]; then
	log_grave "⛔ NO ARMO: la prueba de vida solo pasa $n de 5 con el sistema sano."
	log "   Con el perro armado, eso reiniciaria el movil sin motivo."
	log "   Comprueba que /run es escribible por root y que 'timeout' existe."
	desarmar; exit 1
fi
if ! vivo_disco; then
	log_grave "⛔ NO ARMO: la prueba de DISCO no pasa con el sistema sano."
	log_grave "   Comprueba que $DIR_DISCO se puede crear y que 'dd conv=fsync' existe."
	desarmar; exit 1
fi
log "autodiagnostico: prueba de vida 5 de 5, y el disco responde"

[ "$SOLO_COMPROBAR" = 1 ] || exec 3>"$DISPOSITIVO"          # ahora si, de verdad
# ⚠️ El margen NO se fija por sysfs: ese fichero es de SOLO LECTURA y el intento
#    solo ensucia el diario ("Permission denied"). El driver aplica su propio
#    valor al abrirlo -- en este SoC, 30 s, que es justo lo que queriamos. Se lee
#    y se informa del real, sin intentar cambiarlo.
PLAZO_REAL=$(cat /sys/class/watchdog/watchdog0/timeout 2>/dev/null)
# En kmsg tambien, para que el arranque quede marcado en ramoops: si tras una
# muerte subita aparece este "armado" pero NO aparece ningun "DEJO DE ACARICIAR",
# el perro no fue -- el movil se murio por otro lado.
if [ "$SOLO_COMPROBAR" = 1 ]; then
	log_grave "vigilando SIN armar: prueba cada ${CADA}s, disco cada $((CADA * CADA_DISCO))s. No puede reiniciar."
else
	log_grave "armado: margen ${PLAZO_REAL:-?}s (lo fija el driver), prueba cada ${CADA}s, $FALLOS fallos para soltar"
fi

# Dejar constancia EN DISCO de por que va a reiniciar, y luego reiniciar.
#
# POR QUE (2026-08-26): el movil entro en un bucle de reinicios y no habia forma
# de saber si el perro tenia algo que ver. El diario no llega a volcarse, y el
# anillo del kernel —que si sobrevive en ramoops— es un bufer de 84 KB que EN
# ESE ARRANQUE SE DIO LA VUELTA ENTERO EN DIEZ SEGUNDOS: la tormenta de mensajes
# del audio se comio cualquier rastro anterior. Un fichero en disco no se da la
# vuelta.
#
# ⚠️ La escritura va con PLAZO y es de mejor esfuerzo: si lo que falla es
#    justamente el almacenamiento, aqui no se puede esperar. Que no se pueda
#    dejar la marca NO debe impedir el mordisco.
# ⚠️ Se acaricia una ultima vez antes de la espera de gracia: si no, esos
#    segundos saldrian del margen del perro y el reinicio llegaria antes de
#    tiempo, quiza a mitad de escribir la marca.
morder() {
	MOTIVO="$1"
	log_grave "DEJO DE ACARICIAR ($MOTIVO): reiniciara en <=${PLAZO}s tras ${GRACIA}s de gracia."

	[ "$SOLO_COMPROBAR" = 1 ] || printf '\0' >&3 2>/dev/null || true    # una ultima caricia

	# ⚠️ El `|| exit 1` de la escritura NO SOBRA. Sin el, el estado de salida era
	#    el del `sync` final —que devuelve 0 aunque el `printf` haya fallado— y
	#    el guion anunciaba "marca escrita" con el disco en solo lectura.
	#    Cazado probandolo: es justo el caso real, el disco que no admite escrituras.
	timeout "$GRACIA" sh -c '
		d=$(dirname "$2"); mkdir -p "$d" 2>/dev/null
		printf "%s uptime=%s motivo=%s\n" \
			"$(date "+%Y-%m-%d %H:%M:%S")" \
			"$(cut -d" " -f1 /proc/uptime)" \
			"$1" >> "$2" || exit 1
		sync "$2" 2>/dev/null || true
	' _ "$MOTIVO" "$MARCAS" 2>/dev/null \
		&& log_grave "marca escrita en $MARCAS" \
		|| log_grave "AVISO: no se pudo escribir la marca (¿el disco?)"

	if [ "$SOLO_COMPROBAR" = 1 ]; then
		log_grave "(SOLO COMPROBAR) aqui habria reiniciado. Sigo comprobando."
		fallos_vida=0
		fallos_disco=0
		return 0
	fi
	sleep "$GRACIA"
	log_grave "se acabo la gracia: dejo de acariciar"
	while :; do sleep 60; done
}

# ⚠️⚠️ DOS CONTADORES SEPARADOS, Y NO ES UN DETALLE.
#
# Con un solo contador, un disco muerto NUNCA llegaba a provocar el mordisco:
# fallaba la prueba de disco, y en la vuelta siguiente la prueba barata pasaba
# —porque el kernel esta vivo— y ponia el contador a cero. Bucle infinito de
# "PRUEBA DE DISCO FALLIDA (1/2)" + "vida recuperada", con el movil congelado
# para siempre. O sea: el punto ciego que esto venia a tapar, otra vez, movido
# un piso mas arriba. Cazado probandolo con un tmpfs remontado de solo lectura.
fallos_vida=0
fallos_disco=0
vuelta=0
while :; do
	vuelta=$((vuelta + 1))
	if vivo; then
		[ $fallos_vida -gt 0 ] && log "vida recuperada tras $fallos_vida fallo(s)"
		fallos_vida=0
		[ "$SOLO_COMPROBAR" = 1 ] || printf '\0' >&3        # caricia
		# ⚠️ La prueba de disco va DESPUES de acariciar, a proposito: puede
		#    bloquearse hasta $ESPERA_DISCO segundos y durante ese rato el
		#    margen del perro corre sin que nadie lo renueve.
		if [ $((vuelta % CADA_DISCO)) -eq 0 ]; then
			if vivo_disco; then
				[ $fallos_disco -gt 0 ] && log "disco recuperado tras $fallos_disco fallo(s)"
				fallos_disco=0
			else
				fallos_disco=$((fallos_disco + 1))
				log_grave "PRUEBA DE DISCO FALLIDA ($fallos_disco/$FALLOS): el almacenamiento no responde"
				[ $fallos_disco -eq 1 ] && volcar_bloqueadas "disco"
				if [ $fallos_disco -ge $FALLOS ]; then
					morder "prueba de DISCO fallida $fallos_disco/$FALLOS"
				fi
			fi
		fi
	else
		fallos_vida=$((fallos_vida + 1))
		log_grave "PRUEBA DE VIDA FALLIDA ($fallos_vida/$FALLOS)"
		[ $fallos_vida -eq 1 ] && volcar_bloqueadas "vida"
		if [ $fallos_vida -ge $FALLOS ]; then
			morder "prueba de VIDA fallida $fallos_vida/$FALLOS"
		fi
	fi
	sleep "$CADA"
done
