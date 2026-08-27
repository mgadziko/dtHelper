import Foundation

/// The DX100 current-voice response: 93 expanded VCED bytes inside a
/// checksummed 101-byte Yamaha single-voice bulk message.
struct DX100VoiceBaseline {
    let bytes: [UInt8]
    let channel: UInt8

    init?(singleVoiceBulkSysEx message: [UInt8]) {
        guard message.count == 101,
              message[0] == 0xF0,
              message[1] == 0x43,
              (message[2] & 0xF0) == 0x00,
              message[3] == 0x03,
              message[4] == 0x00,
              message[5] == 0x5D,
              message[100] == 0xF7 else { return nil }

        let voiceBytes = Array(message[6..<99])
        let sum = voiceBytes.reduce(0) { ($0 + Int($1)) & 0x7F }
        guard UInt8((128 - sum) & 0x7F) == message[99] else { return nil }
        bytes = voiceBytes
        channel = message[2] & 0x0F
    }

    var name: String {
        String(bytes: bytes[77..<87], encoding: .ascii)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Values represented directly in the DX100's expanded current-voice data.
    /// DT-81z delay/reverb controls are not part of a DX100 voice, so they
    /// deliberately have no stored-value comparison here.
    var values: [String: Int] {
        var result: [String: Int] = [
            "ALGO": Int(bytes[52]), "FB LEVEL": Int(bytes[53]),
            "SPEED": Int(bytes[54]), "DELAY": Int(bytes[55]),
            "PITCH": Int(bytes[56]), "AMP": Int(bytes[57]),
            "SYNC": Int(bytes[58]), "WAVEFORM": Int(bytes[59]),
            "P-MOD SENSE": Int(bytes[60]), "AMP MOD SENSE": Int(bytes[61]),
            // The DT-81z reports the DX100's raw 0...48 transpose value.
            "TRANSPOSE": Int(bytes[62]), "POLY MONO": Int(bytes[63]),
            "P-BEND RANGE": Int(bytes[64]), "PORTA MODE": Int(bytes[65]),
            "PORTA TIME": Int(bytes[66]), "PORTA ON": Int(bytes[69]),
            "CHORUS": Int(bytes[70]),
            "MW PITCH RANGE": Int(bytes[71]), "MW AMP RANGE": Int(bytes[72])
        ]

        // VCED stores operators in DX100 order 4, 2, 3, 1.
        let operatorNumbers = [4, 2, 3, 1]
        for (index, number) in operatorNumbers.enumerated() {
            let start = index * 13
            let prefix = "OP\(number) "
            result[prefix + "ATTACK RATE"] = Int(bytes[start])
            result[prefix + "DECAY1 RATE"] = Int(bytes[start + 1])
            result[prefix + "DECAY2 RATE"] = Int(bytes[start + 2])
            result[prefix + "RELEASE RATE"] = Int(bytes[start + 3])
            result[prefix + "DECAY1 LEVEL"] = Int(bytes[start + 4])
            result[prefix + "LEVEL SCALE"] = Int(bytes[start + 5])
            result[prefix + "RATE SCALE"] = Int(bytes[start + 6])
            result[prefix + "EG BIAS"] = Int(bytes[start + 7])
            result[prefix + "AMP MOD"] = Int(bytes[start + 8])
            result[prefix + "KEY VEL"] = Int(bytes[start + 9])
            result[prefix + "OP LEVEL"] = Int(bytes[start + 10])
            result[prefix + "FREQ"] = Int(bytes[start + 11])
            result[prefix + "DETUNE"] = Int(bytes[start + 12])
        }
        return result
    }

    /// Maps DT-81z parameter names to the corresponding expanded DX100 VCED
    /// byte. Parameters without an entry are not represented in a DX100 .dxv
    /// voice (for example TX81Z effects and operator waveform controls).
    static func vcedByteIndex(for parameter: String) -> Int? {
        let global: [String: Int] = [
            "ALGO": 52, "FB LEVEL": 53, "SPEED": 54, "DELAY": 55,
            "PITCH": 56, "AMP": 57, "SYNC": 58, "WAVEFORM": 59,
            "P-MOD SENSE": 60, "AMP MOD SENSE": 61, "TRANSPOSE": 62,
            "POLY MONO": 63, "P-BEND RANGE": 64, "PORTA MODE": 65,
            "PORTA TIME": 66, "PORTA ON": 69, "CHORUS": 70,
            "MW PITCH RANGE": 71, "MW AMP RANGE": 72
        ]
        if let index = global[parameter] { return index }

        guard parameter.hasPrefix("OP"),
              let separator = parameter.firstIndex(of: " "),
              let number = Int(parameter.dropFirst(2).prefix(upTo: separator)),
              let operatorOrder = [4, 2, 3, 1].firstIndex(of: number) else { return nil }

        let label = String(parameter[parameter.index(after: separator)...])
        let operatorOffset: [String: Int] = [
            "ATTACK RATE": 0, "DECAY1 RATE": 1, "DECAY2 RATE": 2,
            "RELEASE RATE": 3, "DECAY1 LEVEL": 4, "LEVEL SCALE": 5,
            "RATE SCALE": 6, "EG BIAS": 7, "AMP MOD": 8,
            "KEY VEL": 9, "OP LEVEL": 10, "FREQ": 11, "DETUNE": 12
        ]
        guard let offset = operatorOffset[label] else { return nil }
        return operatorOrder * 13 + offset
    }

    static func singleVoiceBulkSysEx(voiceBytes: [UInt8], channel: UInt8) -> [UInt8]? {
        guard voiceBytes.count == 93, voiceBytes.allSatisfy({ $0 <= 0x7F }) else { return nil }
        let sum = voiceBytes.reduce(0) { ($0 + Int($1)) & 0x7F }
        let checksum = UInt8((128 - sum) & 0x7F)
        return [0xF0, 0x43, channel & 0x0F, 0x03, 0x00, 0x5D] + voiceBytes + [checksum, 0xF7]
    }
}
