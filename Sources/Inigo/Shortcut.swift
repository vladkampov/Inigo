import AppKit
import Carbon

@MainActor
final class GlobalShortcut {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let identifier: UInt32
    var onPress: (() -> Void)?
    init(identifier: UInt32 = 1) {
        self.identifier = identifier
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, pointer in
            guard let pointer else { return OSStatus(eventNotHandledErr) }
            let shortcut = Unmanaged<GlobalShortcut>.fromOpaque(pointer).takeUnretainedValue()
            var pressed = EventHotKeyID()
            guard GetEventParameter(event,EventParamName(kEventParamDirectObject),EventParamType(typeEventHotKeyID),nil,MemoryLayout<EventHotKeyID>.size,nil,&pressed) == noErr,
                  pressed.signature == 0x494E4947, pressed.id == shortcut.identifier else { return OSStatus(eventNotHandledErr) }
            Task { @MainActor in shortcut.onPress?() }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    func suspend() {
        if let hotKey { UnregisterEventHotKey(hotKey); self.hotKey = nil }
    }
    func register(key: UInt32, modifiers: UInt32) -> Bool {
        suspend()
        let id = EventHotKeyID(signature: 0x494E4947, id: identifier)
        return RegisterEventHotKey(key, modifiers, id, GetEventDispatcherTarget(), 0, &hotKey) == noErr
    }
}
