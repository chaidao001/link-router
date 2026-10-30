import AppKit
import Carbon
import ServiceManagement

final class RouterApp: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var statusLine: NSMenuItem!
    private var lastRouteLine: NSMenuItem!
    private var loginItem: NSMenuItem!
    private var handledLink = false
    private let diagnostic = CommandLine.arguments.contains("--diagnostic")
    private let traceRouting = CommandLine.arguments.contains("--trace-routing")
    private let workspace = NSWorkspace.shared

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self, andSelector: #selector(openURL(_:reply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "Link Router"
        )
        if let iconURL = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "pdf"),
           let icon = NSImage(contentsOf: iconURL) {
            icon.isTemplate = true
            icon.size = NSSize(width: 20, height: 18)
            icon.accessibilityDescription = "Link Router"
            statusItem.button?.image = icon
        }
        statusItem.button?.toolTip = "Slack links → Island · Other web links → Chrome"
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(NSMenuItem(title: "Link Router", action: nil, keyEquivalent: ""))
        statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        menu.addItem(statusLine)
        menu.addItem(NSMenuItem(title: "Slack → Island", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Other apps → Chrome", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        lastRouteLine = NSMenuItem(title: "No links routed this session", action: nil, keyEquivalent: "")
        menu.addItem(lastRouteLine)
        menu.addItem(.separator())
        addItem("Enable in System Settings…", action: #selector(enable), to: menu)
        addItem("Switch Back to Chrome…", action: #selector(openBrowserSettings), to: menu)
        menu.addItem(.separator())
        loginItem = NSMenuItem(title: "Start at Login", action: #selector(toggleStartAtLogin), keyEquivalent: "")
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(.separator())
        addItem("Quit", action: #selector(quit), to: menu)
        statusItem.menu = menu
        if CommandLine.arguments.contains("--enable-login") {
            enableStartAtLogin()
            print("LOGIN status=\(loginStatusName)")
            fflush(stdout)
        }
        if diagnostic || traceRouting {
            print("READY pid=\(ProcessInfo.processInfo.processIdentifier)", terminator: "\n")
            fflush(stdout)
        }
        if !diagnostic && !traceRouting {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
                if !handledLink && !isDefault { showSetup() }
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSetup()
        return false
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        handledLink = true
        guard let chromeURL = workspace.urlForApplication(withBundleIdentifier: Browser.chrome.rawValue) else {
            sender.reply(toOpenOrPrint: .failure)
            return
        }
        let files = filenames.map { URL(fileURLWithPath: $0) }
        workspace.open(files, withApplicationAt: chromeURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            DispatchQueue.main.async { sender.reply(toOpenOrPrint: error == nil ? .success : .failure) }
        }
    }

    private func addItem(_ title: String, action: Selector, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    private var isDefault: Bool {
        ["http", "https"].allSatisfy { scheme in
            guard let app = workspace.urlForApplication(toOpen: URL(string: scheme + "://example.invalid")!)
            else { return false }
            return Bundle(url: app)?.bundleIdentifier == Bundle.main.bundleIdentifier
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        statusLine.title = isDefault ? "Routing is enabled" : "Not the default link handler"
        switch SMAppService.mainApp.status {
        case .enabled: loginItem.state = .on
        case .requiresApproval: loginItem.state = .mixed
        default: loginItem.state = .off
        }
    }

    private var loginStatusName: String {
        switch SMAppService.mainApp.status {
        case .enabled: return "enabled"
        case .requiresApproval: return "requires-approval"
        case .notRegistered: return "not-registered"
        case .notFound: return "not-found"
        @unknown default: return "unknown"
        }
    }

    private func enableStartAtLogin() {
        do {
            switch SMAppService.mainApp.status {
            case .enabled: return
            case .requiresApproval:
                SMAppService.openSystemSettingsLoginItems()
                return
            default: try SMAppService.mainApp.register()
            }
            if SMAppService.mainApp.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
        } catch {
            print("LOGIN error=\((error as NSError).domain):\((error as NSError).code)")
            fflush(stdout)
            showMessage("Could not enable Start at Login", "Open System Settings → General → Login Items & Extensions and add Link Router under Open at Login.")
        }
    }

    @objc private func toggleStartAtLogin() {
        if SMAppService.mainApp.status == .enabled {
            do { try SMAppService.mainApp.unregister() }
            catch { showMessage("Could not change Start at Login", "Change Link Router in System Settings → General → Login Items & Extensions.") }
        } else {
            enableStartAtLogin()
        }
    }

    @objc private func openURL(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        handledLink = true
        guard let raw = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = Routing.webURL(raw) else {
            reply.setParam(NSAppleEventDescriptor(int32: -1700), forKeyword: AEKeyword(keyErrorNumber))
            return
        }

        let source = Routing.sourceBundleID(of: event)
        let browser = Routing.browser(for: source)
        let sourceName = source == Routing.slackBundleID ? "Slack" : source ?? "Unidentified app"
        lastRouteLine?.title = "Last: \(sourceName) → \(browser.name)"

        // Diagnostic mode exercises real URL events without opening a browser or logging URLs.
        if diagnostic || traceRouting {
            print("ROUTE source=\(source ?? "unknown") browser=\(browser.rawValue)")
            fflush(stdout)
        }
        if diagnostic { return }

        guard let appURL = workspace.urlForApplication(withBundleIdentifier: browser.rawValue) else {
            showMessage("\(browser.name) was not found", "Install \(browser.name), then click the link again.")
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        workspace.open([url], withApplicationAt: appURL, configuration: configuration) { [weak self] _, error in
            if self?.traceRouting == true {
                print(error == nil ? "OPENED browser=\(browser.rawValue)" : "FAILED browser=\(browser.rawValue) code=\((error! as NSError).code)")
                fflush(stdout)
            }
            guard let error else { return }
            DispatchQueue.main.async {
                // Keep URLs out of errors, as work links may contain private query parameters.
                self?.showMessage("Could not open \(browser.name)",
                    "macOS returned error \((error as NSError).code). Open the browser and try the link again.")
            }
        }
    }

    private func showSetup() {
        guard !diagnostic else { return }
        if isDefault {
            showMessage("Link Router is enabled", "Slack links open in Island. Other web links open in Chrome.\n\nUse the Link Router icon in the menu bar to change routing or Start at Login.")
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Open Slack links in Island"
        alert.informativeText = "In System Settings → Desktop & Dock, choose Link Router as your Default web browser.\n\nSlack links will open in Island; other web links will open in Chrome. You can switch back to Google Chrome in the same setting."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Not Now")
        if alert.runModal() == .alertFirstButtonReturn { enable() }
    }

    @objc private func enable() {
        for browser in [Browser.island, .chrome] {
            guard workspace.urlForApplication(withBundleIdentifier: browser.rawValue) != nil else {
                showMessage("\(browser.name) was not found", "Install both Island and Google Chrome before enabling routing.")
                return
            }
        }
        openBrowserSettings()
    }

    @objc private func openBrowserSettings() {
        if !workspace.open(URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension")!) {
            showMessage("Open System Settings", "In Desktop & Dock, use Default web browser to choose Link Router to enable routing, or Google Chrome to turn it off.")
        }
    }

    private func showMessage(_ title: String, _ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = RouterApp()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
