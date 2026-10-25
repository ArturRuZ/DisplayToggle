import AppKit
import DisplayToggleCore

/// "Keyboard Shortcuts…" window: one recorder per action.
final class HotKeySettingsWindow: NSWindowController, NSWindowDelegate {
    struct Row {
        let action: HotKeyAction
        let title: String
    }

    private let store: HotKeyStore
    /// Re-registers all hotkeys; returns the actions whose combo couldn't be grabbed.
    private let apply: () -> Set<HotKeyAction>
    private let suspend: (Bool) -> Void
    private var rows: [Row] = []
    private let stack = NSStackView()

    init(store: HotKeyStore, apply: @escaping () -> Set<HotKeyAction>, suspend: @escaping (Bool) -> Void) {
        self.store = store
        self.apply = apply
        self.suspend = suspend
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 200),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = Strings.t("hk.title")
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = NSView()
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            stack.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func show(rows: [Row]) {
        self.rows = rows
        rebuild()
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    private func rebuild() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let grid = NSGridView()
        grid.rowSpacing = 8
        grid.columnSpacing = 12
        for row in rows {
            let label = NSTextField(labelWithString: row.title)
            let recorder = ShortcutRecorder()
            recorder.combo = store.combo(for: row.action)
            recorder.onRecordingChanged = { [weak self] on in self?.suspend(on) }
            recorder.onChange = { [weak self] combo in self?.change(row.action, to: combo) ?? false }
            let clear = NSButton(title: "✕", target: nil, action: nil)
            clear.bezelStyle = .inline
            clear.toolTip = Strings.t("hk.clear")
            clear.target = self
            clear.action = #selector(clearClicked(_:))
            clear.identifier = NSUserInterfaceItemIdentifier(row.action.id)
            grid.addRow(with: [label, recorder, clear])
        }
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        stack.addArrangedSubview(grid)

        let hint = NSTextField(wrappingLabelWithString: Strings.t("hk.hint"))
        hint.textColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hint.preferredMaxLayoutWidth = 420
        stack.addArrangedSubview(hint)
        window?.setContentSize(stack.fittingSize)
    }

    @objc private func clearClicked(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue, let action = HotKeyAction(id: id) else { return }
        _ = change(action, to: nil)
        rebuild()
    }

    private func change(_ action: HotKeyAction, to combo: KeyCombo?) -> Bool {
        let previous = store.combo(for: action)
        let displaced = store.set(combo, for: action)
        let failed = apply()
        if let combo, failed.contains(action) {
            // Roll back: the combo is owned by macOS or another app.
            store.set(previous, for: action)
            if let displaced { store.set(combo, for: displaced) }
            _ = apply()
            let alert = NSAlert()
            alert.messageText = Strings.t("hk.taken.title")
            alert.informativeText = Strings.t("hk.taken.text", combo.displayString)
            alert.runModal()
            return false
        }
        if displaced != nil {
            // Another row just lost this combo — redraw on the next tick (we're inside its recorder).
            DispatchQueue.main.async { [weak self] in self?.rebuild() }
        }
        return true
    }

    func windowWillClose(_ notification: Notification) {
        suspend(false)
    }
}
