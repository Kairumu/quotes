import XCTest

/// Phase 3 regression test for the wholesale value-based routing of the 서재
/// (Books) tab. Reproduces the exact push chain that previously suffered
/// double-push / overlap bugs:
///
///   서재 → tap a living cover (book-cover-b001) → Book Detail →
///   tap 처음부터 → Reader (top screen, detail/서재 gone).
///
/// BookDetail and the Reader share the same nav-bar title (the book title), so
/// the reader is proven by a reader-ONLY probe (the 보기 모드 segmented control's
/// 문장 segment) while asserting the detail-only 처음부터 CTA and the 서재 cover grid
/// are gone — the same overlap assertion style as `BookmarkNavigationUITests`.
final class BooksNavigationUITests: XCTestCase {

    @MainActor
    func testLibraryCoverToDetailToReaderPushesCleanly() throws {
        let app = XCUIApplication()
        // -disableChromeAutoHide: asserts the 이어보기 mode bar at T+8s settled,
        // past the 3s auto-hide mark.
        app.launchArguments = ["-disableChromeAutoHide"]
        app.launch()
        sleep(2)

        // 1) 서재 tab.
        app.tabBars.buttons["서재"].tap()
        sleep(1)

        // 2) Tap the known living cover directly (no title-substring guessing).
        //    The cover uses `.accessibilityElement(children: .combine)` inside a
        //    NavigationLink, so it surfaces as a button rather than an
        //    `otherElement` — match by identifier across ANY element type.
        let cover = app.descendants(matching: .any)["book-cover-b001"].firstMatch
        XCTAssertTrue(cover.waitForExistence(timeout: 8), "book-cover-b001 not found in 서재")
        cover.tap()

        // 3) Book Detail must be on top: its nav bar carries the book title.
        let detailBar = app.navigationBars["The Tortoise and the Hare"]
        XCTAssertTrue(detailBar.waitForExistence(timeout: 5), "Book Detail nav bar not on top")

        // 4) The detail-only 처음부터 CTA must exist here — then open the reader.
        let startButton = app.buttons["처음부터"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "처음부터 CTA not found on Book Detail")
        startButton.tap()

        // 5) The reader must be the TOP screen. Prove it with a reader-ONLY probe:
        //    the 보기 모드 segmented control's 이어보기 segment (absent on Book Detail).
        //    Default mode is .continuous (이어보기) per the global reader.viewMode default.
        let readerProbe = app.buttons["이어보기"]
        XCTAssertTrue(
            readerProbe.waitForExistence(timeout: 8),
            "Reader mode bar (이어보기) not on top — push failed or was covered"
        )
        sleep(2)
        attach(name: "T+2s after 처음부터")

        // Overlap assertions: the detail CTA and the 서재 cover grid must be gone.
        XCTAssertFalse(
            app.buttons["처음부터"].exists,
            "처음부터 CTA still present — Book Detail overlaps the reader"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["book-cover-b001"].firstMatch.isHittable,
            "서재 cover grid still hittable — screens overlap"
        )
        XCTAssertFalse(
            app.navigationBars["북마크"].exists,
            "북마크 nav bar present — unexpected overlap"
        )

        // Settled state: still the reader, no regression to an overlapping stack.
        sleep(6)
        attach(name: "T+8s settled")
        XCTAssertTrue(readerProbe.exists, "Reader mode bar disappeared after settling")
        XCTAssertFalse(app.buttons["처음부터"].exists, "Book Detail reappeared under the reader")
    }

    @MainActor
    private func attach(name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
