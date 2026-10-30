import AppKit

// Identify installed copies by their known locations. Their bundle identifiers
// can differ when an upgrade preserves the existing macOS preferences.
let applications = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications")
let allowed = ["Link Router.app", "Slack Link Router.app"].map { applications.appendingPathComponent($0).standardizedFileURL }
let installedApps = NSWorkspace.shared.runningApplications.filter { app in
    guard let path = app.bundleURL?.standardizedFileURL else { return false }
    return allowed.contains(path)
}
if CommandLine.arguments.contains("--stop") {
    for app in installedApps {
        guard app.terminate() else { fputs("Could not quit Link Router.\n", stderr); exit(1) }
        let deadline = Date().addingTimeInterval(5)
        while !app.isTerminated && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        guard app.isTerminated else { fputs("Link Router is still running.\n", stderr); exit(1) }
    }
} else {
    for scheme in ["http", "https"] {
        let path = NSWorkspace.shared.urlForApplication(toOpen: URL(string: scheme + "://example.invalid")!)
        print("\(scheme): \(path?.path ?? "unknown")")
    }
    for app in installedApps {
        print("running: \(app.bundleURL?.path ?? "unknown") pid=\(app.processIdentifier)")
    }
}
