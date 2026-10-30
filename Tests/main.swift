import AppKit
import Carbon

var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
    checks += 1
}

func browser_slackOrHelper_returnsIsland() {
    let sources = ["com.tinyspeck.slackmacgap", "com.tinyspeck.slackmacgap.helper", "com.tinyspeck.slackmacgap.helper.Renderer"]

    let browsers = sources.map { Routing.browser(for: $0) }

    for (source, browser) in zip(sources, browsers) {
        check(browser == .island, "\(source) must open Island")
    }
}

func browser_outlook_returnsIsland() {
    let source = "com.microsoft.Outlook"

    let browser = Routing.browser(for: source)

    check(browser == .island, "Outlook must open Island")
}

func browser_otherApp_returnsChrome() {
    let sources = ["com.google.Chrome", "com.apple.mail", "com.microsoft.teams2", "com.microsoft.Word"]

    let browsers = sources.map { Routing.browser(for: $0) }

    for (source, browser) in zip(sources, browsers) {
        check(browser == .chrome, "\(source) must open Chrome")
    }
}

func browser_lookalikeBundleID_returnsChrome() {
    let sources = ["com.tinyspeck.slackmacgap.other", "com.tinyspeck.slackmacgap.helperOther", "com.microsoft.OutlookOther"]

    let browsers = sources.map { Routing.browser(for: $0) }

    for (source, browser) in zip(sources, browsers) {
        check(browser == .chrome, "\(source) must open Chrome")
    }
}

func browser_missingSource_returnsChrome() {
    let source: String? = nil

    let browser = Routing.browser(for: source)

    check(browser == .chrome, "Missing source must open Chrome")
}

func islandSource_slackHelper_returnsSlack() {
    let source = "com.tinyspeck.slackmacgap.helper.Renderer"

    let islandSource = Routing.islandSource(for: source)

    check(islandSource == .slack, "Slack helpers must be reported as Slack")
}

func names_allSources_returnsJoinedPhrase() {
    let expected = "Slack and Outlook"

    let names = IslandSource.names

    check(names == expected, "Source names must read naturally, got \(names)")
}

func webURL_escapedQueryAndFragment_preservesURL() {
    let link = "https://example.com/a%2Fb?token=a%2Bb&next=https%3A%2F%2Fexample.org#fragment"

    let url = Routing.webURL(link)

    check(url?.absoluteString == link, "Preserve URL escaping, query and fragment")
}

func webURL_http_returnsURL() {
    let link = "http://example.com"

    let url = Routing.webURL(link)

    check(url != nil, "HTTP supported")
}

func webURL_nonWebValue_returnsNil() {
    let values = ["file:///etc/passwd", "javascript:alert(1)", "slack://channel", "https:", "", "/tmp/file"]

    let urls = values.map { Routing.webURL($0) }

    for (value, url) in zip(values, urls) {
        check(url == nil, "Reject non-web URL: \(value)")
    }
}

func senderPID_missingSender_returnsNil() {
    let event = NSAppleEventDescriptor.appleEvent(
        withEventClass: AEEventClass(kInternetEventClass), eventID: AEEventID(kAEGetURL),
        targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID)
    )

    let pid = Routing.senderPID(of: event)

    // macOS's sender-PID attribute is read-only. Exercise it through a real
    // NSWorkspace URL delivery in the integration test, rather than forging it.
    check(pid == nil, "Missing sender stays unknown")
}

browser_slackOrHelper_returnsIsland()
browser_outlook_returnsIsland()
browser_otherApp_returnsChrome()
browser_lookalikeBundleID_returnsChrome()
browser_missingSource_returnsChrome()
islandSource_slackHelper_returnsSlack()
names_allSources_returnsJoinedPhrase()
webURL_escapedQueryAndFragment_preservesURL()
webURL_http_returnsURL()
webURL_nonWebValue_returnsNil()
senderPID_missingSender_returnsNil()
print("Passed \(checks) routing checks")
