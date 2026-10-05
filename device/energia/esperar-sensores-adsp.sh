#!/bin/sh
# esperar-sensores-adsp.sh — espera a que el concentrador de sensores del ADSP (SSC) conteste (2026-09-28)
#
# POR QUÉ: iio-sensor-proxy busca los sensores UNA sola vez al arrancar (find_sensors) y después solo reacciona a
# avisos de udev. El concentrador tarda ~86 s en cargar tras el arranque, así que si el servicio arranca antes
# (lo hace a los ~8 s) se queda SIN ACELERÓMETRO para todo el arranque: phosh no ofrece la rotación automática.
# Pasó el 27-09: 14 horas con HasAccelerometer=false y un solo arranque del servicio.
#
# Se usa como ExecStartPre de iio-sensor-proxy. `ssccli` lee el sensor directamente, sin pasar por el servicio.
#
# ⚠️ Si se agota el plazo NO falla: es mejor arrancar sin acelerómetro (con luz y proximidad, que sí suelen estar)
#    que no arrancar. Queda dicho en el diario.
set -u
PLAZO=${PLAZO:-150}      # segundos como mucho
PASO=${PASO:-3}

t0=$(date +%s)
while :; do
	# ⚠️ Cada comprobación cuesta ~6 s aunque el concentrador YA esté listo: es lo que tarda `ssccli` en dar su
	# primera lectura (descubrir el sensor y abrirlo). Medido el 28-09, con y sin `head -1`. No es el plazo.
	if timeout 6 sh -c 'ssccli --sensor accelerometer 2>/dev/null | head -1' | grep -q "Accelerometer sensor measurement"; then
		echo "sensores del ADSP listos tras $(( $(date +%s) - t0 )) s"
		exit 0
	fi
	if [ $(( $(date +%s) - t0 )) -ge "$PLAZO" ]; then
		echo "AVISO: el acelerómetro del ADSP no contesta tras $PLAZO s; arranco igualmente (sin rotación automática)"
		exit 0
	fi
	sleep "$PASO"
done
