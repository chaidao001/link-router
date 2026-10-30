import AppKit

@main
struct IntegrationSender {
    static func main() {
        guard CommandLine.arguments.count == 2 else { exit(2) }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let destination = URL(fileURLWithPath: CommandLine.arguments[1])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            NSWorkspace.shared.open(
                [URL(string: "https://example.com/#slack-link-router-check")!],
                withApplicationAt: destination, configuration: configuration
            ) { _, error in
                if error != nil { exit(3) }
                // Remain alive while the receiver resolves the sender's bundle ID.
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { app.terminate(nil) }
            }
        }
        app.run()
    }
}
