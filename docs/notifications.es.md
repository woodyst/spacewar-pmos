# Avisos: sonido, vibración y LED Glyph

Tres cosas distintas, y las tres tenían su propio fallo.

## Por qué «a veces» no sonaban

phosh traduce cada aviso a un evento de feedbackd **según su `category`**: `im.received` →
`message-new-instant`, `email.arrived` → `message-new-email`, `x-phosh.sms.received` →
`message-new-sms`… y **sin `category` → `notification-new-generic`**. El tema que usaba el teléfono
era el `default.json` (no había tema para `nothing,spacewar`) y **no tiene `notification-new-generic`
en el perfil `full`** → esos avisos salían **mudos** (ni sonido, ni vibración, ni LED). Los emisores
que no mandan `category` (varios clientes de WhatsApp) caían justo ahí; los que sí la mandan sonaban.

Además, dos detalles más de phosh: el hint `suppress-sound` pasa al perfil `quiet` (solo vibración),
y `maybe_trigger_feedback()` solo lanza feedback del **primer aviso de cada tanda**.

**Arreglo**: `device/feedbackd/nothing,spacewar.json`, un *device theme* que feedbackd elige solo por
el compatible del device tree (`nothing,spacewar`). Hereda del `default.json` y añade
`notification-new-generic` (sonido `message-new-instant`) al perfil `full`, con los «perdidos» en LED
blanco.

⚠️ feedbackd es una **unidad de D-Bus** (`dbus-:1.2-org.sigxcpu.Feedback@N.service`), no un servicio
systemd: `systemctl --user restart feedbackd` **falla**. Se recarga con **SIGHUP** y, si se cae,
D-Bus lo reactiva.

## Vibración

El motor es un LRA (~170 Hz) movido por el bloque de haptics del **PM8350B**. Mainline no tenía
driver: el kernel lleva la serie v7 de Fenglin Wu `qcom-spmi-haptics` (`0041`, sin fusionar) y el
nodo del DT (`0042`). Dos cosas hubo que arreglar:

- feedbackd pedía `FF_RUMBLE` y el núcleo lo emulaba con un seno de un tercio de la magnitud; el
  parche `0043` hace que el driver trate `FF_RUMBLE` a plena escala y anuncie `FF_RUMBLE` y `FF_SINE`.
- El dispositivo se marca `FEEDBACKD_TYPE=vibra` con ACL de sesión desde `device/vibracion/`.
