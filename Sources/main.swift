import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)

    #if DEBUG
    if let i = CommandLine.arguments.firstIndex(of: "--selftest") {
        let tester = SelfTest(out: CommandLine.arguments[i + 1])
        app.delegate = tester
        app.run()
    }
    #endif

    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
