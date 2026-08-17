import XCTest

/// Reproduces: 마이 > 북마크 관리 > tap a highlight bookmark → reader should
/// push cleanly. Holds the final state for several seconds so an external
/// `simctl io screenshot` can capture what is actually on screen.
final class BookmarkNavigationUITests: XCTestCase {

    @MainActor
    func testOpenHighlightBookmarkFromMyTab() throws {
        let app = XCUIApplication()
        // -disableChromeAutoHide: asserts reader nav bar at T+2s AND T+8s settled,
        // past the 3s auto-hide mark.
        app.launchArguments = ["-seedTestBookmark", "-disableChromeAutoHide"]
        app.launch()
        sleep(2)

        app.tabBars.buttons["마이"].tap()
        sleep(1)

        let manageRow = app.buttons.containing(
            NSPredicate(format: "label CONTAINS '북마크 관리'")
        ).firstMatch
        XCTAssertTrue(manageRow.waitForExistence(timeout: 5), "북마크 관리 row not found")
        manageRow.tap()
        sleep(2)

        let bookmarkRow = app.buttons.containing(
            NSPredicate(format: "label CONTAINS 'UITEST-HL'")
        ).firstMatch
        if bookmarkRow.waitForExistence(timeout: 5) {
            bookmarkRow.tap()
        } else {
            let text = app.staticTexts["UITEST-HL"].firstMatch
            XCTAssertTrue(text.waitForExistence(timeout: 5), "UITEST-HL row not found")
            text.tap()
        }

        // The reader must be the TOP screen: its nav bar carries the book
        // title. The bookmark list's nav bar must be gone.
        let readerBar = app.navigationBars["The Tortoise and the Hare"]
        XCTAssertTrue(
            readerBar.waitForExistence(timeout: 8),
            "Reader nav bar not on top — push failed or was covered"
        )
        sleep(2)
        attach(name: "T+2s after tap")

        let bookmarkBar = app.navigationBars["북마크"]
        XCTAssertFalse(
            bookmarkBar.exists,
            "북마크 nav bar still present — bookmark screen overlaps the reader"
        )

        // Settled state: still the reader, list still absent.
        sleep(6)
        attach(name: "T+8s settled")
        XCTAssertTrue(readerBar.exists, "Reader nav bar disappeared after settling")
        XCTAssertFalse(app.navigationBars["북마크"].exists, "북마크 screen reappeared")
    }

    @MainActor
    private func attach(name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
