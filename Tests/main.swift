import AppKit
import Carbon

var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
    checks += 1
}

check(Routing.browser(for: "com.tinyspeck.slackmacgap") == .island, "Slack must open Island")
check(Routing.browser(for: "com.tinyspeck.slackmacgap.helper") == .island, "Slack helpers must open Island")
check(Routing.browser(for: "com.tinyspeck.slackmacgap.helper.Renderer") == .island, "Slack renderer helper must open Island")
check(Routing.browser(for: "com.google.Chrome") == .chrome, "Chrome must stay in Chrome")
check(Routing.browser(for: "com.apple.mail") == .chrome, "Other apps must open Chrome")
check(Routing.browser(for: nil) == .chrome, "Missing source must open Chrome")
check(Routing.browser(for: "com.tinyspeck.slackmacgap.other") == .chrome, "Unrelated bundle must open Chrome")
check(Routing.browser(for: "com.tinyspeck.slackmacgap.helperOther") == .chrome, "Require exact helper prefix")

let link = "https://example.com/a%2Fb?token=a%2Bb&next=https%3A%2F%2Fexample.org#fragment"
check(Routing.webURL(link)?.absoluteString == link, "Preserve URL escaping, query and fragment")
check(Routing.webURL("http://example.com") != nil, "HTTP supported")
for invalid in ["file:///etc/passwd", "javascript:alert(1)", "slack://channel", "https:", "", "/tmp/file"] {
    check(Routing.webURL(invalid) == nil, "Reject non-web URL: \(invalid)")
}

let event = NSAppleEventDescriptor.appleEvent(
    withEventClass: AEEventClass(kInternetEventClass), eventID: AEEventID(kAEGetURL),
    targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID)
)
check(Routing.senderPID(of: event) == nil, "Missing sender stays unknown")
// macOS's sender-PID attribute is read-only. Exercise it through a real
// NSWorkspace URL delivery in the integration test, rather than forging it.
print("Passed \(checks) routing checks")
