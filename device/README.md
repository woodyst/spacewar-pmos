# Device configuration

The kernel gets the hardware working; these files make the system use it. Everything here is
installed **on the phone**, not built into the image.

`scripts/install-on-device.sh <host>` copies them all over SSH. What each one is:

## `ucm/` — ALSA UCM (audio routing and calls)

Where: `/usr/share/alsa/ucm2/Nothing/spacewar/`

| File | What it does |
|---|---|
| `NP1.conf` | Card definition; points at the two verbs below |
| `HiFi.conf` | Music, stereo (the two TFA9873 amplifiers get their channel through `sound-channel`), earpiece, headset, Bluetooth; capture through the WCD9385's **DEC0** |
| `VoiceCall.conf` | Calls: routing through the DSP's CS-Voice front end, a **call volume that really attenuates**, mute in the DSP (`Voice Tx Capture Switch`) and the per-device voice calibration. ⚠️ Needs the kernel from `kernel/` (r135 or later) |

⚠️ The capture path is the part that cost the most: with the stock routing all microphones went
through **DEC1** and produced an I/O error, and the call's microphone is a *different* ADC from the
one a normal recording uses. The working configuration is DEC0 with the ADC modes set explicitly.

## `wireplumber-llamada/` and part of `bluetooth/` — Bluetooth and call policy

Where: the `.conf` files in `~/.config/wireplumber/wireplumber.conf.d/`, the Lua scripts in
`~/.local/share/wireplumber/scripts/device/` — **except** `suspend-node-spacewar.lua`, which goes in
`~/.local/share/wireplumber/scripts/node/`.

⚠️ Putting the Lua files anywhere else makes **wireplumber refuse to start**.

| File | What it does |
|---|---|
| `bluetooth/54-offload.conf` | Hands SCO to the chip (`bluez5.hw-offload-sco = true` is the one that matters) |
| `56-mantener-voz-bt.conf` + `mantener-voz-bluetooth.lua` | Forces the hands-free profile during a call, from inside wireplumber |
| `find-voice-call-profile.lua` | Finds the call profile for the card |
| `57-suspender-en-llamada.conf` + `suspend-node-spacewar.lua` | Lets idle audio nodes suspend again — keeping them always running cost ~300 mA at idle — **except during a call**, when remounting the internal route used to crash the DSP. It is a full component because only one that declares `requires = [ support.modem-manager ]` actually receives the call notifications |
| `bluetooth/10-greeter-sin-bluetooth.conf` | Keeps the **greeter's** wireplumber from registering the hands-free profile. It would win the race and the first call after boot would find the profile gone |

⚠️ Never mSBC on the Bluetooth link: this chip's SCO rate is fixed at 8 kHz and mSBC gives silence.

## `feedbackd/` — sound and the Glyph LED

| File | Where | Why |
|---|---|---|
| `nothing,spacewar.json` | `/usr/share/feedbackd/themes/` | Device theme, chosen by the device-tree compatible. Adds **sound** to generic notifications (the stock `default.json` gives them none in the `full` profile, so any app that does not send a `category` hint — WhatsApp/greenline, and others — was **silent**), and asks for a white **LED** for missed notifications (the Glyph). With the `leds-aw21018` driver from `kernel/` the theme finds the `white:indicator` LED and the Glyph blinks |

⚠️ feedbackd is a **D-Bus unit**, not a systemd service: `systemctl --user restart feedbackd` fails.
Reload it with `SIGHUP` and D-Bus restarts it.

## `vibracion/` — haptic motor

| File | Where | Why |
|---|---|---|
| `72-vibracion-spacewar.rules` | `/etc/udev/rules.d/` | Marks the `qcom-spmi-haptics` input device as the vibrator for feedbackd (`FEEDBACKD_TYPE=vibra`) with a seat ACL |

## `energia/` — suspend, wakeups and battery

| File | Where | What it does |
|---|---|---|
| `50-despertar-y-sensores` | `/usr/lib/systemd/system-sleep/` | Suspend/resume hook: re-arms the sensors after resume and records the wakeup source |
| `91-bt-uart-sin-despertar.rules` | `/etc/udev/rules.d/` | Stops the Bluetooth UART from aborting every suspend |
| `92-bateria-sin-despertar.rules` + `bateria-sin-despertar.service` | `/etc/udev/rules.d/`, `/etc/systemd/system/` | Stops the PMIC battery notifications from waking the phone ~1×/1 % |
| `sleep-solo-deep.conf` | `/etc/systemd/sleep.conf.d/` | Only `deep` is offered: s2idle was the source of hangs |
| `volver-a-dormir.sh` | `/usr/local/sbin/` | Sends the phone back to sleep 15 s after an automatic wakeup |
| `spacewar-sensores.conf` | `/etc/tmpfiles.d/` | Readable sensor state directories at boot |
| `esperar-sensores-adsp.sh` + `iio-sensor-proxy-esperar.conf` | `/usr/local/sbin/`, unit drop-in | Waits for the ADSP sensors before starting `iio-sensor-proxy`, so the accelerometer is not lost for the whole session |
| `contadores-glink` + `.service` | `/usr/local/sbin/`, `/etc/systemd/system/` | Counts how often each glink client wakes the SoC (diagnostics) |
| `consumo-reposo-muestra.sh`, `info_carga.sh` | `/usr/local/sbin/`, `/usr/local/bin/` | Idle-draw sampling and charger/PD reporting |
| `vigia-microfono.{sh,service,timer}` | `/usr/local/bin/`, user units | Warns when something keeps a microphone stream open, which **aborts suspend** silently |

## `cuelgues/` — hangs, watchdog and logs

| File | Where | What it does |
|---|---|---|
| `perro-vivo.{service,sh}` | `/etc/systemd/system/`, `/usr/local/sbin/` | Hardware watchdog with a **real liveness test**, not just PID 1: on a freeze it lets the Gunyah watchdog bite and reset the phone |
| `watchdog.conf` | `/etc/systemd/system.conf.d/` | Runtime/watchdog limits |
| `aviso-bt-caido.{service,sh}` | user unit, `/usr/local/bin/` | Watches the kernel log and warns when the Bluetooth controller is wedged: **reboot and do not touch Bluetooth** |
| `99-pmsg-escribible.rules` | `/etc/udev/rules.d/` | Makes pstore's `pmsg0` writable by the session, so a warning survives a crash |
| `99-ufs-sin-escalado.rules` | `/etc/udev/rules.d/` | Disables UFS clock scaling (a storage deadlock mitigation) |
| `vigia-ipa.{service,sh}` | `/etc/systemd/system/`, `/usr/local/sbin/` | Detects the IPA/interconnect stall that could deadlock suspend |
| `90-cuelgues.conf`, `90-retencion.conf` | `/etc/sysctl.d/`, `/etc/systemd/journald.conf.d/` | Kernel panic behaviour and persistent journal |

## `eco/` — echo cancellation in calls

See the top-level README. Needs `hexagonrpcd` from [`packages/hexagonrpcd`](../packages/hexagonrpcd)
and the factory voice calibration in `/lib/firmware/qcom/sm7325/nothing/spacewar/`, which is **not**
included. Without the calibration the calls stay in passthrough and work as before.

| File | Where | What it does |
|---|---|---|
| `hexagonrpcd-adsp-audiopd.service` | `/etc/systemd/system/` | Serves the ADSP's **audio PD**, like the vendor's `adsprpcd audiopd`. The canceller is a dynamic module that PD loads over fastrpc |
| `hexagonrpcd-adsp-rootpd.service` + `override-fwdir.conf` | `/etc/systemd/system/`, drop-in | Gives the root PD's daemon `-R`, so it serves the ADSP's libraries |
| `hexagonrpcd-adsp-sensorspd.service` | `/etc/systemd/system/` | Serves the sensors PD |
| `cancelacion-eco.{service}` + `activar-cancelacion-eco.sh` | `/etc/systemd/system/`, `/usr/local/sbin/` | On every boot: registers the vendor topologies in the DSP, loads their modules and, **only if that worked**, sets the kernel parameters. On failure it leaves passthrough and says so |

## `supervisor/` — headset call supervisor

| File | Where | What it does |
|---|---|---|
| `llamada-al-bluetooth.service` + `supervisor-llamada-bt.py` | user unit, `/usr/local/bin/` | Event-driven over D-Bus (ModemManager and PipeWire), no polling: brings the headset side up when a call starts (voice profile, SCO through the device's `bluetoothOffloadActive`), tears it down when you switch to the speaker, rebuilds it on the way back, watches it and notifies. Repairs a broken wireplumber router after a call. Needs `py3-gobject3` |

## `camaras/` — libcamera tuning

Where: `/etc/libcamera/ipa/simple/`

| File | What it does |
|---|---|
| `imx766.yaml`, `s5kjn1.yaml`, `imx471.yaml` | Black level and tuning for the three sensors, so the software ISP produces usable photos |

## The rest

| File | Where | What it does |
|---|---|---|
| `brillo/brillo-persistente.{service,sh}` | `/etc/systemd/system/`, `/usr/local/bin/` | Restores the backlight after boot |
| `firefox/spacewar-prefs.js` | `/usr/lib/firefox/defaults/pref/` | Keeps video playing in the background |
| `kernel-cmdline.d/*.conf` | `/etc/kernel-cmdline.d/` | Boot console (large font, no `quiet`/`splash`) |
| `wifi/cfg80211-pais.conf` | `/etc/modprobe.d/` | Regulatory domain for the Wi-Fi country |
| `waydroid/*` | `/etc/nftables.d/`, `/etc/modules-load.d/` | Network and module setup for Waydroid |

⚠️ Camera load order matters: `qcom_camss` waits for **every** sensor in the device tree, so if one
fails to probe **no camera appears at all**.
