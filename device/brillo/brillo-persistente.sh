#!/bin/sh
# Guarda y restaura el brillo de la pantalla entre arranques (spacewar, 2026-09-12; copiado de surya).
#
# systemd-backlight ya lo hace, pero restaura MUY pronto y su valor guardado se queda viejo: en
# spacewar tenía 160 de 4095 y la pantalla salía casi a oscuras. Este restaura tarde, con la sesión
# gráfica ya en pie, así que es el último en hablar. Sin nada guardado todavía, pone el máximo.
#
#   brillo-persistente.sh guardar     (al apagar, y cada minuto con el temporizador)
#   brillo-persistente.sh restaurar   (al arrancar, tras la sesión)
#
# El panel no se llama igual en cada móvil (surya: backlight; spacewar: ae94000.dsi.0): se usa el
# primero que haya en /sys/class/backlight.
B=$(ls -d /sys/class/backlight/* 2>/dev/null | head -1)
ESTADO=/var/lib/brillo-persistente
[ -n "$B" ] || exit 0

case "$1" in
guardar)
	[ -r "$B/brightness" ] || exit 0
	v=$(cat "$B/brightness")
	# No guardar el 0: la pantalla apagada marca 0, y restaurarlo dejaría el móvil aparentemente muerto.
	[ "$v" -gt 0 ] 2>/dev/null && echo "$v" > "$ESTADO"
	;;
restaurar)
	max=$(cat "$B/max_brightness")
	v=$max
	[ -r "$ESTADO" ] && v=$(cat "$ESTADO")
	[ "$v" -gt 0 ] 2>/dev/null && [ "$v" -le "$max" ] 2>/dev/null || v=$max
	# Esperar a que la sesión gráfica haya puesto lo suyo, para escribir después y no pelearse con ella.
	sleep 12
	echo "$v" > "$B/brightness"
	;;
esac
