import XCTest
@testable import DisplayToggleCore

final class StringsTests: XCTestCase {
    func testBothLanguagesHaveTheSameKeys() {
        XCTAssertEqual(Set(Strings.en.keys), Set(Strings.ru.keys))
    }

    func testFormatPlaceholdersMatch() {
        for (key, en) in Strings.en {
            let ru = Strings.ru[key] ?? ""
            XCTAssertEqual(en.components(separatedBy: "%@").count, ru.components(separatedBy: "%@").count, key)
        }
    }
}
