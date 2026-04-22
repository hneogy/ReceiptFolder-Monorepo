import XCTest

/// Golden-flow UI tests for Receipt Folder.
///
/// The app honours a `-UITests` launch argument: in-memory SwiftData, onboarding
/// pre-completed, biometric lock disabled, TipKit suppressed, draft storage
/// cleared. Each test starts from a clean state.
final class ReceiptFolderUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITests"]
        app.launch()
    }

    // MARK: - 1. Launch

    func testAppLaunchesToVault() throws {
        let receiptMasthead = app.staticTexts["Receipt"]
        XCTAssertTrue(receiptMasthead.waitForExistence(timeout: 5),
                      "Vault masthead missing. Hierarchy:\n\(app.debugDescription)")

        XCTAssertTrue(app.buttons["tab.vault"].exists, "Vault tab missing")
        XCTAssertTrue(app.buttons["tab.expiring"].exists, "Expiring tab missing")
        XCTAssertTrue(app.buttons["tab.scan"].exists, "Scan tab missing")
        XCTAssertTrue(app.buttons["tab.insights"].exists, "Insights tab missing")
        XCTAssertTrue(app.buttons["tab.settings"].exists, "Settings tab missing")
    }

    // MARK: - 2. Add a receipt manually

    func testAddReceiptByHand() throws {
        addReceipt(name: "Test Item", store: "Test Store")

        XCTAssertTrue(rowExists(productName: "Test Item", timeout: 5),
                      "Added receipt did not appear in Vault")
    }

    // MARK: - 3. Tab navigation

    func testTabBarNavigation() throws {
        app.buttons["tab.expiring"].tap()
        XCTAssertTrue(app.staticTexts["Expiring"].waitForExistence(timeout: 3),
                      "Expiring masthead not shown after tab tap")

        app.buttons["tab.insights"].tap()
        XCTAssertTrue(app.staticTexts["Ledger"].waitForExistence(timeout: 3),
                      "Insights (Ledger) masthead not shown after tab tap")

        app.buttons["tab.settings"].tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 3),
                      "Settings masthead not shown after tab tap")

        app.buttons["tab.vault"].tap()
        XCTAssertTrue(app.staticTexts["Receipt"].waitForExistence(timeout: 3),
                      "Vault masthead not shown after returning to tab")
    }

    // MARK: - 4. Settings sections render

    func testSettingsShowsSections() throws {
        app.buttons["tab.settings"].tap()

        XCTAssertTrue(app.staticTexts["APPEARANCE"].waitForExistence(timeout: 3),
                      "Appearance eyebrow missing")

        let settingsScroll = app.scrollViews.firstMatch
        if settingsScroll.exists {
            settingsScroll.swipeUp()
            settingsScroll.swipeUp()
        }

        XCTAssertTrue(app.staticTexts["EXPORT DATA"].waitForExistence(timeout: 3),
                      "Export-data row missing from Settings")
    }

    // MARK: - 5. Expiring empty state

    func testExpiringEmptyState() throws {
        app.buttons["tab.expiring"].tap()
        XCTAssertTrue(app.staticTexts["All clear."].waitForExistence(timeout: 3),
                      "Expiring empty-state headline missing")
    }

    // MARK: - 6. Mark a receipt as returned

    func testMarkAsReturned() throws {
        addReceipt(name: "Returned Kettle", store: "Kitchen Store")
        XCTAssertTrue(rowExists(productName: "Returned Kettle", timeout: 5))

        openDetail(productName: "Returned Kettle")

        // Toolbar ellipsis menu → "Mark as Returned"
        app.buttons["button.itemActions"].tap()
        let markReturned = app.buttons["Mark as Returned"]
        XCTAssertTrue(markReturned.waitForExistence(timeout: 3),
                      "Mark-as-Returned menu item missing")
        markReturned.tap()

        // Detail view shows the rotated "RETURNED" stamp when item is returned.
        XCTAssertTrue(app.staticTexts["RETURNED"].waitForExistence(timeout: 3),
                      "RETURNED stamp not shown after marking returned")
    }

    // MARK: - 7. Archive a receipt (via detail menu)

    func testArchiveFromDetailMenu() throws {
        addReceipt(name: "Archived Lamp", store: "Home Goods")
        XCTAssertTrue(rowExists(productName: "Archived Lamp", timeout: 5))

        openDetail(productName: "Archived Lamp")

        app.buttons["button.itemActions"].tap()
        let archive = app.buttons["Archive"]
        XCTAssertTrue(archive.waitForExistence(timeout: 3), "Archive menu item missing")
        archive.tap()

        // Detail view dismisses back to Vault.
        XCTAssertTrue(app.staticTexts["Receipt"].waitForExistence(timeout: 5),
                      "Did not return to Vault after archive")

        // The row should no longer appear in Vault (Vault query filters !isArchived).
        let row = app.otherElements["row.Archived Lamp"]
        XCTAssertFalse(row.exists, "Archived item should not be listed in Vault")
    }

    // MARK: - 8. Claim a warranty

    func testClaimWarranty() throws {
        // Default warranty is 1 year when no policy matches, so the "Mark Warranty Claimed"
        // menu item will be present.
        addReceipt(name: "Headphones", store: "Audio Shop")
        XCTAssertTrue(rowExists(productName: "Headphones", timeout: 5))

        openDetail(productName: "Headphones")

        app.buttons["button.itemActions"].tap()
        let claim = app.buttons["Mark Warranty Claimed"]
        XCTAssertTrue(claim.waitForExistence(timeout: 3),
                      "Warranty-claim menu item missing — is default warranty still > 0?")
        claim.tap()

        // After claim, the menu item should be gone. Re-open menu and assert.
        app.buttons["button.itemActions"].tap()
        XCTAssertFalse(app.buttons["Mark Warranty Claimed"].waitForExistence(timeout: 2),
                       "Warranty-claim option should disappear after claiming")
        // Dismiss the menu by tapping outside.
        app.tap()
    }

    // MARK: - 9. Export CSV

    func testExportCSV() throws {
        // Need at least one item so export has content.
        addReceipt(name: "Exported Mug", store: "Cafe")

        app.buttons["tab.settings"].tap()

        let settingsScroll = app.scrollViews.firstMatch
        XCTAssertTrue(settingsScroll.waitForExistence(timeout: 3))
        // Scroll until Export row is hit-testable.
        let exportRow = app.buttons["button.exportData"]
        var scrolls = 0
        while !exportRow.isHittable && scrolls < 6 {
            settingsScroll.swipeUp()
            scrolls += 1
        }
        XCTAssertTrue(exportRow.isHittable, "Export row never became hittable")
        exportRow.tap()

        // Confirmation dialog with CSV / JSON / Cancel buttons.
        let csvButton = app.buttons["CSV (Spreadsheet)"]
        XCTAssertTrue(csvButton.waitForExistence(timeout: 3),
                      "CSV option missing from export dialog")
        csvButton.tap()

        // Two things to verify, both resilient to iOS version differences:
        //  1. The dialog dismisses (CSV button disappears) — proves runExport ran.
        //  2. No failure alert surfaces — proves the write succeeded.
        let notPresent = NSPredicate(format: "exists == false")
        let csvGone = expectation(for: notPresent, evaluatedWith: csvButton, handler: nil)
        wait(for: [csvGone], timeout: 5)

        XCTAssertFalse(app.alerts["Couldn't export"].exists,
                       "Export failure alert appeared — CSV write did not succeed")
    }

    // MARK: - 10. Discard draft clears restored state

    func testDiscardDraftDoesNotResurrect() throws {
        // Open the add sheet, fill a field, cancel → discard → reopen and assert no prompt.
        app.buttons["button.addFirstReceipt"].tap()
        app.buttons["button.enterByHand"].tap()

        let nameField = app.textFields["field.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText("Discarded")

        // Cancel triggers the confirmation dialog (because review step has content).
        app.buttons["Cancel"].tap()
        let discard = app.buttons["Discard"]
        XCTAssertTrue(discard.waitForExistence(timeout: 3),
                      "Discard-draft confirmation dialog missing")
        discard.tap()

        // Reopen the add sheet: the ghost-draft regression would show a "Continue
        // where you left off?" alert. Asserting its absence guards against that bug.
        app.buttons["button.addFirstReceipt"].tap()
        XCTAssertFalse(app.staticTexts["Continue where you left off?"].waitForExistence(timeout: 2),
                       "Discarded draft was resurrected on next open")
    }

    // MARK: - Helpers

    /// Navigates the empty-state → add sheet → manual flow and saves a receipt.
    private func addReceipt(name: String, store: String) {
        // Tap whichever entry point is currently visible. Empty state offers
        // "Add your first receipt"; populated vault uses the tab-bar Scan button.
        let emptyButton = app.buttons["button.addFirstReceipt"]
        if emptyButton.waitForExistence(timeout: 2) {
            emptyButton.tap()
        } else {
            app.buttons["tab.scan"].tap()
        }

        app.buttons["button.enterByHand"].tap()

        let nameField = app.textFields["field.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText(name)

        let storeField = app.textFields["field.store"]
        XCTAssertTrue(storeField.waitForExistence(timeout: 3))
        storeField.tap()
        storeField.typeText(store)

        if app.keyboards.element.exists {
            app.typeText("\n")
        }

        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3))
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()
    }

    /// Whether a Vault row for the given product exists.
    private func rowExists(productName: String, timeout: TimeInterval = 5) -> Bool {
        let row = app.otherElements["row.\(productName)"]
        if row.waitForExistence(timeout: timeout) { return true }
        // Fallback — some row rendering surfaces only the static text, not the
        // combined accessibilityElement.
        return app.staticTexts[productName].waitForExistence(timeout: 1)
    }

    /// Taps a row to push the detail view. Works whether the row is surfaced as
    /// `otherElements` (accessibilityElement) or just staticText.
    private func openDetail(productName: String) {
        let row = app.otherElements["row.\(productName)"]
        if row.exists {
            row.tap()
        } else {
            app.staticTexts[productName].tap()
        }
    }
}
