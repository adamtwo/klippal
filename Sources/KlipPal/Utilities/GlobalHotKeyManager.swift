import AppKit
import Carbon

/// Manages global keyboard shortcuts
class GlobalHotKeyManager {
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?

    typealias HotKeyAction = () -> Void
    private var action: HotKeyAction?

    /// Register a global hotkey (Cmd+Shift+V by default)
    func registerHotKey(keyCode: UInt32 = 9, modifiers: UInt32 = UInt32(cmdKey | shiftKey), action: @escaping HotKeyAction) -> Bool {
        self.action = action

        // Create event type spec
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        // Install event handler
        let handler: EventHandlerUPP = { (_, event, userData) -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }

            let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.action?()

            return noErr
        }

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, selfPointer, &eventHandler)

        guard status == noErr else {
            print("⚠️ Failed to install event handler: \(status)")
            return false
        }

        // Register the hot key (Cmd+Shift+V)
        let hotKeyID = EventHotKeyID(signature: OSType(fourCharCode: "cmgr"), id: 1)
        let registerStatus = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)

        guard registerStatus == noErr else {
            print("⚠️ Failed to register hotkey: \(registerStatus)")
            return false
        }

        let description = KeyCodeConverter.shortcutDescription(keyCode: keyCode, modifiers: modifiers)
        print("✅ Global hotkey registered: \(description)")
        return true
    }

    /// Re-register the hotkey with a new key code and modifiers (keeps existing action)
    func reregister(keyCode: UInt32, modifiers: UInt32) -> Bool {
        guard let existingAction = action else {
            print("⚠️ Cannot re-register: no action set")
            return false
        }

        // Unregister existing hotkey
        unregisterHotKey()

        // Register with new settings
        return registerHotKey(keyCode: keyCode, modifiers: modifiers, action: existingAction)
    }

    func unregisterHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    deinit {
        unregisterHotKey()
    }
}
