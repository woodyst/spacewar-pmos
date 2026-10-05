# Documentation

The per-subsystem deep dives are **in Spanish** (`.es.md`): they are the working record kept while
the port was made, and translating them would have meant rewriting them from memory rather than
preserving what was actually measured. They are worth reading even through a translator, because
they record *how* each thing was found, and the traps that cost the most time.

| File | What it covers |
|---|---|
| [`audio-and-calls.es.md`](audio-and-calls.es.md) | The audio chain (WCD9385 + two TFA9873), the UCM, the DSP call path, call volume, mute, microphones and echo cancellation |
| [`bluetooth.es.md`](bluetooth.es.md) | Bluetooth calls: SCO over SLIMBus, the WCN6750 that would not appear on the bus, and the headset call supervisor |
| [`notifications.es.md`](notifications.es.md) | Why generic notifications were silent, the feedbackd theme, and the vibration motor |
| [`glyph-led.es.md`](glyph-led.es.md) | ★ The Glyph LED strips (an Awinic AW21018): the new mainline driver, the board revision, and why the LED is named `white:indicator` |
| [`cameras.es.md`](cameras.es.md) | The three sensors (IMX766, S5KJN1, IMX471), C-PHY, Bayer order, autofocus and the software ISP |
| [`wireplumber.es.md`](wireplumber.es.md) | ★ Every call can leave the phone **mute**: the wireplumber router breaks on a profile change with an active sink, and the repair |
| [`sensors.es.md`](sensors.es.md) | The ADSP sensor hub, iio-sensor-proxy and why phosh lost rotation |
| [`stability.es.md`](stability.es.md) | Hangs, the Gunyah watchdog, the UFS deadlock, the IPA suspend hang and the `console_suspend` trap |
| [`wakeups-and-battery.es.md`](wakeups-and-battery.es.md) | Why the phone did not sleep, and the wakeup sources that were tamed |
| [`wifi-modem.es.md`](wifi-modem.es.md) | Wi-Fi and its calibration, mobile data, and the ModemManager/NetworkManager patches |
| [`deploy.es.md`](deploy.es.md) | How the kernel and the device configuration are built, flashed (A/B) and verified |
| [`pending.es.md`](pending.es.md) | What is still open, and where to start on each |
| [`../device/README.md`](../device/README.md) | Every device file, what it does and where it goes |
| [`../kernel/`](../kernel/) | The patch series, one commit per fix, with a message explaining each one |

## Lessons that generalise beyond this phone

A few of these cost days, and none of them are specific to a Nothing Phone (1):

- **Not every notification carries a `category`.** phosh turns a notification into a feedbackd event
  *by its `category`*, and falls back to `notification-new-generic` for apps that send none — and the
  stock theme gives that event **no feedback at all**. Apps that omit it (several WhatsApp clients
  among them) are silently mute. Check the theme before blaming the speakers.
- **An LED driver's *name* is an interface.** feedbackd discovers notification LEDs through a udev
  rule matching `*:indicator`, reads the colour from the name, and only then asks for the `pattern`
  attribute. Naming the LED `white:indicator` made the whole thing work with no custom udev rule.
- **Read the hardware straps, don't guess.** The AW21018 has two current tables selected by board
  revision; the straps were readable in `debugfs`, which settled it instead of trying both.
- **A profile change with an active sink can break the router.** The wireplumber failure only shows
  when the sink is RUNNING; the log message appears in every profile change and proves nothing on its
  own.
- **A zero proves nothing without a positive control**, and **the absence of an error is not
  success**: check the precondition actually ran.
- **Measuring can be the bug.** The call probe itself delayed the SCO bring-up by 6.8 s and made the
  call mute.
- **A callback signature can differ from upstream.** This kernel fork returns `int` from
  `brightness_set_blocking`; the driver is written for the tree it lives in, not for mainline.
