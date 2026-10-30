import AppKit
import Carbon

enum Browser: String {
    case chrome = "com.google.Chrome"
    case island = "io.island.Island"

    var name: String { self == .island ? "Island" : "Google Chrome" }
}

/// Apps whose links open in Island.
enum IslandSource: String, CaseIterable {
    case slack = "com.tinyspeck.slackmacgap"
    case outlook = "com.microsoft.Outlook"

    var name: String {
        switch self {
        case .slack: return "Slack"
        case .outlook: return "Outlook"
        }
    }

    /// The source names as a phrase, such as "Slack and Outlook". English, like the rest of the interface.
    static var names: String {
        let formatter = ListFormatter()
        formatter.locale = Locale(identifier: "en")
        return formatter.string(from: allCases.map(\.name)) ?? ""
    }

    /// Matches the app itself and any "<bundle ID>.helper" subprocesses, such as Slack's Electron helpers.
    func matches(_ bundleID: String) -> Bool {
        bundleID == rawValue || bundleID == rawValue + ".helper" || bundleID.hasPrefix(rawValue + ".helper.")
    }
}

enum Routing {
    static func islandSource(for sourceBundleID: String?) -> IslandSource? {
        guard let sourceBundleID else { return nil }
        return IslandSource.allCases.first { $0.matches(sourceBundleID) }
    }

    static func browser(for sourceBundleID: String?) -> Browser {
        islandSource(for: sourceBundleID) == nil ? .chrome : .island
    }

    static func webURL(_ value: String) -> URL? {
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    static func senderPID(of event: NSAppleEventDescriptor) -> pid_t? {
        guard let descriptor = event.attributeDescriptor(forKeyword: AEKeyword(keySenderPIDAttr)),
              descriptor.int32Value > 0 else { return nil }
        return descriptor.int32Value
    }

    static func sourceBundleID(of event: NSAppleEventDescriptor) -> String? {
        guard let pid = senderPID(of: event) else { return nil }
        return NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
    }
}
