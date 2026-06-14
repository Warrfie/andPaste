import AppKit
import Carbon

enum HotkeyShortcut: String, CaseIterable, Identifiable {
    case fnV
    case controlOptionV
    case commandShiftV

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fnV:
            return "Fn + V"
        case .controlOptionV:
            return "Control + Option + V"
        case .commandShiftV:
            return "Command + Shift + V"
        }
    }

    fileprivate var carbonModifiers: UInt32 {
        switch self {
        case .fnV:
            return UInt32(kEventKeyModifierFnMask)
        case .controlOptionV:
            return UInt32(controlKey | optionKey)
        case .commandShiftV:
            return UInt32(cmdKey | shiftKey)
        }
    }
}

final class HotkeyManager {
    var onShowHistory: (() -> Void)?
    var shortcut: HotkeyShortcut = .fnV {
        didSet {
            guard shortcut != oldValue, eventHandler != nil else { return }
            unregisterHotkey()
            registerHotkey()
        }
    }

    private let hotkeyID = EventHotKeyID(signature: OSType(0x43505648), id: 1)
    private var hotkeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    func start() {
        guard eventHandler == nil else { return }
        AppLog.write("HotkeyManager start; shortcut=\(shortcut.rawValue)")

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                return manager.handleHotkey(event)
            },
            1,
            &eventSpec,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandler
        )
        guard handlerStatus == noErr else {
            AppLog.write("InstallEventHandler failed; status=\(handlerStatus)")
            return
        }
        AppLog.write("InstallEventHandler succeeded")

        registerHotkey()
    }

    func stop() {
        AppLog.write("HotkeyManager stop")
        unregisterHotkey()

        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        eventHandler = nil
    }

    deinit {
        stop()
    }

    private func handleHotkey(_ event: EventRef) -> OSStatus {
        var pressedID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &pressedID
        )
        guard status == noErr else { return status }
        guard pressedID.signature == hotkeyID.signature else {
            return noErr
        }
        guard pressedID.id == hotkeyID.id else {
            return noErr
        }
        AppLog.write("Hotkey pressed")
        DispatchQueue.main.async { [weak self] in
            self?.onShowHistory?()
        }
        return noErr
    }

    private func registerHotkey() {
        let vKeyCode: UInt32 = 9
        let status = RegisterEventHotKey(
            vKeyCode,
            shortcut.carbonModifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
        if status == noErr {
            AppLog.write("RegisterEventHotKey succeeded; shortcut=\(shortcut.rawValue)")
        } else {
            AppLog.write("RegisterEventHotKey failed; shortcut=\(shortcut.rawValue); status=\(status)")
        }
    }

    private func unregisterHotkey() {
        if let hotkeyRef {
            AppLog.write("UnregisterEventHotKey")
            UnregisterEventHotKey(hotkeyRef)
        }
        hotkeyRef = nil
    }
}
