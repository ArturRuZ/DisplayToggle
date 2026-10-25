import Carbon.HIToolbox
import XCTest
@testable import DisplayToggleCore

final class HotKeyStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!

    override func setUp() {
        suite = "DisplayToggleTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    private func digit(_ n: Int) -> KeyCombo {
        KeyCombo(keyCode: KeyCombo.digitKeyCodes[n], modifiers: HotKeyStore.defaultModifiers)
    }

    func testActionIDRoundTrip() {
        for action in [HotKeyAction.enableAll, .toggle(displayKey: "7252-1-42")] {
            XCTAssertEqual(HotKeyAction(id: action.id), action)
        }
        XCTAssertNil(HotKeyAction(id: "toggle:"))
        XCTAssertNil(HotKeyAction(id: "bogus"))
    }

    func testDefaultsAssignDigitsInOrder() {
        let store = HotKeyStore(defaults: defaults)
        store.ensureDefaults(displayKeys: ["a", "b"])
        XCTAssertEqual(store.combo(for: .enableAll), digit(0))
        XCTAssertEqual(store.combo(for: .toggle(displayKey: "a")), digit(1))
        XCTAssertEqual(store.combo(for: .toggle(displayKey: "b")), digit(2))
    }

    func testNewDisplayGetsNextFreeDigit() {
        let store = HotKeyStore(defaults: defaults)
        store.ensureDefaults(displayKeys: ["a", "b"])
        store.set(nil, for: .toggle(displayKey: "a"))
        store.ensureDefaults(displayKeys: ["a", "b", "c"])
        XCTAssertNil(store.combo(for: .toggle(displayKey: "a")), "a cleared shortcut must stay cleared")
        XCTAssertEqual(store.combo(for: .toggle(displayKey: "c")), digit(1))
    }

    func testClearedEnableAllStaysCleared() {
        let store = HotKeyStore(defaults: defaults)
        store.ensureDefaults(displayKeys: [])
        store.set(nil, for: .enableAll)
        store.ensureDefaults(displayKeys: [])
        XCTAssertNil(store.combo(for: .enableAll))
    }

    func testSettingTakenComboMovesIt() {
        let store = HotKeyStore(defaults: defaults)
        store.ensureDefaults(displayKeys: ["a"])
        let displaced = store.set(digit(1), for: .enableAll)
        XCTAssertEqual(displaced, .toggle(displayKey: "a"))
        XCTAssertEqual(store.combo(for: .enableAll), digit(1))
        XCTAssertNil(store.combo(for: .toggle(displayKey: "a")))
    }

    func testPersistsAcrossInstances() {
        HotKeyStore(defaults: defaults).set(digit(5), for: .toggle(displayKey: "x"))
        XCTAssertEqual(HotKeyStore(defaults: defaults).combo(for: .toggle(displayKey: "x")), digit(5))
    }

    func testStableDisplayKey() {
        XCTAssertEqual(stableDisplayKey(vendor: 7252, model: 1, serial: 0), "7252-1-0")
    }
}
