import AppKit
import Carbon

final class HotkeyManager {
    var onShowHistory: (() -> Void)?

    private let hotkeyID = EventHotKeyID(signature: OSType(0x43505648), id: 1)
    private var hotkeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    func start() {
        guard eventHandler == nil else { return }

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
        guard handlerStatus == noErr else { return }

        let vKeyCode: UInt32 = 9
        let modifiers = UInt32(controlKey | optionKey)
        RegisterEventHotKey(vKeyCode, modifiers, hotkeyID, GetApplicationEventTarget(), 0, &hotkeyRef)
    }

    func stop() {
        if let hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
        }
        hotkeyRef = nil

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
        guard pressedID.signature == hotkeyID.signature, pressedID.id == hotkeyID.id else {
            return noErr
        }
        DispatchQueue.main.async { [weak self] in
            self?.onShowHistory?()
        }
        return noErr
    }
}
