#!/bin/sh
# pruebas/energia/quien-despierta.sh — preguntarle AL KERNEL quién despierta al móvil (2026-09-17)
#
# Desde 2026-10-14 la sonda es permanente: se instala como /usr/local/sbin/despertar-causa.sh y la arma
# despertar-causa.service en cada arranque (scripts/99-ganchos-suspension.sh). Este script es solo un
# atajo para lanzarla desde el ordenador; todo el trabajo está en device/energia/despertar-causa.sh.
#
# POR QUÉ: llevamos días deduciendo la causa desde espacio de usuario y equivocándonos.
#   - «pm_wakeup_irq=ninguna» en 26 de 34 despertares. Pero `pm_system_irq_wakeup()` solo guarda las DOS primeras
#     interrupciones (drivers/base/power/wakeup.c: wakeup_irq[0], wakeup_irq[1], y la tercera la tira), así que
#     «ninguna» puede significar «no hubo» o «se perdió». No se puede distinguir desde fuera.
#   - «fuentes de despertar con eventos: ninguna» en 31 de 34.
#   - «primeros QRTR al volver» salía vacío en 28 de 34 porque el gancho leía a los ~60 ms y el primer paquete no
#     llega hasta +689 ms (arreglado el 17-09, ahora diferido 3 s).
#   En surya el mismo kprobe reordenó toda la investigación: el despertar llegaba 151 µs ANTES de terminar de
#   suspender (irq 158 = el UART del Bluetooth), y se habían pasado días midiendo un móvil que no podía dormir.
#   Ver suria/parches/scripts/cuando-se-arma.sh y suria/parches/energia/README.md.
#
# Uso:  [MOVIL=epo2lan] sh pruebas/energia/quien-despierta.sh armar     (la deja lista; graba el gancho al dormir)
#       [MOVIL=epo2lan] sh pruebas/energia/quien-despierta.sh leer      (qué hubo en el último despertar)
#       [MOVIL=epo2lan] sh pruebas/energia/quien-despierta.sh desarmar
#
# ⚠️ NO usa no_console_suspend ni console_suspend=N: con sesión gráfica matan phosh (README).
set -eu
MOVIL=${MOVIL:-epo2lan}
ORDEN=${1:?armar|leer|desarmar}

ssh -o ConnectTimeout=8 -o BatchMode=yes "$MOVIL" "sudo -n /usr/local/sbin/despertar-causa.sh $ORDEN"
