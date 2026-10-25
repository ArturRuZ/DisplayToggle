import Carbon.HIToolbox
import DisplayToggleCore

/// System-wide shortcuts via Carbon `RegisterEventHotKey` — works without the
/// Accessibility / Input Monitoring permission.
final class HotKeyCenter {
    private static let signature: OSType = 0x4454_474C // 'DTGL'

    private var refs: [EventHotKeyRef] = []
    private var handlers: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1
    private var handlerInstalled = false

    /// Returns false when the combo is already grabbed by macOS or another app.
    func register(_ combo: KeyCombo, handler: @escaping () -> Void) -> Bool {
        installHandlerIfNeeded()
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: HotKeyCenter.signature, id: nextID)
        let status = RegisterEventHotKey(combo.keyCode, combo.modifiers, hotKeyID,
                                         GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &ref)
        guard status == noErr, let ref else { return false }
        refs.append(ref)
        handlers[nextID] = handler
        nextID += 1
        return true
    }

    func unregisterAll() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
        handlers.removeAll()
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard status == noErr, hotKeyID.signature == HotKeyCenter.signature else {
                return OSStatus(eventNotHandledErr)
            }
            let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
            center.handlers[hotKeyID.id]?()
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
    }
}
