import AppKit
import Carbon

enum Browser: String {
    case chrome = "com.google.Chrome"
    case island = "io.island.Island"

    var name: String { self == .island ? "Island" : "Google Chrome" }
}

enum Routing {
    static let slackBundleID = "com.tinyspeck.slackmacgap"

    static func browser(for sourceBundleID: String?) -> Browser {
        guard let sourceBundleID else { return .chrome }
        return sourceBundleID == slackBundleID
            || sourceBundleID == slackBundleID + ".helper"
            || sourceBundleID.hasPrefix(slackBundleID + ".helper.") ? .island : .chrome
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
