import CoreMIDI
import Foundation
import AppKit
import UniformTypeIdentifiers

struct DT81zSource: Identifiable, Hashable {
    let id: MIDIUniqueID
    let name: String
}
struct DT81zDestination: Identifiable, Hashable { let id: MIDIUniqueID; let name: String }

struct MappingCapture: Identifiable {
    let id = UUID()
    let control: String
    let bytes: String
    let time: Date
}

@MainActor
final class DT81zMonitor: ObservableObject {
    @Published private(set) var sources: [DT81zSource] = []
    @Published private(set) var destinations: [DT81zDestination] = []
    @Published private(set) var selectedDestinationIDs: Set<MIDIUniqueID> = []
    @Published var selectedSourceID: MIDIUniqueID? { didSet { connectSelectedSource() } }
    @Published var selectedControl = "AMP MOD SENSE"
    @Published var isCaptureArmed = false
    @Published private(set) var lastMessage = "No MIDI received"
    @Published private(set) var captures: [MappingCapture] = []
    @Published private(set) var status = "Starting CoreMIDI listener..."
    @Published private(set) var values: [String: Int] = [:]
    @Published private(set) var operatorOnMask = 0
    @Published private(set) var hasSessionVoiceBaseline = false
    @Published private(set) var canSaveVoice = false
    @Published private(set) var isFetchingDX100Voice = false
    @Published private(set) var dx100VoiceFetchStatus = "No DX100 voice fetched."

    let controls = [
        "AMP MOD SENSE", "P-MOD SENSE", "P-BEND RANGE", "MW AMP RANGE", "MW PITCH RANGE", "FB LEVEL", "TRANSPOSE", "PORTA TIME", "PORTA MODE", "PORTA ON",
        "ALGO", "DELAY TIME", "PITCH SHIFT", "FEEDBACK", "LEVEL", "DIRECTION", "RANGE", "REVERB", "CHORUS", "POLY MONO", "INIT",
        "WAVEFORM", "SPEED", "DELAY", "PITCH", "AMP", "MOD SOURCE", "SYNC",
        "WAVE", "ATTACK RATE", "DECAY1 RATE", "DECAY2 RATE", "DECAY1 LEVEL", "RELEASE RATE", "EG BIAS", "EG SHIFT", "KEY VEL",
        "DETUNE", "FIXED RANGE (knob)", "FIXED RANGE (toggle)", "LEVEL SCALE", "RATE SCALE", "FREQ", "FREQ RANGE MODE", "AMP MOD",
        "OPERATOR 1 SEL", "OPERATOR 1 ON/OFF", "OPERATOR 2 SEL", "OPERATOR 2 ON/OFF", "OPERATOR 3 SEL", "OPERATOR 3 ON/OFF", "OPERATOR 4 SEL", "OPERATOR 4 ON/OFF"
    ]

    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var outputPort = MIDIPortRef()
    private var connectedSource: MIDIEndpointRef = 0
    private var baselineSources: [MIDIEndpointRef] = []
    private var endpointByID: [MIDIUniqueID: MIDIEndpointRef] = [:]
    private var destinationByID: [MIDIUniqueID: MIDIEndpointRef] = [:]
    private var baselineRequestPending = false
    private var baselineRequestID: UUID?
    private var incomingSysExBytes: [UInt8] = []
    private var baselineValues: [String: Int] = [:]
    private var lastOperatorKeyForLabel: [String: String] = [:]
    private var currentVoiceBytes: [UInt8]?
    private var currentVoiceChannel: UInt8 = 0
    private var currentVoiceName = "Untitled DX100 Voice"
    private var unmappedVoiceParameters: Set<String> = []

    init() {
        MIDIClientCreateWithBlock("dtHelper CoreMIDI Client" as CFString, &client) { [weak self] _ in
            Task { @MainActor in self?.refreshSources() }
        }
        MIDIInputPortCreateWithBlock(client, "dtHelper Read-Only Input" as CFString, &inputPort) { [weak self] packetList, _ in
            let packets = Self.packetBytes(from: packetList)
            Task { @MainActor in packets.forEach { self?.receivedPacket($0) } }
        }
        MIDIOutputPortCreate(client, "dtHelper Thru Output" as CFString, &outputPort)
        refreshSources()
    }

    deinit {
        let primarySource = connectedSource
        let responseSources = baselineSources
        if primarySource != 0 { MIDIPortDisconnectSource(inputPort, primarySource) }
        for responseSource in responseSources where responseSource != primarySource {
            MIDIPortDisconnectSource(inputPort, responseSource)
        }
        MIDIPortDispose(inputPort)
        MIDIPortDispose(outputPort)
        MIDIClientDispose(client)
    }

    func refreshSources() {
        endpointByID.removeAll()
        sources = (0..<MIDIGetNumberOfSources()).compactMap { index in
            let endpoint = MIDIGetSource(index)
            guard endpoint != 0 else { return nil }
            var id: Int32 = 0
            MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &id)
            var unmanaged: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &unmanaged)
            let name = unmanaged?.takeRetainedValue() as String? ?? "Unnamed MIDI Source"
            endpointByID[id] = endpoint
            return DT81zSource(id: id, name: name)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        if selectedSourceID == nil || endpointByID[selectedSourceID ?? 0] == nil {
            selectedSourceID = sources.first(where: { $0.name.localizedCaseInsensitiveContains("Dtronics DT-81z") })?.id ?? sources.first?.id
        } else {
            connectSelectedSource()
        }
        status = selectedSourceID == nil ? "No CoreMIDI source available." : "Listening read-only."
        refreshDestinations()
        connectBaselineSources()
        requestInitialVoiceBaseline()
    }

    func toggleDestination(_ id: MIDIUniqueID) {
        if selectedDestinationIDs.contains(id) { selectedDestinationIDs.remove(id) } else { selectedDestinationIDs.insert(id) }
    }
    func sendDXPlayReset() {
        forward([0xF0, 0x43, 0x10, 0x00, 0x1B, 0x7F, 0xF7])
        status = "Sent DX PLAY reset to selected destination(s)."
    }

    private func refreshDestinations() {
        destinationByID.removeAll()
        destinations = (0..<MIDIGetNumberOfDestinations()).compactMap { index in
            let endpoint = MIDIGetDestination(index); guard endpoint != 0 else { return nil }
            var id: Int32 = 0; MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &id)
            var unmanaged: Unmanaged<CFString>?; MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &unmanaged)
            destinationByID[id] = endpoint
            return DT81zDestination(id: id, name: unmanaged?.takeRetainedValue() as String? ?? "Unnamed MIDI Destination")
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func requestInitialVoiceBaseline() {
        guard !baselineRequestPending, !hasSessionVoiceBaseline else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.fetchDX100Voice()
        }
    }

    func fetchDX100Voice() {
        guard !isFetchingDX100Voice else { return }
        refreshDestinations()
        connectBaselineSources()
        guard let destination = preferredDX100Destination(), let endpoint = destinationByID[destination.id] else {
            dx100VoiceFetchStatus = "No DX100 output endpoint found."
            status = "Select the DX100/Scarlett destination, then Fetch DX Voice."
            return
        }

        let requestID = UUID()
        baselineRequestID = requestID
        baselineRequestPending = true
        isFetchingDX100Voice = true
        dx100VoiceFetchStatus = "Requesting from \(destination.name)…"
        status = "Requesting DX100 current voice."
        send([0xF0, 0x43, 0x20, 0x03, 0xF7], to: endpoint)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, self.baselineRequestID == requestID, self.baselineRequestPending else { return }
            self.baselineRequestPending = false
            self.isFetchingDX100Voice = false
            self.dx100VoiceFetchStatus = "No valid reply from \(destination.name)."
            self.status = "DX100 voice fetch timed out. Check MIDI settings, then select the DX100's current voice on its front panel and retry."
        }
    }

    func armCapture() { isCaptureArmed = true; status = "Move (selectedControl) on the DT-81z." }
    func clearCaptures() { captures.removeAll(); lastMessage = "No MIDI received" }

    private func connectSelectedSource() {
        if connectedSource != 0 { MIDIPortDisconnectSource(inputPort, connectedSource); connectedSource = 0 }
        guard let id = selectedSourceID, let endpoint = endpointByID[id] else { return }
        guard MIDIPortConnectSource(inputPort, endpoint, nil) == noErr else { status = "Could not connect selected source."; return }
        connectedSource = endpoint
    }

    private func connectBaselineSources() {
        for source in baselineSources where source != connectedSource {
            MIDIPortDisconnectSource(inputPort, source)
        }
        baselineSources.removeAll()
        let matchingSources = sources.filter { isLikelyDX100Endpoint($0.name) }
        for source in matchingSources {
            guard let endpoint = endpointByID[source.id], endpoint != connectedSource else { continue }
            guard MIDIPortConnectSource(inputPort, endpoint, nil) == noErr else {
                status = "Could not listen for the DX100 voice reply."
                continue
            }
            baselineSources.append(endpoint)
        }
        if matchingSources.isEmpty {
            status = "Could not listen for the DX100 voice reply."
        }
    }

    private func preferredDX100Destination() -> DT81zDestination? {
        let selected = destinations.filter { selectedDestinationIDs.contains($0.id) }
        return selected.first(where: { isLikelyDX100Endpoint($0.name) })
            ?? destinations.first(where: { isLikelyDX100Endpoint($0.name) })
            ?? (selected.count == 1 ? selected.first : nil)
            ?? (destinations.count == 1 ? destinations.first : nil)
    }

    private func isLikelyDX100Endpoint(_ name: String) -> Bool {
        let normalized = name.lowercased()
        return normalized.contains("dx100")
            || normalized.contains("scarlett 2i4 usb (2)")
            || (normalized.contains("scarlett") && normalized.contains("(2)"))
    }

    private func receivedPacket(_ bytes: [UInt8]) {
        for message in extractSysExMessages(from: bytes) {
            received(message)
        }
    }

    private func extractSysExMessages(from bytes: [UInt8]) -> [[UInt8]] {
        var messages: [[UInt8]] = []
        for byte in bytes {
            if byte == 0xF0 {
                incomingSysExBytes = [byte]
            } else if !incomingSysExBytes.isEmpty {
                incomingSysExBytes.append(byte)
                if byte == 0xF7 {
                    messages.append(incomingSysExBytes)
                    incomingSysExBytes.removeAll(keepingCapacity: true)
                }
            }
        }
        return messages
    }

    private func received(_ bytes: [UInt8]) {
        guard !bytes.isEmpty else { return }
        if baselineRequestPending, let baseline = DX100VoiceBaseline(singleVoiceBulkSysEx: bytes) {
            baselineValues = baseline.values
            currentVoiceBytes = baseline.bytes
            currentVoiceChannel = baseline.channel
            currentVoiceName = baseline.name.isEmpty ? "Untitled DX100 Voice" : baseline.name
            unmappedVoiceParameters.removeAll()
            loadBaselineValuesIntoLEDs()
            hasSessionVoiceBaseline = true
            canSaveVoice = true
            baselineRequestPending = false
            isFetchingDX100Voice = false
            let voiceName = baseline.name.isEmpty ? "Untitled voice" : baseline.name
            lastMessage = "DX100 baseline: \(voiceName)"
            status = "DX100 session voice baseline received."
            dx100VoiceFetchStatus = "Fetched \(voiceName)."
            return
        }
        let hex = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        let decoded = decodedDescription(bytes)
        lastMessage = decoded ?? hex
        if let decoded, let name = decoded.split(separator: ":", maxSplits: 1).first {
            let key = String(name)
            values[key] = Int(bytes[bytes.count - 2])
            if key == "OPERATOR ON/OFF" { operatorOnMask = Int(bytes[bytes.count - 2]) }
            if key.hasPrefix("OP") , let label = key.split(separator: " ", maxSplits: 1).last {
                values[String(label)] = Int(bytes[bytes.count - 2])
                lastOperatorKeyForLabel[String(label)] = key
            }
            updateStoredVoiceBuffer(parameter: key, value: Int(bytes[bytes.count - 2]))
        }
        status = "Received (bytes.count) byte\(bytes.count == 1 ? "" : "s")."
        if isCaptureArmed {
            captures.insert(MappingCapture(control: selectedControl, bytes: hex, time: .now), at: 0)
            isCaptureArmed = false
            status = "Captured (selectedControl). Choose the next control."
        }
        forward(bytes)
    }

    private func forward(_ bytes: [UInt8]) {
        for id in selectedDestinationIDs {
            guard let destination = destinationByID[id] else { continue }
            let size = MemoryLayout<MIDIPacketList>.size + bytes.count + 32
            let raw = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: MemoryLayout<MIDIPacketList>.alignment)
            defer { raw.deallocate() }
            let list = raw.assumingMemoryBound(to: MIDIPacketList.self)
            let packet = MIDIPacketListInit(list)
            _ = MIDIPacketListAdd(list, size, packet, 0, bytes.count, bytes)
            MIDISend(outputPort, destination, list)
        }
    }

    private func send(_ bytes: [UInt8], to destination: MIDIEndpointRef) {
        let size = MemoryLayout<MIDIPacketList>.size + bytes.count + 32
        let raw = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: MemoryLayout<MIDIPacketList>.alignment)
        defer { raw.deallocate() }
        let list = raw.assumingMemoryBound(to: MIDIPacketList.self)
        let packet = MIDIPacketListInit(list)
        _ = MIDIPacketListAdd(list, size, packet, 0, bytes.count, bytes)
        MIDISend(outputPort, destination, list)
    }

    func displayValue(for label: String) -> String {
        let key = label.replacingOccurrences(of: "\n", with: " ")
        return values[key].map(String.init) ?? "---"
    }

    func hasChangedValue(for label: String) -> Bool {
        let key = label.replacingOccurrences(of: "\n", with: " ")
        guard let currentValue = values[key] else { return false }
        let baselineKey = lastOperatorKeyForLabel[key] ?? key
        guard let storedValue = baselineValues[baselineKey] else { return false }
        return currentValue != storedValue
    }

    func saveCurrentVoice() {
        guard let voiceBytes = currentVoiceBytes,
              let message = DX100VoiceBaseline.singleVoiceBulkSysEx(voiceBytes: voiceBytes, channel: currentVoiceChannel) else {
            status = "Fetch a DX100 current voice before saving."
            return
        }

        let panel = NSSavePanel()
        panel.title = "Save DX100 Voice"
        panel.message = "Creates a Forest-compatible DX100 .dxv voice file."
        panel.allowedContentTypes = [UTType(filenameExtension: "dxv")!]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(safeFileName(currentVoiceName)).dxv"

        guard panel.runModal() == .OK, var url = panel.url else { return }
        if url.pathExtension.lowercased() != "dxv" { url.appendPathExtension("dxv") }
        do {
            try Data(message).write(to: url, options: .atomic)
            if unmappedVoiceParameters.isEmpty {
                status = "Saved Forest-compatible DX100 voice: \(url.lastPathComponent)"
            } else {
                status = "Saved \(url.lastPathComponent). Not stored: \(unmappedVoiceParameters.sorted().joined(separator: ", "))."
            }
        } catch {
            status = "Could not save DX100 voice: \(error.localizedDescription)"
        }
    }

    /// The DT-81z has one physical set of operator LEDs. Its SEL buttons do
    /// not send a message, so a fetched voice begins by showing Operator 1.
    /// Once the DT-81z reports a parameter from another operator, `received`
    /// changes that shared display to the operator that was actually touched.
    private func loadBaselineValuesIntoLEDs() {
        values = baselineValues.filter { !$0.key.hasPrefix("OP") }
        lastOperatorKeyForLabel.removeAll()

        for (operatorKey, value) in baselineValues where operatorKey.hasPrefix("OP1 ") {
            let label = String(operatorKey.dropFirst(4))
            values[label] = value
            lastOperatorKeyForLabel[label] = operatorKey
        }
    }

    private func updateStoredVoiceBuffer(parameter: String, value: Int) {
        guard hasSessionVoiceBaseline else { return }
        guard let index = DX100VoiceBaseline.vcedByteIndex(for: parameter),
              (0...127).contains(value), var voiceBytes = currentVoiceBytes else {
            unmappedVoiceParameters.insert(parameter)
            return
        }
        voiceBytes[index] = UInt8(value)
        currentVoiceBytes = voiceBytes
    }

    private func safeFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\")
        let cleaned = name.components(separatedBy: invalid).joined(separator: "-")
        return cleaned.isEmpty ? "Untitled DX100 Voice" : cleaned
    }

    private func decodedDescription(_ bytes: [UInt8]) -> String? {
        guard bytes.count >= 7, bytes[0] == 0xF0, bytes[1] == 0x43, bytes[2] == 0x10, bytes.last == 0xF7 else { return nil }
        let parameter: String?
        if let operatorParameter = operatorParameter(group: bytes[3], address: bytes[4]), bytes.count == 7 {
            parameter = operatorParameter
        } else if bytes[3] == 0x12, bytes.count == 7 {
            parameter = [0x3D:"AMP MOD SENSE",0x3C:"P-MOD SENSE",0x40:"P-BEND RANGE",0x48:"MW AMP RANGE",0x47:"MW PITCH RANGE",0x35:"FB LEVEL",0x3E:"TRANSPOSE",0x42:"PORTA TIME",0x41:"PORTA MODE",0x45:"PORTA ON",0x34:"ALGO",0x46:"CHORUS",0x3F:"POLY MONO",0x3B:"WAVEFORM",0x36:"SPEED",0x37:"DELAY",0x38:"PITCH",0x39:"AMP",0x3A:"SYNC",0x27:"ATTACK RATE",0x28:"DECAY1 RATE",0x29:"DECAY2 RATE",0x2B:"DECAY1 LEVEL",0x2A:"RELEASE RATE",0x2E:"EG BIAS",0x30:"KEY VEL",0x33:"DETUNE",0x10:"FIXED RANGE",0x31:"LEVEL",0x2C:"LEVEL SCALE",0x2D:"RATE SCALE",0x32:"FREQ",0x08:"AMP MOD",0x5D:"OPERATOR ON/OFF"][bytes[4]]
        } else if bytes[3] == 0x13, bytes.count == 7 {
            parameter = [0x12:"WAVE",0x13:"EG SHIFT",0x00:"FIXED RANGE",0x10:"FIXED RANGE",0x11:"FREQ RANGE FINE",0x14:"REVERB"][bytes[4]]
        } else if bytes[3] == 0x10, bytes.count == 8, bytes[4] == 0x7C {
            parameter = [0:"DELAY TIME",1:"PITCH SHIFT",2:"FEEDBACK",3:"EFFECT LEVEL",4:"DIRECTION",5:"MOD SOURCE",6:"RANGE"][bytes[5]]
        } else { parameter = nil }
        guard let parameter else { return nil }
        return "\(parameter): \(bytes[bytes.count - 2])  [\(bytes.map { String(format: "%02X", $0) }.joined(separator: " "))]"
    }

    private func operatorParameter(group: UInt8, address: UInt8) -> String? {
        let group12: [(String, [UInt8])] = [
            ("ATTACK RATE", [0x27,0x0D,0x1A,0x00]), ("DECAY1 RATE", [0x28,0x0E,0x1B,0x01]),
            ("DECAY2 RATE", [0x29,0x0F,0x1C,0x02]), ("DECAY1 LEVEL", [0x2B,0x11,0x1E,0x04]),
            ("RELEASE RATE", [0x2A,0x10,0x1D,0x03]), ("EG BIAS", [0x2E,0x14,0x21,0x07]),
            ("KEY VEL", [0x30,0x16,0x23,0x09]), ("DETUNE", [0x33,0x19,0x26,0x0C]),
            ("OP LEVEL", [0x31,0x17,0x24,0x0A]), ("LEVEL SCALE", [0x2C,0x12,0x1F,0x05]),
            ("RATE SCALE", [0x2D,0x13,0x20,0x06]), ("FREQ", [0x32,0x18,0x25,0x0B]),
            ("AMP MOD", [0x2F,0x15,0x22,0x08])]
        let group13: [(String, [UInt8])] = [
            ("WAVE", [0x12,0x08,0x0D,0x03]), ("EG SHIFT", [0x13,0x09,0x0E,0x04]),
            ("FIXED RANGE", [0x10,0x06,0x0B,0x01]), ("FIXED RANGE", [0x0F,0x05,0x0A,0x00]),
            ("FREQ RANGE FINE", [0x11,0x07,0x0C,0x02])]
        let table = group == 0x12 ? group12 : group == 0x13 ? group13 : []
        for (label, addresses) in table {
            if let index = addresses.firstIndex(of: address) { return "OP\(index + 1) \(label)" }
        }
        return nil
    }

    private static func packetBytes(from packetList: UnsafePointer<MIDIPacketList>) -> [[UInt8]] {
        var result: [[UInt8]] = []
        var packet = packetList.pointee.packet
        for _ in 0..<packetList.pointee.numPackets {
            result.append(withUnsafeBytes(of: packet.data) { Array($0.prefix(Int(packet.length))) })
            packet = MIDIPacketNext(&packet).pointee
        }
        return result
    }
}
