# dtHelper

`dtHelper` is a native macOS companion app for the DTronics DT-81z hardware
programmer. It observes the DT-81z's MIDI output, routes it to selected MIDI
destinations when requested, and presents current control values as LCD-style
readouts arranged to match the physical controller.

The goal is to make a DT-81z session legible at a glance without replacing the
hardware workflow. A later release may offer virtual controls and toggles for
working when the hardware is not attached.

## Status

The panel decodes the captured DT-81z map, animates the virtual knobs, and can
silently fetch the current DX100 voice as a session baseline. After a valid
DX100 fetch, **Save DX Voice…** writes a Forest-compatible `.dxv` file.

The save uses the fetched 93-byte DX100 voice buffer, preserves its channel,
and recalculates the Yamaha checksum. It incorporates only DT-81z messages
with an exact DX100 voice-buffer mapping. TX81Z-only/effect changes are named
in the save status rather than silently written into an incompatible voice.

## Hardware connection

The connected DT-81z appears to macOS as a bidirectional CoreMIDI endpoint
named `Dtronics DT-81z` over USB-C. The supplied DT-81z Manual v1.2 also
documents USB-to-PC MIDI SysEx transfer for firmware updates. Version 1 listens
to that endpoint; it does not require the DT-81z to be connected through a
DIN-style MIDI port.

## Product specification

The authoritative initial product and technical requirements are in
[SPECIFICATION.md](SPECIFICATION.md).

## Scope boundary

dtHelper is not a patch librarian or a replacement DX100 editor. It saves the
current DT-81z session as a portable `.dxv` file for Forest Editor to open and
manage.
