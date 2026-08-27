import CoreMIDI
import SwiftUI

struct ContentView: View {
    @ObservedObject var monitor: DT81zMonitor
    private let global = ["AMP MOD\nSENSE", "P-MOD\nSENSE", "P-BEND\nRANGE", "MW AMP\nRANGE", "MW PITCH\nRANGE", "FB\nLEVEL", "TRANSPOSE", "PORTA\nTIME"]
    private let algorithm = ["ALGO", "DELAY\nTIME", "PITCH\nSHIFT", "FEEDBACK", "LEVEL"]
    private let pan = ["DIRECTION", "RANGE"]
    private let lfo = ["WAVEFORM", "SPEED", "DELAY", "PITCH", "AMP", "MOD\nSOURCE"]
    private let operatorsA = ["WAVE", "ATTACK\nRATE", "DECAY1\nRATE", "DECAY2\nRATE", "DECAY1\nLEVEL", "RELEASE\nRATE", "EG\nBIAS", "EG\nSHIFT", "KEY\nVEL"]
    private let operatorsB = ["DETUNE", "FIXED\nRANGE", "FIXED\nRANGE", "LEVEL", "LEVEL\nSCALE", "RATE\nSCALE", "FREQ", "FREQ\nRANGE\nFINE", "AMP\nMOD"]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView([.horizontal, .vertical]) {
                panel.padding(30)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .background(LinearGradient(colors: [Color(nsColor: .windowBackgroundColor), Color(nsColor: .underPageBackgroundColor)], startPoint: .top, endPoint: .bottom))
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("dtHelper").font(.title3.weight(.semibold))
                Text("DT-81z read-only monitor").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
                Circle().fill(monitor.lastMessage == "No MIDI received" ? Color.orange : Color.green).frame(width: 8, height: 8)
                Text(monitor.status).font(.caption).foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Routing").font(.caption.weight(.bold))
                    Text("DT-81z input: \(monitor.sources.first(where: { $0.id == monitor.selectedSourceID })?.name ?? "None")").font(.caption)
                    ForEach(monitor.destinations) { destination in
                        Toggle(destination.name, isOn: Binding(get: { monitor.selectedDestinationIDs.contains(destination.id) }, set: { _ in monitor.toggleDestination(destination.id) }))
                            .toggleStyle(.checkbox).font(.caption)
                    }
                    if monitor.destinations.isEmpty { Text("No MIDI destinations available.").font(.caption).foregroundStyle(.secondary) }
                    Text(monitor.dx100VoiceFetchStatus)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    HStack {
                        Button("Refresh MIDI Endpoints") { monitor.refreshSources() }.controlSize(.small)
                        Button("DX PLAY") { monitor.sendDXPlayReset() }.controlSize(.small)
                        Button(monitor.isFetchingDX100Voice ? "Fetching DX Voice…" : "Fetch DX Voice") { monitor.fetchDX100Voice() }
                            .controlSize(.small)
                            .disabled(monitor.isFetchingDX100Voice)
                        Button("Save DX Voice…") { monitor.saveCurrentVoice() }
                            .controlSize(.small)
                            .disabled(!monitor.canSaveVoice)
                    }
                }
                Divider().frame(height: 98)
                Spacer()
                Text(monitor.lastMessage).font(.system(.caption, design: .monospaced)).lineLimit(3).truncationMode(.middle).frame(maxWidth: 330, alignment: .trailing)
            }
            if let capture = monitor.captures.first {
                Text("Last capture: \(capture.control)  [\(capture.bytes)]")
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 22).padding(.vertical, 13)
    }

    private var panel: some View {
        VStack(spacing: 8) {
            HStack { Text("DTRONICS").font(.system(size: 25, weight: .heavy, design: .rounded)); Spacer(); Text("SYNTHESIZER PROGRAMMER").font(.caption.weight(.bold)) }.foregroundStyle(.primary).padding(.horizontal, 18).padding(.top, 14)
            Grid(alignment: .leading, horizontalSpacing: 2, verticalSpacing: 7) {
                GridRow {
                    ForEach(global, id: \.self) { gridControl($0) }
                    gridControl("PORTA\nMODE", toggle: true)
                    gridControl("PORTA\nON", toggle: true)
                }

                GridRow {
                    ForEach(Array(algorithm.enumerated()), id: \.offset) { index, label in gridControl(label, valueKey: index == 4 ? "EFFECT LEVEL" : label) }
                    gridControl(pan[0], toggle: true)
                    gridControl(pan[1])
                    gridControl("REVERB")
                    gridControl("CHORUS", toggle: true)
                    gridControl("POLY\nMONO", toggle: true)
                    gridControl("INIT", toggle: true)
                }

                GridRow {
                    ForEach(lfo, id: \.self) { gridControl($0) }
                    gridControl("SYNC", toggle: true)
                }

                GridRow {
                    ForEach(0..<9, id: \.self) { _ in gridBlank }
                    gridControl("SEL\n1", toggle: true)
                    operatorOnSwitch(1)
                }

                GridRow {
                    ForEach(operatorsA, id: \.self) { gridControl($0) }
                    gridControl("SEL\n2", toggle: true)
                    operatorOnSwitch(2)
                }

                GridRow {
                    ForEach(0..<9, id: \.self) { _ in gridBlank }
                    gridControl("SEL\n3", toggle: true)
                    operatorOnSwitch(3)
                }

                GridRow {
                    ForEach(Array(operatorsB.enumerated()), id: \.offset) { index, label in
                        gridControl(label, toggle: index == 2 || index == 8, valueKey: index == 3 ? "OP LEVEL" : label)
                    }
                    gridControl("SEL\n4", toggle: true)
                    operatorOnSwitch(4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .padding(12)
        .frame(width: 820)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(red: 0.73, green: 0.12, blue: 0.12), lineWidth: 2))
    }

    @ViewBuilder
    private func gridControl(_ label: String, toggle: Bool = false, valueKey: String? = nil) -> some View {
        let key = valueKey ?? label
        if toggle {
            ReadOnlySwitch(label: label, isOn: monitor.displayValue(for: key) == "1", hasChanged: monitor.hasChangedValue(for: key))
        } else {
            ReadOnlyKnob(label: label, value: monitor.displayValue(for: key), maximum: maximum(for: key), hasChanged: monitor.hasChangedValue(for: key))
        }
    }

    private var gridBlank: some View {
        Color.clear.frame(width: 64, height: 102)
    }

    private func maximum(for label: String) -> Int {
        switch label.replacingOccurrences(of: "\n", with: " ") {
        case "AMP MOD SENSE", "WAVEFORM", "MOD SOURCE", "EG SHIFT", "RATE SCALE": return 3
        case "P-MOD SENSE", "FB LEVEL", "FEEDBACK", "EG BIAS", "KEY VEL", "DETUNE", "FIXED RANGE", "WAVE": return 7
        case "P-BEND RANGE", "DECAY1 LEVEL", "RELEASE RATE", "FREQ RANGE FINE": return 15
        case "ALGO": return 8
        case "ATTACK RATE", "DECAY1 RATE", "DECAY2 RATE": return 31
        case "TRANSPOSE", "PITCH SHIFT": return 48
        case "FREQ": return 63
        case "DELAY TIME": return 127
        default: return 99
        }
    }

    private func operatorOnSwitch(_ number: Int) -> some View {
        ReadOnlySwitch(label: "ON/OFF\n\(number)", isOn: monitor.operatorOnMask & (1 << (number - 1)) != 0)
    }
}
