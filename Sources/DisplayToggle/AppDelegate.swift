import AppKit
import DisplayToggleCore
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let manager = DisplayManager()
    private let hotKeyStore = HotKeyStore()
    private let hotKeys = HotKeyCenter()
    private var statusItem: NSStatusItem!
    private var settingsWindow: HotKeySettingsWindow?
    /// True while a shortcut recorder is listening.
    private var hotKeysSuspended = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        displaysChanged()
        CGDisplayRegisterReconfigurationCallback({ _, flags, _ in
            // Fires once per display per change; only react to the final notification.
            guard !flags.contains(.beginConfigurationFlag) else { return }
            DispatchQueue.main.async { (NSApp.delegate as? AppDelegate)?.displaysChanged() }
        }, nil)
    }

    private func displaysChanged() {
        let list = manager.displays()
        hotKeyStore.ensureDefaults(displayKeys: list.map(\.key))
        _ = applyHotKeys()
        let allOn = list.allSatisfy(\.isActive)
        statusItem.button?.image = NSImage(systemSymbolName: allOn ? "display.2" : "display",
                                           accessibilityDescription: Strings.t("icon.accessibility"))
    }

    // MARK: - Hotkeys

    /// Registers every stored shortcut; returns those macOS refused.
    private func applyHotKeys() -> Set<HotKeyAction> {
        hotKeys.unregisterAll()
        guard !hotKeysSuspended else { return [] }
        var failed = Set<HotKeyAction>()
        for (action, combo) in hotKeyStore.all() {
            let ok = hotKeys.register(combo) { [weak self] in self?.perform(action) }
            if !ok { failed.insert(action) }
        }
        return failed
    }

    private func perform(_ action: HotKeyAction) {
        switch action {
        case .enableAll:
            manager.enableAll()
        case .toggle(let key):
            if !manager.toggle(key: key) { NSSound.beep() }
        }
        displaysChanged()
    }

    @objc private func openHotKeys() {
        let rows = [HotKeySettingsWindow.Row(action: .enableAll, title: Strings.t("hk.enableAll"))]
            + manager.displays().map {
                HotKeySettingsWindow.Row(action: .toggle(displayKey: $0.key), title: Strings.t("hk.toggle", $0.name))
            }
        if settingsWindow == nil {
            settingsWindow = HotKeySettingsWindow(
                store: hotKeyStore,
                apply: { [weak self] in self?.applyHotKeys() ?? [] },
                // While a recorder listens, global hotkeys must not fire (or swallow the keys).
                suspend: { [weak self] recording in
                    self?.hotKeysSuspended = recording
                    _ = self?.applyHotKeys()
                })
        }
        settingsWindow?.show(rows: rows)
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let list = manager.displays()
        let activeCount = list.filter(\.isActive).count

        for d in list {
            let title = d.isMain ? Strings.t("menu.main", d.name) : d.name
            let item = NSMenuItem(title: title, action: #selector(toggle(_:)), keyEquivalent: "")
            item.target = self
            item.state = d.isActive ? .on : .off
            item.representedObject = d
            item.toolTip = Strings.t(d.isActive ? "tip.disable" : "tip.enable")
            if d.isActive && activeCount <= 1 { item.action = nil } // can't disable the last one
            show(hotKeyStore.combo(for: .toggle(displayKey: d.key)), on: item)
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let all = NSMenuItem(title: Strings.t("menu.enableAll"), action: #selector(enableAll), keyEquivalent: "")
        all.target = self
        if list.allSatisfy(\.isActive) { all.action = nil }
        show(hotKeyStore.combo(for: .enableAll), on: all)
        menu.addItem(all)

        menu.addItem(.separator())
        let hk = NSMenuItem(title: Strings.t("menu.hotkeys"), action: #selector(openHotKeys), keyEquivalent: ",")
        hk.target = self
        menu.addItem(hk)

        let login = NSMenuItem(title: Strings.t("menu.launchAtLogin"), action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        let quit = NSMenuItem(title: Strings.t("menu.quit"), action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private func show(_ combo: KeyCombo?, on item: NSMenuItem) {
        guard let combo, let key = combo.menuKeyEquivalent else { return }
        item.keyEquivalent = key
        item.keyEquivalentModifierMask = combo.modifierFlags
    }

    @objc private func toggle(_ sender: NSMenuItem) {
        guard let d = sender.representedObject as? Display else { return }
        if !manager.setEnabled(d, !d.isActive) { NSSound.beep() }
        displaysChanged()
    }

    @objc private func enableAll() {
        perform(.enableAll)
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    @objc private func quit() {
        manager.enableAll()
        NSApp.terminate(nil)
    }
}
