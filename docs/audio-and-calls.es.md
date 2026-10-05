# Audio y llamadas

El audio de este teléfono va, como en el POCO X3, **del DSP al códec por SoundWire** y de ahí a los
amplificadores; la CPU no toca la voz. La cadena la completa mainline con los parches de este repo.

## La cadena

| Pieza | Qué es |
|---|---|
| Tarjeta | `qcom,sm7325-sndcard` (+ `qcom,sm8250-sndcard`), PCMs MultiMedia1/2/3, I2S a los TFA9873, WCD playback/capture y el frontal de voz CS-Voice |
| Códec | **WCD9385** por SWR0/SWR1 (rx/tx/va en `okay`) |
| Amplificadores | **dos TFA9873** por `PRI_MI2S_RX`, uno por canal (estéreo) |
| DSP | q6afe/q6asm/q6adm por **APR**, más la pila de voz q6voice/cvp/cvs/mvm |

Lo que traía el kernel de pmaports eran **dos** dai-links (I2S y MultiMedia1) y 20 controles de
mezclador: el códec, las SoundWire y los macros LPASS estaban `disabled`. Los parches `0001` (orden de
los PCM y la cadena completa), `0007` (canal y prefijo de cada TFA9873) y `0008`-`0013` (voz) lo montan.

## Estéreo

Los dos TFA9873 leen `sound-channel` y `sound-name-prefix` del device tree; sin eso, el driver pone
los dos en el canal 0 y **solo suena el altavoz de arriba**. El parche `0007` les da cada canal:
izquierda arriba, derecha abajo.

## Llamadas

- El **frontal de voz** es `CS-Voice` (`hw:0,3`). El PCM señuelo (`MultiMedia1`) es lo que hace que
  PipeWire aplique el perfil «Voice Call»: sin un sumidero al que apuntar, **el enrutado no se
  ejecuta**.
- ⚠️ **Carrera de arranque de q6voiced**: abre el PCM 3 ms después de `active`, antes de que PipeWire
  cambie de perfil; sin ruta de captura el kernel responde `EINVAL` («Failed to open tx»). Por eso
  las rutas `PRI_MI2S_RX Voice Mixer CS-Voice` y `CS-Voice Capture Mixer TX_CODEC_DMA_TX_3` van
  **siempre encendidas**.
- **Volumen de llamada**: los dos registros de ganancia del TFA9873 (AMPGAIN, TDMSPKG) **casi no
  mueven el nivel** (medido: −4,4 dB en 90 pasos, y el otro ±0,5 dB). El volumen útil es la ganancia
  del **módulo de volumen del DSP** (`Voice Rx Playback Volume`, 0‑6; el kernel manda el paso con
  `SET_PARAM_V2`). El UCM se lo da a PipeWire.
- **Silencio del micro**: `Voice Tx Capture Switch` (mute del DSP). PipeWire solo lo arma por
  hardware si el UCM declara `CaptureMixerElem "Voice Tx"`; el `ctl-remap` del paquete lo impedía.
- **Auricular vs manos libres**: los controles `Earpiece/Speaker Output Switch` del driver TFA9873
  apagan un amplificador u otro.

## Micrófonos

- ⛔ Con el UCM del paquete **todos los micros iban por DEC1** y `arecord` daba I/O error; por
  **DEC0** (como el Fairphone 5, mismo SoC y códec) graban. Corregido en `HiFi.conf`/`VoiceCall.conf`.
- En este teléfono los micros son **analógicos del WCD9385**: **AMIC1** (abajo, para auricular) y
  **AMIC3** (arriba, para manos libres). Los digitales de fábrica no dan audio con mainline.
- ⚠️ Los `ADCn Switch` se leen solo en `hw_params`; van siempre encendidos para que q6voiced los pille
  al abrir antes que el perfil.

## Cancelación de eco

El cancelador (SMECNS V2) es un **módulo dinámico que carga el PD de audio del ADSP** por fastrpc:
sin `hexagonrpcd` sirviendo ese PD y sin la **calibración de voz de fábrica** (que no se
redistribuye), la topología no se registra y las llamadas quedan en paso directo. Con todo, el eco
bajó ~21 dB en picos. La calibración de **auricular** de fábrica es para las topologías propias de
Nothing, que no se corren: se usa la de **manos libres en los dos modos**.

## Trazas y trampas

- ⛔ **Nunca** poner los dos teléfonos en manos libres: se acoplan y hacen mucho ruido. El teléfono de
  pruebas (surya) va conectado al Bluetooth de la máquina de desarrollo.
- Diagnóstico de volumen y silencio: `scripts/diag-volumen-silencio.sh` (kprobes: ¿llega el cambio al
  DSP?). El volumen y el silencio en llamada **no se mueven con tonos puros** para medir el eco: la
  supresión de ruido del vocproc los trata como ruido; se usa voz grabada.
