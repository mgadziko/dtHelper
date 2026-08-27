import SwiftUI

struct LCDReadout: View {
    var value: String = "---"

    var body: some View {
        SevenSegmentDisplay(text: value)
            .frame(width: 48, height: 24)
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
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.33, green: 0.37, blue: 0.39),
                                Color(red: 0.14, green: 0.16, blue: 0.18),
                            ],
                            center: .topLeading,
                            startRadius: 2,
                            endRadius: 16
                        )
                    )
                Circle().stroke(Color.white.opacity(0.18), lineWidth: 1.2)
                Circle()
                    .trim(from: 0.125, to: 0.875)
                    .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                    .rotationEffect(.degrees(90))
                    .frame(width: 23, height: 23)
                Rectangle()
                    .fill(Color.white.opacity(0.76))
                    .frame(width: 2, height: 9)
                    .offset(y: -5)
                    .rotationEffect(.degrees(indicatorAngle))
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 15, height: 15)
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
        Text(title)
            .font(.headline)
            .foregroundStyle(.blue)
    }
}

private struct SevenSegmentDisplay: View {
    var text: String

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, character in
                SevenSegmentCharacter(character: character)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.03, green: 0.05, blue: 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.green.opacity(0.22), lineWidth: 1)
                )
        )
    }
}

private struct SevenSegmentCharacter: View {
    var character: Character

    var body: some View {
        GeometryReader { proxy in
            let segments = activeSegments(for: character)
            let inactiveColor = Color.green.opacity(0.10)
            let activeColor = Color(red: 0.43, green: 1.0, blue: 0.12)

            ZStack {
                ForEach(SevenSegment.allCases, id: \.self) { segment in
                    segment.path(in: proxy.size)
                        .fill(segments.contains(segment) ? activeColor : inactiveColor)
                        .shadow(color: segments.contains(segment) ? activeColor.opacity(0.45) : .clear, radius: 2)
                }
            }
        }
        .aspectRatio(0.58, contentMode: .fit)
    }

    private func activeSegments(for character: Character) -> Set<SevenSegment> {
        switch character {
        case "0", "O", "o": return [.top, .upperLeft, .upperRight, .lowerLeft, .lowerRight, .bottom]
        case "1", "I", "i": return [.upperRight, .lowerRight]
        case "2": return [.top, .upperRight, .middle, .lowerLeft, .bottom]
        case "3": return [.top, .upperRight, .middle, .lowerRight, .bottom]
        case "4": return [.upperLeft, .upperRight, .middle, .lowerRight]
        case "5", "S", "s": return [.top, .upperLeft, .middle, .lowerRight, .bottom]
        case "6": return [.top, .upperLeft, .middle, .lowerLeft, .lowerRight, .bottom]
        case "7": return [.top, .upperRight, .lowerRight]
        case "8": return Set(SevenSegment.allCases)
        case "9": return [.top, .upperLeft, .upperRight, .middle, .lowerRight, .bottom]
        case "C", "c": return [.top, .upperLeft, .lowerLeft, .bottom]
        case "L", "l": return [.upperLeft, .lowerLeft, .bottom]
        case "R", "r": return [.top, .upperLeft, .upperRight, .middle, .lowerLeft]
        case "F", "f": return [.top, .upperLeft, .middle, .lowerLeft]
        case "E", "e": return [.top, .upperLeft, .middle, .lowerLeft, .bottom]
        case "P", "p": return [.top, .upperLeft, .upperRight, .middle, .lowerLeft]
        case "A", "a": return [.top, .upperLeft, .upperRight, .middle, .lowerLeft, .lowerRight]
        case "-": return [.middle]
        default: return []
        }
    }
}

private enum SevenSegment: CaseIterable {
    case top
    case upperLeft
    case upperRight
    case middle
    case lowerLeft
    case lowerRight
    case bottom

    func path(in size: CGSize) -> Path {
        let thickness = max(min(size.width, size.height) * 0.15, 2)
        let inset = thickness * 0.5
        let x0 = inset
        let x1 = size.width - inset
        let y0 = inset
        let y1 = size.height / 2
        let y2 = size.height - inset

        switch self {
        case .top:
            return horizontalSegment(from: CGPoint(x: x0 + thickness, y: y0), to: CGPoint(x: x1 - thickness, y: y0), thickness: thickness)
        case .middle:
            return horizontalSegment(from: CGPoint(x: x0 + thickness, y: y1), to: CGPoint(x: x1 - thickness, y: y1), thickness: thickness)
        case .bottom:
            return horizontalSegment(from: CGPoint(x: x0 + thickness, y: y2), to: CGPoint(x: x1 - thickness, y: y2), thickness: thickness)
        case .upperLeft:
            return verticalSegment(from: CGPoint(x: x0, y: y0 + thickness), to: CGPoint(x: x0, y: y1 - thickness * 0.5), thickness: thickness)
        case .upperRight:
            return verticalSegment(from: CGPoint(x: x1, y: y0 + thickness), to: CGPoint(x: x1, y: y1 - thickness * 0.5), thickness: thickness)
        case .lowerLeft:
            return verticalSegment(from: CGPoint(x: x0, y: y1 + thickness * 0.5), to: CGPoint(x: x0, y: y2 - thickness), thickness: thickness)
        case .lowerRight:
            return verticalSegment(from: CGPoint(x: x1, y: y1 + thickness * 0.5), to: CGPoint(x: x1, y: y2 - thickness), thickness: thickness)
        }
    }

    private func horizontalSegment(from start: CGPoint, to end: CGPoint, thickness: CGFloat) -> Path {
        var path = Path()
        let half = thickness / 2
        path.move(to: CGPoint(x: start.x - half, y: start.y))
        path.addLine(to: CGPoint(x: start.x, y: start.y - half))
        path.addLine(to: CGPoint(x: end.x, y: end.y - half))
        path.addLine(to: CGPoint(x: end.x + half, y: end.y))
        path.addLine(to: CGPoint(x: end.x, y: end.y + half))
        path.addLine(to: CGPoint(x: start.x, y: start.y + half))
        path.closeSubpath()
        return path
    }

    private func verticalSegment(from start: CGPoint, to end: CGPoint, thickness: CGFloat) -> Path {
        var path = Path()
        let half = thickness / 2
        path.move(to: CGPoint(x: start.x, y: start.y - half))
        path.addLine(to: CGPoint(x: start.x + half, y: start.y))
        path.addLine(to: CGPoint(x: end.x + half, y: end.y))
        path.addLine(to: CGPoint(x: end.x, y: end.y + half))
        path.addLine(to: CGPoint(x: end.x - half, y: end.y))
        path.addLine(to: CGPoint(x: start.x - half, y: start.y))
        path.closeSubpath()
        return path
    }
}
