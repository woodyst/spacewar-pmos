# Notices, licences and what is not here

## Licences

| What | Licence |
|---|---|
| `kernel/*.patch` | **GPL-2.0** — derived work of the Linux kernel |
| `packages/libcamera/*.patch` | **LGPL-2.1-or-later** — matching libcamera upstream |
| `packages/hexagonrpcd/*.patch` | **GPL-3.0-or-later** — matching hexagonrpc upstream |
| `packages/modemmanager/*.patch`, `packages/networkmanager/*.patch` | **GPL-2.0-or-later** — matching upstream |
| `packages/callaudiod/*.patch`, `packages/calls/*.patch` | **GPL-3.0-or-later** — matching upstream |
| `packages/phosh/*.patch`, `packages/stevia/*.patch` | **GPL-3.0-or-later / MIT**, as upstream |
| `packages/*/APKBUILD` | **GPL-2.0-or-later**, as the postmarketOS/Alpine aports they extend |
| `device/**`, `scripts/**` | Configuration and glue, same terms as the projects they configure |

## No proprietary firmware is redistributed here

This phone needs binaries that belong to Nothing and Qualcomm to work fully:

- **ACDB** — audio calibration for the DSP, including the **voice calibration** that echo
  cancellation needs.
- **ADSP / modem firmware** — signed by the vendor.
- **Camera sensor configuration** — power sequences, register tables and lane assignment.
- **The factory device tree overlay**, useful as a reference for the camera and Glyph topology.

**None of them are in this repository.** They are on your own device, and postmarketOS does not erase
the partitions that hold them, so you can read them from there.

## Nor is development material

Left out on purpose: audio recordings from the call test bench (they contain voices), Bluetooth
traces (they contain addresses), register dumps and terminal logs from working sessions, and compiled
binaries. None of it is needed to reproduce anything.

## Attribution

The mainline port of this SoC is the work of the
[sc7280-mainline](https://github.com/sc7280-mainline/linux) project (notably Danila Tikhonov and
Eugene Lepshy for the Nothing Phone (1) device tree), and the distribution is
[postmarketOS](https://postmarketos.org). This repository only adds what was missing for daily use.
