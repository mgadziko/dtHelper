import AppKit
import SwiftUI

final class AboutBoxController {
    static let shared = AboutBoxController()
    private var panel: NSPanel?

    func show() {
        if let panel {
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 520, height: 286), styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.center()
        panel.contentView = NSHostingView(rootView: AboutBoxView())
        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct AboutBoxView: View {
    private var versionText: String {
        "Version: " + (Bundle.main.object(forInfoDictionaryKey: "DTBuildTimestamp") as? String ?? "Development")
    }
    var body: some View {
        ZStack {
            VisualEffectBackground()
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 20) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 96, height: 96)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("dtHelper")
                            .font(.title2.weight(.semibold))
                            .padding(.bottom, 6)
                        Text(versionText)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 18)
                        Text("A visual monitor for the DTronics DT-81z hardware programmer.")
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom, 18)
                        Text("©2026 Mark Gadzikowski. All Rights Reserved Worldwide.")
                            .fontWeight(.semibold)
                        Text("Contact: dthelper@quantumpenguin.com")
                            .padding(.top, 16)
                    }
                    Spacer(minLength: 0)
                }
                Spacer()
                HStack { Spacer(); Button("OK") { NSApp.keyWindow?.close() }.keyboardShortcut(.defaultAction).frame(width: 210); Spacer() }
            }
            .padding(24)
        }
        .frame(width: 520, height: 286)
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
