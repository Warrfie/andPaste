import SwiftUI

@main
struct CopyPasteApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            StatusMenuView(model: model)
        } label: {
            MenuBarLabelView(model: model)
        }
    }
}

private struct MenuBarLabelView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Image(systemName: "clipboard")
            .onAppear {
                model.start()
            }
    }
}

private struct StatusMenuView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Button("Show Clipboard History") {
            model.showHistoryWindow()
        }

        Button("Clear History") {
            model.store.clearHistory()
        }

        Divider()

        Button("Quit CopyPaste") {
            model.quit()
        }
        .keyboardShortcut("q", modifiers: [.command])
        .onAppear {
            model.start()
        }
    }
}
