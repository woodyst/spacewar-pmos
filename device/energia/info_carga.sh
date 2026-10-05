#!/bin/sh
# info_carga.sh — batería, carga y consumo de spacewar (Nothing Phone 1), como el info_carga.sh de surya (2026-09-14)
#
# En spacewar la carga la lleva el firmware del ADSP (pmic_glink): qcom-battmgr y ucsi solo INFORMAN de lo que decide.
# No hay current_avg; sí contador de carga (charge_counter, µAh que quedan), OCV, resistencia interna, ciclos y salud.
#
# Uso: info_carga.sh            foto instantánea
#      info_carga.sh SEGUNDOS   además mide el consumo medio durante SEGUNDOS (corriente leída cada segundo y
#                               diferencia del contador de carga). ⚠️ Por SSH el móvil no se suspende: es consumo
#                               DESPIERTO.
export LC_ALL=C
CAP_NOM_MAH=4500

BAT=/sys/class/power_supply/qcom-battmgr-bat
USB=/sys/class/power_supply/qcom-battmgr-usb
WLS=/sys/class/power_supply/qcom-battmgr-wls
UCSI=$(ls -d /sys/class/power_supply/ucsi-source-psy-* 2>/dev/null | head -1)
TC=/sys/class/typec/port0
THERM=/sys/class/thermal

r() { v=$(cat "$1" 2>/dev/null) && [ -n "$v" ] && echo "$v" || echo 0; }
s() { cat "$1" 2>/dev/null || echo "-"; }
active() { s "$1" | grep -o '\[[^]]*\]' | tr -d '[]'; }
# calc FORMATO EXPRESIÓN (awk: sin bc, con decimales de verdad)
calc() { awk "BEGIN { printf \"$1\", $2 }"; }
thermtemp() {
	for z in "$THERM"/thermal_zone*; do
		if [ "$(s "$z/type")" = "$1" ]; then
			t=$(cat "$z/temp" 2>/dev/null) && { calc "%.1f" "$t / 1000"; return; }
		fi
	done
	echo "?"
}
si_no() { [ "$1" = "1" ] && echo "Sí" || echo "No"; }

case "${1:-}" in
	"") SEG= ;;
	*[!0-9]*|0) echo "uso: $0 [segundos]"; exit 2 ;;
	*) SEG=$1 ;;
esac

bat_pct=$(r $BAT/capacity)
bat_status=$(s $BAT/status)
bat_health=$(s $BAT/health)
bat_soh=$(s $BAT/state_of_health)
bat_ciclos=$(s $BAT/cycle_count)
bat_uv=$(r $BAT/voltage_now)
bat_ocv=$(r $BAT/voltage_ocv)
bat_vmax=$(r $BAT/voltage_max)
bat_ua=$(r $BAT/current_now)
bat_res=$(r $BAT/internal_resistance)
bat_uah=$(r $BAT/charge_counter)
bat_temp=$(calc "%.1f" "$(r $BAT/temp) / 10")
t_vacia=$(r $BAT/time_to_empty_avg)
t_llena=$(r $BAT/time_to_full_avg)

usb_online=$(r $USB/online)
usb_tipo=$(active $USB/usb_type)
usb_uv=$(r $USB/voltage_now)
usb_ua=$(r $USB/current_now)
usb_lim=$(r $USB/input_current_limit)
usb_max=$(r $USB/current_max)
wls_online=$(r $WLS/online)

echo "╔══════════════════════════════════════╗"
echo "║         ESTADO DE CARGA              ║"
echo "╠══════════════════════════════════════╣"
printf "║  Batería:    %s%%  (%s mAh en el contador, %s nominales)  -  %s\n" "$bat_pct" "$((bat_uah / 1000))" "$CAP_NOM_MAH" "$bat_status"
printf "║  Salud:      %s   (%s %%, %s ciclos)   Temp: %s°C\n" "$bat_health" "$bat_soh" "$bat_ciclos" "$bat_temp"
# current_now: negativo = descarga, positivo = carga
printf "║  Corriente:  %s mA   Potencia: %s W\n" "$(calc "%.0f" "$bat_ua / 1000")" "$(calc "%.2f" "$bat_uv / 1e6 * $bat_ua / 1e6")"
if [ "$bat_ua" -lt 0 ] 2>/dev/null && [ "$t_vacia" -gt 0 ] 2>/dev/null; then
	printf "║  → Vacía en ~%s h (estimación del firmware)\n" "$(calc "%.1f" "$t_vacia / 3600")"
elif [ "$t_llena" -gt 0 ] 2>/dev/null; then
	printf "║  → Llena en ~%s h (estimación del firmware)\n" "$(calc "%.1f" "$t_llena / 3600")"
fi

if [ -n "$SEG" ]; then
	echo "╠══════════════════════════════════════╣"
	printf "║  CONSUMO MEDIO (%s s, midiendo...)\n" "$SEG"
	c0=$bat_uah; t0=$(date +%s); suma=0; i=0
	while [ $i -lt "$SEG" ]; do
		sleep 1
		suma=$((suma + $(r $BAT/current_now))); i=$((i + 1))
	done
	c1=$(r $BAT/charge_counter); t1=$(date +%s)
	media=$(calc "%.0f" "$suma / $SEG / 1000")
	printf "║  Corriente media:     %s mA  (%s lecturas)\n" "$media" "$SEG"
	if [ "$c1" != "$c0" ] && [ "$t1" -gt "$t0" ]; then
		dc=$(calc "%.0f" "($c1 - $c0) / 1000 * 3600 / ($t1 - $t0)")
		printf "║  Contador de carga:   %s mA  (%s mAh en %s s)\n" "$dc" "$(calc "%.1f" "($c1 - $c0) / 1000")" "$((t1 - t0))"
	else
		printf "║  Contador de carga:   sin cambio en %s s (poca resolución: medir más tiempo)\n" "$((t1 - t0))"
	fi
	m=${media#-}
	if [ "$media" -lt 0 ] 2>/dev/null && [ "$m" -gt 5 ] 2>/dev/null; then
		printf "║  → Quedan ~%s h a este ritmo\n" "$(calc "%.1f" "$c1 / 1000 / $m")"
	fi
fi

echo "╠══════════════════════════════════════╣"
echo "║  MEDIDOR (qcom-battmgr, firmware del ADSP)"
printf "║  V terminal: %s V    OCV: %s V    Máx: %s V\n" \
	"$(calc "%.3f" "$bat_uv / 1e6")" "$(calc "%.3f" "$bat_ocv / 1e6")" "$(calc "%.2f" "$bat_vmax / 1e6")"
printf "║  V - OCV: %s mV (+ cargando, - descargando)   Resistencia interna: %s mΩ\n" \
	"$(calc "%+.0f" "($bat_uv - $bat_ocv) / 1000")" "$(calc "%.0f" "$bat_res / 1000")"
printf "║  Modelo:     %s\n" "$(s $BAT/model_name)"
echo "╠══════════════════════════════════════╣"
echo "║  CARGADOR (qcom-battmgr-usb / -wls)"
printf "║  USB conectado:  %s   Tipo: %s\n" "$(si_no "$usb_online")" "$usb_tipo"
printf "║  V / I entrada:  %s V  /  %s A   → %s W\n" \
	"$(calc "%.2f" "$usb_uv / 1e6")" "$(calc "%.2f" "$usb_ua / 1e6")" "$(calc "%.1f" "$usb_uv / 1e6 * $usb_ua / 1e6")"
printf "║  Límite entrada: %s A   Corriente máx: %s A\n" "$(calc "%.2f" "$usb_lim / 1e6")" "$(calc "%.2f" "$usb_max / 1e6")"
printf "║  Inalámbrica:    %s\n" "$(si_no "$wls_online")"
echo "╠══════════════════════════════════════╣"
echo "║  USB-C / POWER DELIVERY (ucsi)"
printf "║  Modo:       %s   Rol: %s / %s\n" "$(s $TC/power_operation_mode)" "$(s $TC/power_role | grep -o '\[[^]]*\]' | tr -d '[]')" "$(s $TC/data_role | grep -o '\[[^]]*\]' | tr -d '[]')"
if [ -n "$UCSI" ] && [ "$(r "$UCSI/online")" = "1" ]; then
	# ucsi_glink no da la tensión (sale 0): current_now es la corriente del contrato PD; la tensión se toma de la
	# entrada medida por qcom-battmgr-usb
	u_ua=$(r "$UCSI/current_now")
	printf "║  Contrato:   %s A a ~%s V   → hasta %s W   (tipo %s)\n" \
		"$(calc "%.2f" "$u_ua / 1e6")" "$(calc "%.1f" "$usb_uv / 1e6")" "$(calc "%.1f" "$usb_uv / 1e6 * $u_ua / 1e6")" "$(active "$UCSI/usb_type")"
fi
P=/sys/class/typec/port0-partner
if [ -d "$P" ]; then
	printf "║  Cargador:   PD %s\n" "$(s $P/usb_power_delivery/revision)"
	ls -d "$P"/usb_power_delivery/source-capabilities/* >/dev/null 2>&1 \
		|| echo "║    (sus capacidades no las publica ucsi_glink)"
	for c in "$P"/usb_power_delivery/source-capabilities/*; do
		[ -d "$c" ] || continue
		n=${c##*/}
		if [ -r "$c/voltage" ]; then
			printf "║    %-22s %s V  %s A\n" "$n" "$(calc "%.1f" "$(r "$c/voltage") / 1000")" "$(calc "%.2f" "$(r "$c/maximum_current") / 1000")"
		elif [ -r "$c/maximum_voltage" ]; then
			printf "║    %-22s %s-%s V  %s A\n" "$n" "$(calc "%.1f" "$(r "$c/minimum_voltage") / 1000")" \
				"$(calc "%.1f" "$(r "$c/maximum_voltage") / 1000")" "$(calc "%.2f" "$(r "$c/maximum_current") / 1000")"
		fi
	done
else
	echo "║  Cargador:   sin pareja USB-C (desenchufado, o cable/puerto sin PD)"
fi
echo "╠══════════════════════════════════════╣"
echo "║  TÉRMICA"
printf "║  PMIC pm8350b (cargador): %s°C   pm7325: %s°C   pm8350c: %s°C\n" \
	"$(thermtemp pm8350b-thermal)" "$(thermtemp pm7325-thermal)" "$(thermtemp pm8350c-thermal)"
printf "║  Batería: %s°C   CPU: %s°C\n" "$bat_temp" "$(thermtemp cpu0-thermal)"
echo "╚══════════════════════════════════════╝"
echo
echo "Nota: la carga (y USB-PD) la negocia el firmware del ADSP con el PM8350B; Linux (qcom-battmgr, ucsi) solo"
echo "informa. «Default USB» con 5 V = el cargador solo ofrece USB por defecto (típico de cable USB-A a C)."
echo
echo "Nota: la corriente del medidor aún NO está contrastada con un medidor USB externo. En surya el suyo informaba"
echo "2,24 veces menos de lo real; aquí se muestra tal cual. power_now del firmware no se usa: da valores absurdos."
