import SwiftUI

struct LCDReadout: View {
    var value: String = "---"

    var body: some View {
        Text(value)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(Color(red: 0.48, green: 1, blue: 0.16))
            .frame(width: 48, height: 24)
            .background(RoundedRectangle(cornerRadius: 2).fill(Color(red: 0.015, green: 0.035, blue: 0.02)))
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.green.opacity(0.25), lineWidth: 0.7))
    }
}

struct ReadOnlyKnob: View {
    var label: String
    var value: String = "---"
    var maximum: Int = 99
    var hasChanged = false

    var body: some View {
        VStack(spacing: 3) {
            LCDReadout(value: value)
            ZStack {
                Circle().fill(LinearGradient(colors: [Color(white: 0.32), Color(white: 0.06)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle().stroke(Color.white.opacity(0.18), lineWidth: 1)
                Capsule().fill(Color.white.opacity(0.85)).frame(width: 2, height: 9).offset(y: -9).rotationEffect(.degrees(indicatorAngle))
            }
            .frame(width: 25, height: 25)
            Text(displayLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(hasChanged ? Color.orange : .primary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 64, height: 28, alignment: .top)
        }
        .frame(width: 64)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), read-only, value \(value)")
    }

    private var indicatorAngle: Double {
        guard let numericValue = Int(value), maximum > 0 else { return -135 }
        return -135 + (Double(min(max(numericValue, 0), maximum)) / Double(maximum)) * 270
    }

    private var displayLabel: String {
        label.contains("\n") ? label : label.split(separator: " ").count == 2 ? label.replacingOccurrences(of: " ", with: "\n") : label
    }
}

struct ReadOnlySwitch: View {
    var label: String
    var isOn: Bool = false
    var hasChanged = false

    var body: some View {
        VStack(spacing: 5) {
            LCDReadout(value: isOn ? "ON" : "---")
            RoundedRectangle(cornerRadius: 3)
                .fill(isOn ? Color(red: 0.25, green: 0.9, blue: 0.32) : Color(white: 0.45))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.white.opacity(0.18), lineWidth: 1))
                .frame(width: 30, height: 17)
            Text(displayLabel).font(.caption2.weight(.semibold)).foregroundStyle(hasChanged ? Color.orange : .primary).multilineTextAlignment(.center).lineLimit(nil).fixedSize(horizontal: false, vertical: true).frame(width: 64, height: 28, alignment: .top)
        }
        .frame(width: 64)
    }

    private var displayLabel: String {
        label.contains("\n") ? label : label.split(separator: " ").count == 2 ? label.replacingOccurrences(of: " ", with: "\n") : label
    }
}

struct PanelHeading: View {
    var title: String
    var body: some View {
        Text(title).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 2).background(Color(red: 0.73, green: 0.12, blue: 0.12))
    }
}
