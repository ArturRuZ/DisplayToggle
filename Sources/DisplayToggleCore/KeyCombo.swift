import AppKit
import Carbon.HIToolbox

/// A global shortcut: virtual key code + Carbon modifier mask
/// (the format `RegisterEventHotKey` expects).
public struct KeyCombo: Codable, Hashable {
    public var keyCode: UInt32
    public var modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public init(keyCode: UInt16, flags: NSEvent.ModifierFlags) {
        self.init(keyCode: UInt32(keyCode), modifiers: KeyCombo.carbonModifiers(from: flags))
    }

    public static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        return m
    }

    public var modifierFlags: NSEvent.ModifierFlags {
        var f: NSEvent.ModifierFlags = []
        if modifiers & UInt32(controlKey) != 0 { f.insert(.control) }
        if modifiers & UInt32(optionKey) != 0 { f.insert(.option) }
        if modifiers & UInt32(shiftKey) != 0 { f.insert(.shift) }
        if modifiers & UInt32(cmdKey) != 0 { f.insert(.command) }
        return f
    }

    /// A global shortcut must have ⌃, ⌥ or ⌘ — otherwise it would eat plain typing.
    /// Function keys (F1…F20) are allowed alone.
    public var isValidGlobalShortcut: Bool {
        let strong = UInt32(controlKey) | UInt32(optionKey) | UInt32(cmdKey)
        return modifiers & strong != 0 || KeyCombo.functionKeyNumber(keyCode) != nil
    }

    public var modifierSymbols: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s
    }

    public var keyName: String {
        if let n = KeyCombo.functionKeyNumber(keyCode) { return "F\(n)" }
        if let special = KeyCombo.specialKeyNames[Int(keyCode)] { return special }
        if let ch = KeyCombo.character(forKeyCode: keyCode), !ch.isEmpty { return ch.uppercased() }
        return "#\(keyCode)"
    }

    public var displayString: String { modifierSymbols + keyName }

    /// Character for `NSMenuItem.keyEquivalent`, so the menu shows the shortcut; nil if not representable.
    public var menuKeyEquivalent: String? {
        if let n = KeyCombo.functionKeyNumber(keyCode) {
            return UnicodeScalar(NSF1FunctionKey + n - 1).map { String(Character($0)) }
        }
        if KeyCombo.specialKeyNames[Int(keyCode)] != nil { return nil }
        guard let ch = KeyCombo.character(forKeyCode: keyCode), ch.count == 1 else { return nil }
        return ch.lowercased()
    }

    // MARK: - Key tables

    static let functionKeys: [Int] = [
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
        kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
    ]

    static func functionKeyNumber(_ keyCode: UInt32) -> Int? {
        functionKeys.firstIndex(of: Int(keyCode)).map { $0 + 1 }
    }

    static let specialKeyNames: [Int: String] = [
        kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space", kVK_Delete: "⌫",
        kVK_ForwardDelete: "⌦", kVK_Escape: "⎋", kVK_LeftArrow: "←", kVK_RightArrow: "→",
        kVK_UpArrow: "↑", kVK_DownArrow: "↓", kVK_Home: "↖", kVK_End: "↘",
        kVK_PageUp: "⇞", kVK_PageDown: "⇟", kVK_ANSI_KeypadEnter: "⌤",
    ]

    /// Digit keys 0…9 (their virtual key codes are not sequential).
    public static let digitKeyCodes: [UInt32] = [
        kVK_ANSI_0, kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4,
        kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9,
    ].map { UInt32($0) }

    /// What the key prints on the current ASCII-capable layout (Latin even when typing in Russian).
    static func character(forKeyCode keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
        var deadKeys: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = data.withUnsafeBytes { raw -> OSStatus in
            guard let layout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return -1 }
            return UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0,
                                  UInt32(LMGetKbdType()), OptionBits(1 << kUCKeyTranslateNoDeadKeysBit),
                                  &deadKeys, chars.count, &length, &chars)
        }
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }
}
