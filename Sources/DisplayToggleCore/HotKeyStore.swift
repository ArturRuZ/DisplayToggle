import Carbon.HIToolbox
import Foundation

/// What a global shortcut does.
public enum HotKeyAction: Hashable {
    case enableAll
    /// Toggle a display, identified by its stable key (see `stableDisplayKey`).
    case toggle(displayKey: String)

    public var id: String {
        switch self {
        case .enableAll: return "enableAll"
        case .toggle(let key): return "toggle:" + key
        }
    }

    public init?(id: String) {
        if id == "enableAll" { self = .enableAll; return }
        let prefix = "toggle:"
        guard id.hasPrefix(prefix), id.count > prefix.count else { return nil }
        self = .toggle(displayKey: String(id.dropFirst(prefix.count)))
    }
}

/// Display IDs change between reconnects; vendor/model/serial don't.
public func stableDisplayKey(vendor: UInt32, model: UInt32, serial: UInt32) -> String {
    "\(vendor)-\(model)-\(serial)"
}

/// Persists shortcuts in UserDefaults and hands out defaults:
/// ⌃⌥⌘0 — enable all, ⌃⌥⌘1…9 — toggle each newly seen display.
public final class HotKeyStore {
    public static let defaultModifiers = UInt32(controlKey | optionKey | cmdKey)

    private let defaults: UserDefaults
    private let combosKey = "hotKeys"
    private let initializedKey = "hotKeysInitialized"
    private let seenKey = "hotKeysSeenDisplays"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func all() -> [HotKeyAction: KeyCombo] {
        guard let data = defaults.data(forKey: combosKey),
              let raw = try? JSONDecoder().decode([String: KeyCombo].self, from: data) else { return [:] }
        var result: [HotKeyAction: KeyCombo] = [:]
        for (id, combo) in raw {
            if let action = HotKeyAction(id: id) { result[action] = combo }
        }
        return result
    }

    public func combo(for action: HotKeyAction) -> KeyCombo? { all()[action] }

    /// Assigns (or clears with nil) a shortcut. The same combo is taken away from any other action;
    /// that action is returned so the UI can tell the user.
    @discardableResult
    public func set(_ combo: KeyCombo?, for action: HotKeyAction) -> HotKeyAction? {
        var map = all()
        var displaced: HotKeyAction?
        if let combo {
            for (other, c) in map where other != action && c == combo {
                map[other] = nil
                displaced = other
            }
        }
        map[action] = combo
        save(map)
        return displaced
    }

    /// Fills in defaults once per action: a cleared shortcut stays cleared.
    public func ensureDefaults(displayKeys: [String]) {
        var map = all()
        if !defaults.bool(forKey: initializedKey) {
            let zero = KeyCombo(keyCode: KeyCombo.digitKeyCodes[0], modifiers: HotKeyStore.defaultModifiers)
            if !map.values.contains(zero) { map[.enableAll] = zero }
            defaults.set(true, forKey: initializedKey)
        }
        var seen = Set(defaults.stringArray(forKey: seenKey) ?? [])
        for key in displayKeys where !seen.contains(key) {
            seen.insert(key)
            let used = Set(map.values)
            let free = KeyCombo.digitKeyCodes[1...]
                .map { KeyCombo(keyCode: $0, modifiers: HotKeyStore.defaultModifiers) }
                .first { !used.contains($0) }
            if let free, map[.toggle(displayKey: key)] == nil { map[.toggle(displayKey: key)] = free }
        }
        defaults.set(seen.sorted(), forKey: seenKey)
        save(map)
    }

    private func save(_ map: [HotKeyAction: KeyCombo]) {
        let raw = Dictionary(uniqueKeysWithValues: map.map { ($0.key.id, $0.value) })
        defaults.set(try? JSONEncoder().encode(raw), forKey: combosKey)
    }
}
