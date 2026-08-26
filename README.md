# dtHelper

`dtHelper` is a native macOS companion app for the DTronics DT-81z hardware
programmer. Its first release is a read-only monitor: it observes the DT-81z's
MIDI output and presents the current observed control values as LCD-style
readouts arranged to match the physical controller.

The goal is to make a DT-81z session legible at a glance without replacing the
hardware workflow. A later release may offer virtual controls and toggles for
working when the hardware is not attached.

## Status

Planning and specification. No application code has been created yet.

## Hardware connection

The connected DT-81z appears to macOS as a bidirectional CoreMIDI endpoint
named `Dtronics DT-81z` over USB-C. The supplied DT-81z Manual v1.2 also
documents USB-to-PC MIDI SysEx transfer for firmware updates. Version 1 listens
to that endpoint; it does not require the DT-81z to be connected through a
Scarlett MIDI port.

## Product specification

The authoritative initial product and technical requirements are in
[SPECIFICATION.md](SPECIFICATION.md).

## Scope boundary

This repository will begin as a monitor, not a MIDI router, patch librarian,
or DX100 editor. Those capabilities can be considered later only when they do
not compromise the monitor's clear, dependable read-only behavior.
