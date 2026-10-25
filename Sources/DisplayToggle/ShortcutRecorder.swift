import AppKit
import Carbon.HIToolbox
import DisplayToggleCore

/// A button that records a key combination when clicked.
final class ShortcutRecorder: NSButton {
    var combo: KeyCombo? { didSet { refresh() } }
    /// Called with the new combo (nil = cleared). Return false to reject it.
    var onChange: ((KeyCombo?) -> Bool)?
    var onRecordingChanged: ((Bool) -> Void)?

    private var recording = false

    init() {
        super.init(frame: .zero)
        bezelStyle = .rounded
        target = self
        action = #selector(clicked)
        widthAnchor.constraint(greaterThanOrEqualToConstant: 170).isActive = true
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var acceptsFirstResponder: Bool { true }

    override func resignFirstResponder() -> Bool {
        if recording { stopRecording() }
        return super.resignFirstResponder()
    }

    @objc private func clicked() {
        recording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        recording = true
        window?.makeFirstResponder(self)
        onRecordingChanged?(true)
        refresh()
    }

    private func stopRecording() {
        guard recording else { return }
        recording = false
        onRecordingChanged?(false)
        refresh()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard recording else { return super.performKeyEquivalent(with: event) }
        handle(event)
        return true
    }

    override func keyDown(with event: NSEvent) {
        recording ? handle(event) : super.keyDown(with: event)
    }

    private func handle(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection([.control, .option, .shift, .command])
        if flags.isEmpty && Int(event.keyCode) == kVK_Escape {
            stopRecording()
            return
        }
        if flags.isEmpty && (Int(event.keyCode) == kVK_Delete || Int(event.keyCode) == kVK_ForwardDelete) {
            if onChange?(nil) ?? true { combo = nil }
            stopRecording()
            return
        }
        let candidate = KeyCombo(keyCode: event.keyCode, flags: flags)
        guard candidate.isValidGlobalShortcut else {
            NSSound.beep()
            return
        }
        stopRecording()
        if onChange?(candidate) ?? true { combo = candidate }
    }

    private func refresh() {
        title = recording ? Strings.t("hk.recording") : (combo?.displayString ?? Strings.t("hk.none"))
    }
}
