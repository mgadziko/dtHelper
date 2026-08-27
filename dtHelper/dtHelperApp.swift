import AppKit
import SwiftUI

@main
struct dtHelperApp: App {
    @StateObject private var monitor = DT81zMonitor()
    private let minimumSize = NSSize(width: 1120, height: 700)

    var body: some Scene {
        WindowGroup {
            ContentView(monitor: monitor)
                .frame(minWidth: minimumSize.width, minHeight: minimumSize.height)
        }
        .defaultSize(width: 1240, height: 790)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About dtHelper") { AboutBoxController.shared.show() }
            }
        }
    }
}
