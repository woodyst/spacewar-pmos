#!/bin/sh
# Copy the device configuration onto a running postmarketOS install.
#
#   ./install-on-device.sh <hostname-or-ip>
#
# It only writes configuration; it never touches the kernel or the packages,
# which come from the image built with pmbootstrap (see the top-level README).
set -eu

HOST=${1:?usage: install-on-device.sh <hostname-or-ip>}
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

say() { printf '\n== %s\n' "$*"; }
S()   { ssh "$HOST" "$@"; }

# A file for the system: <repo path> <destination> <mode>
inst() {
  scp -q "$HERE/$1" "$HOST":/tmp/sw-inst
  S "sudo install -Dm$3 /tmp/sw-inst '$2'"
}
# A file for the user's session: <repo path> <path relative to $HOME> <mode>
instu() {
  scp -q "$HERE/$1" "$HOST":/tmp/sw-inst
  S "install -Dm$3 /tmp/sw-inst \"\$HOME/$2\""
}

# The configuration below assumes the kernel built from kernel/ (r135 or later).
REL=$(S uname -r)
R=${REL##*.r}
case "$R" in ''|*[!0-9]*) echo "cannot read the kernel release ($REL)"; exit 1 ;; esac
[ "$R" -ge 135 ] || { echo "kernel $REL: this configuration needs r135 or later (kernel/)"; exit 1; }

say "ALSA UCM (audio routing and calls)"
S 'sudo mkdir -p /usr/share/alsa/ucm2/Nothing/spacewar'
inst device/ucm/Nothing/spacewar/NP1.conf       /usr/share/alsa/ucm2/Nothing/spacewar/NP1.conf       644
inst device/ucm/Nothing/spacewar/HiFi.conf      /usr/share/alsa/ucm2/Nothing/spacewar/HiFi.conf      644
inst device/ucm/Nothing/spacewar/VoiceCall.conf /usr/share/alsa/ucm2/Nothing/spacewar/VoiceCall.conf 644

say "wireplumber (audio routing, Bluetooth calls)"
S 'mkdir -p ~/.config/wireplumber/wireplumber.conf.d \
           ~/.local/share/wireplumber/scripts/device \
           ~/.local/share/wireplumber/scripts/node'
instu device/bluetooth/54-offload.conf                     .config/wireplumber/wireplumber.conf.d/54-offload.conf                     644
instu device/wireplumber-llamada/56-mantener-voz-bt.conf   .config/wireplumber/wireplumber.conf.d/56-mantener-voz-bt.conf             644
instu device/wireplumber-llamada/57-suspender-en-llamada.conf .config/wireplumber/wireplumber.conf.d/57-suspender-en-llamada.conf       644
# The Lua files MUST live in these two directories: anywhere else and wireplumber refuses to start.
instu device/wireplumber-llamada/find-voice-call-profile.lua   .local/share/wireplumber/scripts/device/find-voice-call-profile.lua   644
instu device/wireplumber-llamada/mantener-voz-bluetooth.lua    .local/share/wireplumber/scripts/device/mantener-voz-bluetooth.lua    644
instu device/wireplumber-llamada/suspend-node-spacewar.lua     .local/share/wireplumber/scripts/node/suspend-node-spacewar.lua       644
# The greeter must not register the hands-free profile: it would win the race and the
# first call after boot would find the profile gone.
inst device/bluetooth/10-greeter-sin-bluetooth.conf /var/lib/greetd/.config/wireplumber/wireplumber.conf.d/10-greeter-sin-bluetooth.conf 644

say "kernel module options"
inst device/bluetooth/hci_uart-offload.conf /etc/modprobe.d/hci_uart-offload.conf 644
inst device/wifi/cfg80211-pais.conf         /etc/modprobe.d/cfg80211-pais.conf     644

say "udev (vibration motor, wakeup sources, pstore)"
for f in device/vibracion/72-vibracion-spacewar.rules \
         device/energia/91-bt-uart-sin-despertar.rules \
         device/energia/92-bateria-sin-despertar.rules \
         device/cuelgues/99-pmsg-escribible.rules \
         device/cuelgues/99-ufs-sin-escalado.rules; do
  inst "$f" "/etc/udev/rules.d/$(basename "$f")" 644
done
S 'sudo udevadm control --reload-rules'

say "feedbackd theme (notifications: sound, glyph LED)"
# feedbackd picks the theme by the device-tree compatible ("nothing,spacewar").
# It searches XDG_DATA_DIRS in order, so a copy under /usr/local/share would take
# precedence over this one and survive package upgrades; /usr/share is where the
# working install puts it and where it is tested.
inst device/feedbackd/nothing,spacewar.json /usr/share/feedbackd/themes/nothing,spacewar.json 644

say "systemd system units and helpers"
inst device/bluetooth/btmon-arranque.service          /etc/systemd/system/btmon-arranque.service          644
inst device/brillo/brillo-persistente.service         /etc/systemd/system/brillo-persistente.service      644
inst device/cuelgues/perro-vivo.service               /etc/systemd/system/perro-vivo.service              644
inst device/cuelgues/vigia-ipa.service                /etc/systemd/system/vigia-ipa.service               644
inst device/cuelgues/watchdog.conf                    /etc/systemd/system.conf.d/watchdog.conf            644
inst device/energia/bateria-sin-despertar.service     /etc/systemd/system/bateria-sin-despertar.service   644
inst device/energia/contadores-glink.service          /etc/systemd/system/contadores-glink.service        644
inst device/energia/sleep-solo-deep.conf              /etc/systemd/sleep.conf.d/sleep-solo-deep.conf      644
inst device/energia/spacewar-sensores.conf            /etc/tmpfiles.d/spacewar-sensores.conf              644
inst device/energia/iio-sensor-proxy-esperar.conf     /etc/systemd/system/iio-sensor-proxy.service.d/esperar.conf 644
inst device/energia/50-despertar-y-sensores           /usr/lib/systemd/system-sleep/50-despertar-y-sensores 755
inst device/cuelgues/90-cuelgues.conf                 /etc/sysctl.d/90-cuelgues.conf                      644
inst device/cuelgues/90-retencion.conf                /etc/systemd/journald.conf.d/90-retencion.conf      644
inst device/waydroid/60_waydroid.nft                  /etc/nftables.d/60_waydroid.nft                     644
inst device/waydroid/waydroid-modules.conf            /etc/modules-load.d/waydroid.conf                   644
inst device/firefox/spacewar-prefs.js                 /usr/lib/firefox/defaults/pref/spacewar-prefs.js    644
for f in device/kernel-cmdline.d/*.conf; do
  inst "$f" "/etc/kernel-cmdline.d/$(basename "$f")" 644
done
inst device/camaras/libcamera/imx471.yaml  /etc/libcamera/ipa/simple/imx471.yaml  644
inst device/camaras/libcamera/imx766.yaml  /etc/libcamera/ipa/simple/imx766.yaml  644
inst device/camaras/libcamera/s5kjn1.yaml  /etc/libcamera/ipa/simple/s5kjn1.yaml  644

say "helpers (system)"
inst device/brillo/brillo-persistente.sh        /usr/local/bin/brillo-persistente.sh        755
inst device/bluetooth/hfp-registrado.sh         /usr/local/bin/hfp-registrado.sh            755
inst device/cuelgues/aviso-bt-caido.sh          /usr/local/bin/aviso-bt-caido.sh            755
inst device/cuelgues/perro-vivo.sh              /usr/local/sbin/perro-vivo.sh               755
inst device/cuelgues/vigia-ipa.sh               /usr/local/sbin/vigia-ipa.sh                755
inst device/energia/esperar-sensores-adsp.sh    /usr/local/sbin/esperar-sensores-adsp.sh    755
inst device/energia/volver-a-dormir.sh          /usr/local/sbin/volver-a-dormir.sh          755
inst device/energia/contadores-glink            /usr/local/sbin/contadores-glink            755
inst device/energia/consumo-reposo-muestra.sh   /usr/local/sbin/consumo-reposo-muestra.sh   755
inst device/energia/info_carga.sh               /usr/local/bin/info_carga.sh                755
inst device/energia/vigia-microfono.sh          /usr/local/bin/vigia-microfono.sh           755
inst device/supervisor/supervisor-llamada-bt.py /usr/local/bin/supervisor-llamada-bt.py     755

say "echo cancellation (needs the factory voice calibration, not included)"
inst device/eco/hexagonrpcd-adsp-audiopd.service /etc/systemd/system/hexagonrpcd-adsp-audiopd.service 644
inst device/eco/hexagonrpcd-adsp-rootpd.service  /etc/systemd/system/hexagonrpcd-adsp-rootpd.service  644
inst device/eco/hexagonrpcd-adsp-sensorspd.service /etc/systemd/system/hexagonrpcd-adsp-sensorspd.service 644
inst device/eco/cancelacion-eco.service          /etc/systemd/system/cancelacion-eco.service          644
inst device/eco/override-fwdir.conf              /etc/systemd/system/hexagonrpcd-adsp-rootpd.service.d/override-fwdir.conf 644
inst device/eco/activar-cancelacion-eco.sh       /usr/local/sbin/activar-cancelacion-eco.sh           755

say "user units (call supervisor, headset HFP watcher, Bluetooth watchdog, mic watchdog)"
instu device/supervisor/llamada-al-bluetooth.service     .config/systemd/user/llamada-al-bluetooth.service 644
instu device/bluetooth/hfp-registrado.service            .config/systemd/user/hfp-registrado.service       644
instu device/cuelgues/aviso-bt-caido.service             .config/systemd/user/aviso-bt-caido.service       644
instu device/energia/vigia-microfono.service             .config/systemd/user/vigia-microfono.service      644
instu device/energia/vigia-microfono.timer               .config/systemd/user/vigia-microfono.timer        644

say "enabling services"
S 'set -e
  sudo systemctl daemon-reload
  sudo systemctl enable btmon-arranque brillo-persistente perro-vivo vigia-ipa \
                       bateria-sin-despertar contadores-glink cancelacion-eco \
                       hexagonrpcd-adsp-audiopd
  systemctl --user daemon-reload
  systemctl --user enable llamada-al-bluetooth hfp-registrado aviso-bt-caido \
                          vigia-microfono.timer'

say "Done. Reboot the phone so everything comes up in the right order."
