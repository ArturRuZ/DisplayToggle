import AppKit
import CoreGraphics
import DisplayToggleCore

// Private CoreGraphics API (the same one BetterDisplay-style "disconnect" uses).
// Disables a display logically, as if the cable were pulled.
private typealias ConfigureDisplayEnabledFn = @convention(c) (CGDisplayConfigRef?, CGDirectDisplayID, Bool) -> CGError

private let configureDisplayEnabled: ConfigureDisplayEnabledFn? = {
    let handle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_NOW)
    guard let sym = dlsym(handle, "CGSConfigureDisplayEnabled") else { return nil }
    return unsafeBitCast(sym, to: ConfigureDisplayEnabledFn.self)
}()

struct Display {
    let id: CGDirectDisplayID
    /// Survives reconnects — hotkeys are bound to it.
    let key: String
    let name: String
    let isActive: Bool
    let isMain: Bool
}

private struct DisabledDisplay: Codable {
    let id: CGDirectDisplayID
    let name: String
}

final class DisplayManager {
    private let defaults = UserDefaults.standard
    private let disabledKey = "disabledDisplaysV2" // [stableKey: DisabledDisplay]

    init() {
        migrateFromV1()
    }

    /// 1.0 lived under another bundle ID and stored disabled displays as [rawID: name].
    /// Import them so "Enable all" can still bring those displays back.
    private func migrateFromV1() {
        guard let old = UserDefaults(suiteName: "com.dexter.DisplayToggle"),
              let map = old.dictionary(forKey: "disabledDisplays") as? [String: String] else { return }
        var off = disabled
        for (rawID, name) in map {
            guard let id = CGDirectDisplayID(rawID) else { continue }
            off[key(for: id)] = DisabledDisplay(id: id, name: name)
        }
        disabled = off
        old.removeObject(forKey: "disabledDisplays")
    }

    private var disabled: [String: DisabledDisplay] {
        get {
            guard let data = defaults.data(forKey: disabledKey) else { return [:] }
            return (try? JSONDecoder().decode([String: DisabledDisplay].self, from: data)) ?? [:]
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: disabledKey) }
    }

    func activeIDs() -> [CGDirectDisplayID] {
        var ids = [CGDirectDisplayID](repeating: 0, count: 32)
        var count: UInt32 = 0
        CGGetActiveDisplayList(32, &ids, &count)
        return Array(ids.prefix(Int(count)))
    }

    private func key(for id: CGDirectDisplayID) -> String {
        stableDisplayKey(vendor: CGDisplayVendorNumber(id), model: CGDisplayModelNumber(id),
                         serial: CGDisplaySerialNumber(id))
    }

    /// Active displays (main first) followed by the ones this app turned off.
    func displays() -> [Display] {
        var names: [CGDirectDisplayID: String] = [:]
        for screen in NSScreen.screens {
            if let n = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                names[CGDirectDisplayID(n.uint32Value)] = screen.localizedName
            }
        }
        var result = activeIDs().map { id in
            Display(id: id, key: key(for: id), name: names[id] ?? "Display \(id)",
                    isActive: true, isMain: CGDisplayIsMain(id) != 0)
        }
        // Forget displays that came back on their own (logout, replug, another tool).
        var off = disabled
        for d in result { off.removeValue(forKey: d.key) }
        disabled = off
        for (key, d) in off.sorted(by: { $0.value.name < $1.value.name }) {
            result.append(Display(id: d.id, key: key, name: d.name, isActive: false, isMain: false))
        }
        return result
    }

    @discardableResult
    func setEnabled(_ display: Display, _ enabled: Bool) -> Bool {
        guard let fn = configureDisplayEnabled else { return false }
        if !enabled && activeIDs().count <= 1 { return false } // never turn off the last screen
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else { return false }
        guard fn(config, display.id, enabled) == .success else {
            CGCancelDisplayConfiguration(config)
            return false
        }
        // .forSession: a logout/reboot always brings every display back.
        guard CGCompleteDisplayConfiguration(config, .forSession) == .success else { return false }
        var off = disabled
        if enabled { off.removeValue(forKey: display.key) }
        else { off[display.key] = DisabledDisplay(id: display.id, name: display.name) }
        disabled = off
        return true
    }

    @discardableResult
    func toggle(key: String) -> Bool {
        guard let d = displays().first(where: { $0.key == key }) else { return false }
        return setEnabled(d, !d.isActive)
    }

    func enableAll() {
        for d in displays() where !d.isActive { setEnabled(d, true) }
    }
}
