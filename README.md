*[Versión en español](README.es.md)*

# postmarketOS on the Nothing Phone (1) (`nothing,spacewar`, SM7325)

Patches and configuration that turn mainline postmarketOS on the Nothing Phone (1) into a phone
you can actually use: **calls with audio both ways** (earpiece, speaker and Bluetooth headset),
stereo audio, cameras, sensors, GPS, notifications that **ring, buzz and light up the Glyph LEDs**,
and a phone that suspends properly. It also drives the **Glyph LED strips** on the back through a
small mainline driver.

Everything here is built on top of the [sc7280-mainline](https://github.com/sc7280-mainline/linux)
kernel fork and postmarketOS' own packages. Nothing here replaces them — it is an overlay.

> **Read this first:** this is a hobbyist port, not a product. It has rough edges, listed honestly
> in [What does not work](#what-does-not-work). It is also **not verified end to end on a clean
> install yet** — see [Status of these instructions](#status-of-these-instructions).

## What works

| | |
|---|---|
| **Calls** | Outgoing and incoming, **audio both ways**, earpiece ⇄ speaker ⇄ Bluetooth headset switching mid-call, call volume and a mute that works. **Echo cancellation** is implemented but needs the factory voice calibration from your own phone (see below) |
| **Audio** | Stereo speakers with correct L/R (the two TFA9873 amplifiers), earpiece, wired headset, Bluetooth A2DP |
| **Bluetooth** | A2DP music, **calls through a headset** with SCO offloaded to the chip, and moving a call between speaker and headset without it going mute |
| **Mobile data / SMS** | LTE, data and SMS |
| **Cameras** | All three sensors capture (the main IMX766, the ultra-wide and the front one) |
| **Sensors** | Accelerometer and rotation, light, proximity, magnetometer |
| **GPS** | The modem engine, with Galileo and BeiDou reaching applications |
| **Notifications** | Sound, vibration and the **Glyph LED** strips on the back |
| **LED Glyph** | The 18-channel AW21018 that drives the white strips has a driver here; feedbackd uses it as a white notification LED |
| **Haptics** | The LRA vibration motor, driven through the PMIC's haptics block |
| **USB OTG** | Host mode |
| **Battery life** | The phone **suspends properly**: the wakeup sources that kept it awake were tamed (Bluetooth UART, PMIC battery notifications, modem event reports, a VPN keepalive) |
| **Stability** | A hardware watchdog with a real liveness test resets the phone on a freeze, a UFS clock-scaling deadlock is mitigated, and the network/Wi-Fi stack is patched |
| **Waydroid** | Android containers over the mainline kernel |

## What does not work

- **Fingerprint reader.** It is an under-display sensor with a vendor interface mainline does not
  drive.
- **Echo cancellation needs files that are not here.** It works — but the DSP's canceller needs the
  **factory voice calibration**, which is Nothing's and Qualcomm's data and is **not redistributed**.
  Without it the boot service leaves calls in passthrough: they work as before, without cancelling
  echo.
- **Wi-Fi** works but benefits from a calibration variant; expect it to be less than perfect.
- **NFC** is only partly there.
- **Camera image quality is uncalibrated**: the software ISP has no proper tuning for the main
  IMX766, so its photos have colour artifacts. The ultra-wide and front sensors are cleaner.
- **The 90/120 Hz display modes** are not implemented (60 Hz only).

## Requirements

- [`pmbootstrap`](https://wiki.postmarketos.org/wiki/Pmbootstrap) with a `pmaports` checkout.
- A Nothing Phone (1) (`nothing,spacewar`) with an **unlocked bootloader**.

## Building an image

The kernel package here is an overlay on postmarketOS'. Copy it over the aport, then build as usual:

```sh
git clone https://github.com/woodyst/spacewar-pmos
cd spacewar-pmos

# 1. Kernel: 52 patches, the recipe and the config
PMAPORTS=$(pmbootstrap config aports)
cp kernel/*.patch kernel/APKBUILD kernel/config-* \
   "$PMAPORTS/device/community/linux-postmarketos-qcom-sc7280/"

# 2. The patched packages (calls, libcamera, ModemManager, NetworkManager, phosh, …).
#    Each packages/<name>/ has its APKBUILD and patches; copy them over the aport of
#    the same name under temp/ (or device/community/ where it exists) — see each
#    package's APKBUILD for what it extends.

# 3. Checksums and build
pmbootstrap checksum linux-postmarketos-qcom-sc7280 <the packages you copied>
pmbootstrap shutdown          # see the pitfall below
pmbootstrap install
```

⚠️ **`pmbootstrap checksum` leaves its chroot mounted**, and the next build then fails with
*"Failed to umount … /mnt/pmbootstrap/packages"*. Run `pmbootstrap shutdown` in between.

⚠️ **If a package will not rebuild**, bump its `pkgrel`: pmbootstrap reports "up to date" and skips
it otherwise.

⚠️ The kernel `pkgrel` here is high on purpose, so an official update of the same `pkgver` does not
replace it silently.

## Flashing it onto the phone

Nothing's bootloader accepts a mainline `boot.img` **only if `vendor_boot` and `dtbo` are gone** —
this is the one thing the postmarketOS wiki does not say, and without it the bootloader answers
`Load Error` or boots to the logo and stops. You do **not** need to install any version of Android
first: the boot firmware and the DSP/modem images stay in their partitions.

With the phone in the bootloader (**Volume Down + Power** from a powered-off state):

```sh
# erase the stock overlays and the vendor boot image, or the ABL refuses the kernel
fastboot -w
fastboot erase dtbo
fastboot erase vendor_boot

# the image built earlier
pmbootstrap flasher flash_kernel
pmbootstrap flasher flash_rootfs
fastboot reboot
```

Modes: **bootloader** = Volume Down + Power · **recovery** = Volume Up + Power ·
**EDL** = Volume Up + Volume Down + Power.

The first boot takes a minute; the phone then appears over USB at `172.16.42.1` (postmarketOS'
default). ⚠️ Note that `fastboot -w` may fail to format `userdata` with the `mke2fs` of some
`android-sdk` packages; erasing `userdata` and `metadata` explicitly does the same job.

## Installing the device configuration

The kernel alone is not enough: audio routing, the call daemons, notifications and the power
tweaks live in userspace. See [`device/README.md`](device/README.md) for what each file is and
where it goes, or run the helper:

```sh
scripts/install-on-device.sh <hostname-or-ip>
```

Then reboot, so everything comes up in the right order.

## What is deliberately **not** here

No proprietary firmware. Running this phone needs blobs from its own factory partitions — audio
calibration (ACDB and the **voice calibration** the echo canceller needs), DSP and modem firmware,
camera sensor configuration, the factory device tree. They belong to Nothing and Qualcomm, not to
this project, and **they are not redistributed here**. They are already on your device, and
postmarketOS does not erase the partitions that hold them, so they can be read from there.

Also excluded: audio recordings, Bluetooth traces and register dumps from the development sessions.
They carry voices, addresses and identifiers, and none of it is needed to reproduce anything.

## Status of these instructions

Honest disclosure: this overlay is **known to work**, because the phone it was developed on runs it,
and the kernel series is verified to apply cleanly and compile. But **the whole recipe has never
been run start to finish on a clean postmarketOS install**. If you try it, expect gaps, and please
report them.

## Licences

The kernel patches are derived work of the Linux kernel and are **GPL-2.0**. The other package
patches keep the licence of the project they patch (libcamera **LGPL-2.1-or-later**, ModemManager
and NetworkManager **GPL-2.0-or-later**, hexagonrpcd **GPL-3.0-or-later**, and so on). Configuration
files and scripts are published under the same terms as the projects they extend. See
[`NOTICE.md`](NOTICE.md).

## Documentation

- [`docs/`](docs/) — per-subsystem notes: what was wrong, how it was found, and the traps.
- [`kernel/`](kernel/) — the patch series, one commit per fix, plus the recipe and the config.
- [`packages/`](packages/) — the patched packages (calls, callaudiod, libcamera, hexagonrpcd,
  ModemManager, NetworkManager, phosh, stevia, flare, iio-sensor-proxy, mobile-broadband-provider-info).
- [`device/`](device/) — the device configuration, and [`device/README.md`](device/README.md) for
  what each file is and where it goes.
- [Spanish version of this file](README.es.md).
