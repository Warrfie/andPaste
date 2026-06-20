import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Settings")
                .font(.system(size: 18, weight: .semibold))

            Picker(selection: Binding(
                get: { model.hotkeyShortcut },
                set: { model.setHotkeyShortcut($0) }
            )) {
                ForEach(HotkeyShortcut.allCases) { shortcut in
                    Text(shortcut.title)
                        .tag(shortcut)
                }
            } label: {
                Label("Hotkey", systemImage: "keyboard")
            }
            .pickerStyle(.menu)

            Toggle(isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            )) {
                Label("Launch at Login", systemImage: "arrow.clockwise.circle")
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 400, height: 190)
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(model: AppModel())
            .previewDisplayName("Settings")
    }
}
#endif
