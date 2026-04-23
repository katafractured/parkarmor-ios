import XCTest

final class ScreenshotTests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["-ScreenshotMode", "seedData"]
        app.launch()
    }

    func testParkingPinPlaced() throws {
        // Wait for home screen with parked car pin
        let mapView = app.maps.firstMatch
        XCTAssertTrue(mapView.waitForExistence(timeout: 5))

        let parkedLabel = app.staticTexts["Parked 2 min ago"]
        XCTAssertTrue(parkedLabel.waitForExistence(timeout: 3))

        snapshot("01_parking_pin_placed")
    }

    func testTimerRunning() throws {
        // Wait for timer view with countdown
        let timerText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '28:47'")).firstMatch
        XCTAssertTrue(timerText.waitForExistence(timeout: 5))

        let returnButton = app.buttons["Return to Car"]
        XCTAssertTrue(returnButton.exists)

        snapshot("02_timer_running")
    }

    func testPhotoAndNote() throws {
        // Scroll or navigate to photo + note section
        let noteText = app.staticTexts["Level 3B, near elevator"]
        XCTAssertTrue(noteText.waitForExistence(timeout: 5), "Note should be visible")

        let photoElement = app.images.firstMatch
        XCTAssertTrue(photoElement.exists)

        snapshot("03_photo_and_note")
    }

    func testCarPlayDemo() throws {
        // CarPlay may not be available in simulator; graceful skip
        let carPlayIndicator = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'CarPlay'")).firstMatch
        if carPlayIndicator.exists {
            snapshot("04_carplay_demo")
        } else {
            // Fall back to Settings
            let settingsTab = app.tabBars.buttons["Settings"]
            if settingsTab.exists {
                settingsTab.tap()
                snapshot("04_settings_fallback")
            }
        }
    }

    func testSettings() throws {
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 3))
        settingsTab.tap()

        // Verify Pro features toggle visible
        let proToggle = app.switches.containing(NSPredicate(format: "label CONTAINS 'Pro'")).firstMatch
        XCTAssertTrue(proToggle.waitForExistence(timeout: 3))

        let adRemovalText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Remove Ads'")).firstMatch
        XCTAssertTrue(adRemovalText.waitForExistence(timeout: 2))

        snapshot("05_settings")
    }
}
