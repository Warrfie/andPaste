import AppKit

@main
enum CopyPasteLauncherApp {
    private static var appDelegate: CopyPasteApplicationDelegate?

    static func main() {
        let application = NSApplication.shared
        let delegate = CopyPasteApplicationDelegate()
        appDelegate = delegate
        application.delegate = delegate
        application.run()
    }
}
