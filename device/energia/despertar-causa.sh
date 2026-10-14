#!/bin/sh
# /usr/local/sbin/despertar-causa.sh — sonda del kernel que responde QUÉ despierta al móvil (2026-09-17;
# permanente desde 2026-10-14). Lo instala scripts/99-ganchos-suspension.sh y lo arranca
# despertar-causa.service al encender el móvil: antes la sonda se armaba a mano y un reboot la borraba.
#
# POR QUÉ: desde espacio de usuario no se puede saber la causa. `pm_wakeup_irq` solo guarda las DOS primeras
# interrupciones (drivers/base/power/wakeup.c: wakeup_irq[0], wakeup_irq[1], la tercera se tira), así que
# «ninguna» puede significar «no hubo» o «se perdió» (26 de 34 despertares). Y en suspensión profunda quien
# despierta el SoC es el PDC de Qualcomm, por debajo de Linux: si la interrupción no estaba marcada como
# fuente de despertar, el núcleo la procesa al volver sin anotar la causa. Entonces la culpable es
# LA PRIMERA INTERRUPCIÓN ATENDIDA al reanudar, y `irq:irq_handler_entry` da su número y su nombre.
#
# QUÉ ARMA (instancia propia; no toca las sondas de contadores-glink, aunque comparte el kprobe global pmirq):
#   p:pmirq  pm_system_irq_wakeup irq=$arg1:u32  -> la interrupción exacta, en el instante del evento
#   p:pmwake pm_system_wakeup                    -> la vía GENÉRICA de despertar (la usan también las fuentes)
#   power:wakeup_source_activate                 -> el NOMBRE de la fuente, para los despertares sin IRQ
#   power:suspend_resume                         -> situar el momento (en suria el despertar cayó 151 µs ANTES
#                                                 de terminar de suspender)
#   irq:irq_handler_entry                        -> ⭐ la que identifica la causa
#
# ⚠️ La grabación queda PARADA: con el móvil despierto, irq_handler_entry llena el búfer en segundos. El gancho
# 50-despertar-y-sensores la arranca justo antes de dormir y la para a los 51-65 ms de reanudar, de modo que el
# búfer conserva exactamente el sueño y las primeras interrupciones.
#
# Uso:  despertar-causa.sh armar | leer | desarmar
# Leer: sudo /usr/local/sbin/despertar-causa.sh leer
set -u
T=/sys/kernel/tracing
[ -d "$T" ] || T=/sys/kernel/debug/tracing
I=$T/instances/despertar-causa

case "${1:-}" in
armar)
	mkdir -p "$I" 2>/dev/null || true
	echo 0 > "$I/tracing_on"
	echo boot > "$I/trace_clock" 2>/dev/null || true
	# 2048 KB: con 256 solo cabía UN ciclo, porque suspend_resume emite decenas de eventos por suspensión
	# (todos los CPU_ON/CPU_OFF). Con esto caben varios seguidos.
	echo 2048 > "$I/buffer_size_kb"
	echo > "$I/trace"
	# los kprobes son globales (kprobe_events); los eventos se habilitan por instancia
	grep -q '^p:kprobes/pmirq ' "$T/kprobe_events" 2>/dev/null || \
		echo 'p:pmirq pm_system_irq_wakeup irq=$arg1:u32' >> "$T/kprobe_events"
	grep -q '^p:kprobes/pmwake ' "$T/kprobe_events" 2>/dev/null || \
		echo 'p:pmwake pm_system_wakeup' >> "$T/kprobe_events"
	echo 1 > "$I/events/kprobes/pmirq/enable"
	echo 1 > "$I/events/kprobes/pmwake/enable" 2>/dev/null || echo "   ⚠️ pmwake no se pudo armar"
	echo 1 > "$I/events/power/wakeup_source_activate/enable"
	echo 1 > "$I/events/power/suspend_resume/enable"
	echo 1 > "$I/events/irq/irq_handler_entry/enable"
	# nooverwrite: al llenarse, PARE en vez de machacar el principio, que es lo único que interesa
	echo nooverwrite > "$I/trace_options" 2>/dev/null || true
	echo 0 > "$I/tracing_on"
	echo > "$I/trace"
	echo "   armado (la grabación la arranca el gancho al dormir): pmirq=$(cat $I/events/kprobes/pmirq/enable) pmwake=$(cat $I/events/kprobes/pmwake/enable 2>/dev/null) ws=$(cat $I/events/power/wakeup_source_activate/enable) sr=$(cat $I/events/power/suspend_resume/enable) irq=$(cat $I/events/irq/irq_handler_entry/enable) buffer=$(cat $I/buffer_size_kb)KB"
	;;
leer)
	[ -d "$I" ] || { echo "   no armado"; exit 0; }
	echo "   --- interrupciones que despertaron (pm_system_irq_wakeup):"
	grep 'pmirq:' "$I/trace" 2>/dev/null | tail -6 | sed 's/^ */     /'
	echo "   --- fuentes de despertar activadas (con nombre):"
	grep 'wakeup_source_activate' "$I/trace" 2>/dev/null | tail -8 | sed 's/^ */     /'
	echo "   --- ⭐ PRIMERAS INTERRUPCIONES ATENDIDAS AL REANUDAR (la causa, si no hubo pmirq):"
	awk '/syscore_resume\[0\] end/ { vista=1; for(i=1;i<=NF;i++) if ($i ~ /^[0-9]+\.[0-9]+:$/) {t0=$i; sub(/:$/,"",t0)}; next }
	     vista && /irq_handler_entry/ {
	        for(i=1;i<=NF;i++) if ($i ~ /^[0-9]+\.[0-9]+:$/) {t=$i; sub(/:$/,"",t)}
	        n++; printf "     +%7.3f ms  %s\n", (t-t0)*1000, substr($0, index($0, "irq_handler_entry:"))
        if (n >= 12) exit }' "$I/trace" 2>/dev/null
	echo "     (vacío = ninguna interrupción tras reanudar, o la grabación no estaba activa)"
	echo "   --- último ciclo de suspensión:"
	grep 'suspend_resume' "$I/trace" 2>/dev/null | tail -6 | sed 's/^ */     /'
	echo "   --- traducción de las IRQ vistas:"
	for n in $(grep -o 'irq=[0-9]*' "$I/trace" 2>/dev/null | cut -d= -f2 | sort -u | tail -5); do
		printf "     irq %-4s -> %s\n" "$n" "$(awk -v n="$n:" '$1 == n { $1=""; $2=""; print substr($0, 3, 60) }' /proc/interrupts | head -1)"
	done
	;;
desarmar)
	[ -d "$I" ] && { echo 0 > "$I/tracing_on"; echo 0 > "$I/events/kprobes/pmirq/enable" 2>/dev/null; } || true
	echo "   desarmado (el kprobe global se deja: lo comparte contadores-glink)"
	;;
*) echo "uso: despertar-causa.sh armar|leer|desarmar" >&2; exit 2 ;;
esac
