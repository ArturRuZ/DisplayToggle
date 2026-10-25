import AppKit
import Carbon.HIToolbox
import XCTest
@testable import DisplayToggleCore

final class KeyComboTests: XCTestCase {
    func testModifierFlagsRoundTrip() {
        let flags: NSEvent.ModifierFlags = [.control, .option, .command]
        let combo = KeyCombo(keyCode: UInt16(kVK_ANSI_1), flags: flags)
        XCTAssertEqual(combo.modifiers, UInt32(controlKey | optionKey | cmdKey))
        XCTAssertEqual(combo.modifierFlags, flags)
    }

    func testIgnoresNonShortcutFlags() {
        let combo = KeyCombo(keyCode: UInt16(kVK_ANSI_1), flags: [.command, .capsLock, .numericPad])
        XCTAssertEqual(combo.modifiers, UInt32(cmdKey))
    }

    func testSymbolsAreInAppleOrder() {
        let combo = KeyCombo(keyCode: UInt16(kVK_F5), flags: [.command, .shift, .option, .control])
        XCTAssertEqual(combo.displayString, "⌃⌥⇧⌘F5")
    }

    func testSpecialKeyNames() {
        XCTAssertEqual(KeyCombo(keyCode: UInt32(kVK_LeftArrow), modifiers: UInt32(cmdKey)).displayString, "⌘←")
        XCTAssertEqual(KeyCombo(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey)).displayString, "⌥Space")
    }

    func testDigitKeyName() {
        XCTAssertEqual(KeyCombo(keyCode: UInt32(kVK_ANSI_7), modifiers: UInt32(cmdKey)).keyName, "7")
    }

    func testValidity() {
        XCTAssertFalse(KeyCombo(keyCode: UInt32(kVK_ANSI_A), modifiers: 0).isValidGlobalShortcut)
        XCTAssertFalse(KeyCombo(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(shiftKey)).isValidGlobalShortcut)
        XCTAssertTrue(KeyCombo(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(optionKey)).isValidGlobalShortcut)
        XCTAssertTrue(KeyCombo(keyCode: UInt32(kVK_F13), modifiers: 0).isValidGlobalShortcut)
    }

    func testMenuKeyEquivalent() {
        let f1 = KeyCombo(keyCode: UInt32(kVK_F1), modifiers: 0)
        XCTAssertEqual(f1.menuKeyEquivalent, String(Character(UnicodeScalar(NSF1FunctionKey)!)))
        XCTAssertEqual(KeyCombo(keyCode: UInt32(kVK_ANSI_3), modifiers: UInt32(cmdKey)).menuKeyEquivalent, "3")
        XCTAssertNil(KeyCombo(keyCode: UInt32(kVK_Return), modifiers: UInt32(cmdKey)).menuKeyEquivalent)
    }

    func testCodable() throws {
        let combo = KeyCombo(keyCode: 18, modifiers: UInt32(cmdKey))
        let data = try JSONEncoder().encode(combo)
        XCTAssertEqual(try JSONDecoder().decode(KeyCombo.self, from: data), combo)
    }
}
