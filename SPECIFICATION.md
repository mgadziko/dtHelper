# dtHelper — Initial Specification

## 1. Purpose

dtHelper is a macOS app that makes the settings being sent by a DTronics
DT-81z visible. It receives MIDI from the connected DT-81z, decodes the
controller's parameter changes, and shows an LCD-style value display next to
each represented physical control.

The app is a companion to the hardware, not a replacement for it in the first
release. The DT-81z remains the only editable surface.

### Confirmed hardware facts

- The supplied DTronics DT-81Z Manual v1.2 is dated 10 March 2026.
- The unit appears to macOS as a bidirectional USB CoreMIDI endpoint named
  `Dtronics DT-81z`.
- The manual documents sending firmware `.syx` files from a PC to the DT-81z
  over USB, consistent with the observed USB MIDI capability.
- The DT-81z also provides DIN MIDI IN and OUT and a hardware MIDI merger.
- Its MIDI channel is configurable from 1 through 16. The hardware represents
  the channel as a base of 1 plus binary OPERATOR ON/OFF LED values: OP1 = 1,
  OP2 = 2, OP3 = 4, and OP4 = 8.

## 2. Product goals

- Make each observed DT-81z adjustment immediately readable.
- Preserve the controller's physical mental model: the on-screen controls and
  LCDs occupy relative positions corresponding to the DT-81z front panel.
- Clearly distinguish an observed value from a value that has not yet been
  received by the app.
- Work with the DT-81z's native USB CoreMIDI endpoint on macOS.
- Remain reliable and non-invasive: version 1 must not alter, generate, route,
  or suppress MIDI messages.

## 3. Version 1: read-only monitor

### 3.1 MIDI input

- The app lists available CoreMIDI sources and allows the user to select one.
- When present, `Dtronics DT-81z` is shown as the preferred input.
- The app listens to the selected source only.
- The app records no MIDI and sends no MIDI in version 1.
- It must tolerate ordinary MIDI traffic and unknown SysEx messages without
  interrupting monitoring.

### 3.2 State model

- A control value becomes known only after dtHelper receives and successfully
  decodes a corresponding DT-81z MIDI message.
- At launch, and after changing the input source, values are **unknown** rather
  than guessed from the visible position of a hardware pot.
- An unknown LCD displays `---`.
- A known value remains visible until replaced, the source is changed, or the
  user explicitly clears observed state.
- The UI shows the selected MIDI source and a small, non-intrusive indication
  of recent receive activity.
- The UI shows the MIDI channel of each decoded channel-specific message. It
  does not claim to know the DT-81z's configured channel until it has observed
  sufficient matching traffic.

### 3.3 LCD readouts

- Every supported knob has one adjacent LCD-style, read-only display.
- Displays show a parameter-appropriate value rather than an unexplained raw
  MIDI byte where the protocol's units are known.
- Examples include numeric ranges, signed values, named waveforms, and
  `On`/`Off` state, as appropriate.
- During initial development, a parameter may show its validated raw value
  while its final human-readable mapping is still being confirmed. Such a
  display must be visibly identified as raw.

### 3.4 Panel representation

The primary window is a fixed, desktop-friendly visual representation of the
DT-81z panel. It is organized by the same functional regions and relative
placement as the hardware:

1. Global and algorithm controls.
2. Portamento and performance/effect-related controls.
3. LFO controls.
4. Operator controls, including waveform, level, frequency, envelope,
   velocity, and scaling.
5. Operator Select and Operator On/Off status.

The first version favors accurate relative location and rapid scanning over a
pixel-perfect photographic reproduction. It must not imply that any on-screen
knob or switch is interactive.

The Manual v1.2 front-panel image establishes the initial layout inventory:

- Global: AMP MOD SENSE, P-MOD SENSE, P-BEND RANGE, MW AMP RANGE, MW PITCH
  RANGE, FB LEVEL, TRANSPOSE, PORTA TIME, plus PORTA MODE and PORTA ON.
- Second row: ALGORITHM, DELAY, PAN, REVERB, CHORUS, POLY/MONO, and INIT.
- LFO: WAVEFORM, SPEED, DELAY, PITCH, AMP, MOD SOURCE, and SYNC.
- Operator rows: WAVE; the envelope controls; EG BIAS and EG SHIFT; KEY VEL;
  DETUNE; fixed-frequency controls; LEVEL; scaling; frequency; and AMP MOD.
- Right-side bank: Operator Select and Operator On/Off controls for Operators
  1 through 4.

### 3.5 Operator behavior

- The display reflects the DT-81z's four operators.
- Operator selection is shown independently for Operators 1–4.
- Operator enabled/disabled state is shown independently for Operators 1–4.
- Because the hardware can select multiple operators at once, the app supports
  multiple simultaneous selected states.
- When one hardware action applies a parameter to several selected operators,
  each successfully decoded affected operator value is updated.

## 4. Explicitly out of scope for version 1

- Editing a DT-81z or a synth from the app.
- Sending parameter changes, Program Changes, or SysEx.
- Updating DT-81z firmware.
- MIDI thru, routing, or forwarding between the DT-81z and DX100.
- Retrieving or writing DX100/TX81Z patches and banks.
- Saving, recalling, or comparing snapshots.
- Emulating a disconnected DT-81z.

## 5. Future direction (not version 1 requirements)

### 5.1 DX100 session export

- On launch, dtHelper may silently request one current-voice bulk dump from a
  configured DX100 endpoint solely to establish a session baseline.
- After receiving and validating the 101-byte Yamaha single-voice response,
  dtHelper may save the edited session as a Forest-compatible `.dxv` file.
- The file preserves the fetched channel, 93-byte DX100 VCED payload, and a
  recalculated Yamaha checksum.
- Only control messages with a confirmed DX100 VCED-byte mapping update that
  export buffer. TX81Z-only and effect parameters remain outside the file and
  must be reported to the user at save time.

A later interactive mode may make the on-screen knobs and toggles operate as
a virtual DT-81z when the hardware is disconnected. That mode will require a
separate specification covering MIDI output, source-of-truth rules, hardware
reconnection, parameter pickup/takeover behavior, and safeguards against
MIDI feedback loops. It must not change the version 1 monitor behavior.

## 6. Protocol discovery and verification

The DT-81z is observed by macOS as a bidirectional USB CoreMIDI endpoint, and
its Manual v1.2 documents USB MIDI SysEx transfer for firmware updates.
However, the exact mapping from every normal DT-81z control action to its MIDI
bytes must be captured and verified against the connected unit before it is
encoded into the app.

For each panel control, the protocol inventory will record:

- panel label and functional region;
- target parameter and applicable operator(s);
- observed MIDI message bytes;
- decoded raw range and display units;
- confirmed value mapping;
- firmware version used for capture; and
- a sample capture or automated decoding test.

No undocumented mapping is to be represented as confirmed merely because a
similarly named TX81Z/DX100 parameter exists.

## 7. Acceptance criteria for the first usable build

1. With the DT-81z selected as the MIDI source, turning a supported hardware
   knob updates its corresponding LCD quickly and consistently.
2. The updated LCD appears beside the corresponding virtual control in the
   correct functional panel region.
3. A supported multi-operator edit updates every affected operator display.
4. Before an input has been observed, the corresponding display reads `---`.
5. The app sends no MIDI messages while monitoring.
6. Disconnecting or changing the input source leaves the app responsive and
   makes the source/state condition clear to the user.

## 8. Open decisions before implementation

- Exact panel dimensions, visual styling, and LCD typography.
- Whether "clear observed state" is a toolbar action, menu command, or both.
- The complete DT-81z MIDI message map, including firmware differences.
- Whether a later DX100 connection/status indicator belongs in the monitor or
  in a separate routing feature.
