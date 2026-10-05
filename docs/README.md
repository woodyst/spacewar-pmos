# Documentation

The per-subsystem deep dives are **in Spanish** (`.es.md`): they are the working record kept while
the port was made, and translating them would have meant rewriting them from memory rather than
preserving what was actually measured.

| File | What it covers |
|---|---|
| [`glyph-led.es.md`](glyph-led.es.md) | ★ The **Glyph LED** strips (an Awinic AW21018 on i2c1): why there was no driver, how the board revision was read from the hardware straps, and why the LED is named `white:indicator` |
| [`../device/README.md`](../device/README.md) | Every device file, what it does and where it goes |
| [`../kernel/`](../kernel/) | The patch series, one commit per fix, with a message explaining each one |
| [`../packages/`](../packages/) | The patched packages |

## Added 2026-10-05

| document | what it covers |
|---|---|
| [`glyph-led.es.md`](glyph-led.es.md) | The Glyph LED driver: the AW21018 is only driven by Android kernels; this adds a small mainline driver that exposes the whole white strip as a single `white:indicator` LED, which feedbackd picks up with no extra udev rule |
| [`wakeups-and-battery.es.md`](wakeups-and-battery.es.md) | Why the phone did not sleep, and the wakeup sources that were tamed |

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
- **A callback signature can differ from upstream.** This kernel fork returns `int` from
  `brightness_set_blocking`; the driver is written for the tree it lives in, not for mainline.
- **A build that only fails late is still cheap to fix** if you keep the source tree used to
  generate the patches; regenerating the patch from a reconstructed tree is safer than editing it by
  hand.
