import AppKit

@main
enum andPasteLauncherApp {
    private static var appDelegate: andPasteApplicationDelegate?

    static func main() {
        let application = NSApplication.shared
        let delegate = andPasteApplicationDelegate()
        appDelegate = delegate
        application.delegate = delegate
        application.run()
    }
}
