import XCTest

/// T8 — Reader mode segmented control tests.
///
/// Opens the reader via the seeded UITEST-HL bookmark (마이 → 북마크 관리 →
/// UITEST-HL row, anchored to b001-c002-p002-s002), then verifies:
///
///  1. Default mode is 이어보기 (.continuous).
///  2. All 4 segments (문장/문단/페이지/이어보기) can be selected and the reader
///     stays alive after each switch.
///  3. In 문장 mode, swiping left advances the carousel and the "reader.progress"
///     capsule label changes deterministically.
///  4. Mode selection persists across app termination + relaunch (global
///     reader.viewMode UserDefaults key).
final class ReaderModeSwitchingUITests: XCTestCase {

    // MARK: - Shared helpers

    /// Launch the app with the test-bookmark seed argument.
    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-seedTestBookmark"]
        app.launch()
        sleep(2)
        return app
    }

    /// Navigate 마이 → 북마크 관리 → UITEST-HL row → reader.
    /// Asserts the reader nav bar is on top before returning.
    @MainActor
    private func openReader(in app: XCUIApplication) {
        app.tabBars.buttons["마이"].tap()
        sleep(1)

        let manageRow = app.buttons.containing(
            NSPredicate(format: "label CONTAINS '북마크 관리'")
        ).firstMatch
        XCTAssertTrue(manageRow.waitForExistence(timeout: 5), "북마크 관리 row not found")
        manageRow.tap()
        sleep(2)

        // Tap the UITEST-HL row; try button first, fall back to staticText.
        let bookmarkRow = app.buttons.containing(
            NSPredicate(format: "label CONTAINS 'UITEST-HL'")
        ).firstMatch
        if bookmarkRow.waitForExistence(timeout: 5) {
            bookmarkRow.tap()
        } else {
            let text = app.staticTexts["UITEST-HL"].firstMatch
            XCTAssertTrue(text.waitForExistence(timeout: 5), "UITEST-HL bookmark row not found")
            text.tap()
        }

        // Reader nav bar must be on top.
        let readerBar = app.navigationBars["The Tortoise and the Hare"]
        XCTAssertTrue(
            readerBar.waitForExistence(timeout: 8),
            "Reader nav bar not on top after tapping UITEST-HL bookmark"
        )
        sleep(1)
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Tests

    /// 1. Fresh open: default mode must be 이어보기 (.continuous).
    @MainActor
    func testReaderDefaultModeIsContinuous() throws {
        let app = launchApp()
        openReader(in: app)

        let ieobogi = app.buttons["이어보기"]
        XCTAssertTrue(
            ieobogi.waitForExistence(timeout: 5),
            "이어보기 segment not visible — mode bar not rendered"
        )
        XCTAssertTrue(
            ieobogi.isSelected,
            "Default mode is not 이어보기 — expected .continuous as first-run default"
        )
        attach(app, name: "Default mode: 이어보기 selected")
    }

    /// 2. Tap each of the 4 segments in order; assert each becomes selected and
    ///    the reader nav bar remains on top (no crash / navigation regression).
    @MainActor
    func testCycleAllFourModes() throws {
        let app = launchApp()
        openReader(in: app)

        // Ensure the mode bar is visible before cycling.
        XCTAssertTrue(
            app.buttons["이어보기"].waitForExistence(timeout: 8),
            "이어보기 segment not visible before cycling"
        )

        let modeLabels = ["문장", "문단", "페이지", "이어보기"]
        for label in modeLabels {
            let seg = app.buttons[label]
            XCTAssertTrue(seg.waitForExistence(timeout: 5), "\(label) segment not found")
            seg.tap()
            sleep(1)

            XCTAssertTrue(
                seg.isSelected,
                "\(label) segment not selected after tap"
            )
            // Reader must still be on top after each mode switch.
            XCTAssertTrue(
                app.navigationBars["The Tortoise and the Hare"].exists,
                "Reader nav bar disappeared after switching to \(label)"
            )
            attach(app, name: "Mode: \(label) selected")
        }
    }

    /// 3. In 문장 mode, swipe left on the content area; assert the reader.progress
    ///    capsule label changes (sentinel that a new sentence was shown).
    ///
    ///    Uses a real `swipeLeft()` — the user-facing gesture. UITEST-HL anchors
    ///    at b001-c002-p002-s002 (mid-book), so there is always a next sentence
    ///    to advance to.
    @MainActor
    func testSentenceModeSwipeAdvancesProgress() throws {
        let app = launchApp()
        openReader(in: app)

        // Switch to 문장 mode.
        XCTAssertTrue(app.buttons["이어보기"].waitForExistence(timeout: 8))
        let sentenceSeg = app.buttons["문장"]
        XCTAssertTrue(sentenceSeg.waitForExistence(timeout: 5), "문장 segment not found")
        sentenceSeg.tap()
        sleep(1)
        XCTAssertTrue(sentenceSeg.isSelected, "문장 mode not selected")

        // Read the combined "n / N · %" progress capsule.
        // The capsule is a Text with .accessibilityIdentifier("reader.progress").
        let progress = app.staticTexts.matching(identifier: "reader.progress").firstMatch
        XCTAssertTrue(
            progress.waitForExistence(timeout: 5),
            "reader.progress element not found in 문장 mode"
        )
        let labelBefore = progress.label
        XCTAssertFalse(labelBefore.isEmpty, "reader.progress label is unexpectedly empty")
        attach(app, name: "문장 mode: before swipe — \(labelBefore)")

        // Advance one sentence with a REAL horizontal swipe — this is the
        // user-facing navigation path and the regression guard for the
        // carousel-swallows-swipes bug (dragToSelect used to starve TabView's
        // paging recognizer; it is intentionally absent from carousel pages).
        app.swipeLeft(velocity: .fast)
        sleep(2)

        let labelAfter = app.staticTexts.matching(identifier: "reader.progress").firstMatch.label
        attach(app, name: "문장 mode: after swipe — \(labelAfter)")

        XCTAssertNotEqual(
            labelBefore,
            labelAfter,
            "reader.progress did not change after swiping left — carousel did not advance "
            + "(before: \"\(labelBefore)\", after: \"\(labelAfter)\")"
        )
    }

    /// 4. Switch to 문장 mode, terminate the app, relaunch, reopen the reader, and
    ///    assert 문장 is still selected — proves the global reader.viewMode
    ///    UserDefaults key is written and read back correctly.
    @MainActor
    func testModeSelectionPersistsAcrossRelaunch() throws {
        let app = launchApp()
        openReader(in: app)

        // Switch to 문장 and confirm.
        XCTAssertTrue(app.buttons["이어보기"].waitForExistence(timeout: 8))
        let sentenceSeg = app.buttons["문장"]
        XCTAssertTrue(sentenceSeg.waitForExistence(timeout: 5), "문장 segment not found")
        sentenceSeg.tap()
        sleep(1)
        XCTAssertTrue(sentenceSeg.isSelected, "문장 not selected before relaunch")
        attach(app, name: "Before relaunch: 문장 selected")

        // Terminate and relaunch with the same seed argument.
        app.terminate()
        sleep(1)
        app.launch()   // re-uses launchArguments set above
        sleep(2)

        // Reopen the reader.
        openReader(in: app)

        // 문장 must still be the active segment (reader.viewMode key persisted).
        let relaunched = app.buttons["문장"]
        XCTAssertTrue(
            relaunched.waitForExistence(timeout: 8),
            "문장 segment not found after relaunch"
        )
        XCTAssertTrue(
            relaunched.isSelected,
            "문장 mode not persisted after relaunch — reader.viewMode key not saved to UserDefaults"
        )
        attach(app, name: "After relaunch: 문장 still selected")

        // Reset mode to 이어보기 so subsequent tests in this run start with the
        // factory default rather than the 문장 state we deliberately persisted.
        // (XCTest shares the simulator's UserDefaults across test cases in one run.)
        let reset = app.buttons["이어보기"]
        if reset.waitForExistence(timeout: 5) { reset.tap(); sleep(1) }
    }
}
