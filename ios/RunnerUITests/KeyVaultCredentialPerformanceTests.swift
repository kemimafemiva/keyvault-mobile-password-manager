//
//  KeyVaultCredentialPerformanceTests.swift
//  RunnerUITests
//
//  Created by Oluwakemi Mafe on 2026-08-25.
//

import Foundation
import XCTest

final class KeyVaultCredentialPerformanceTests: XCTestCase {
    private let trials = 10
    private let faceIDSignalPath = "/tmp/keyvault_faceid_request"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCredentialOperations() throws {
        let app = XCUIApplication()

        app.launch()

        var addTimes: [TimeInterval] = []
        var retrievalTimes: [TimeInterval] = []
        var editTimes: [TimeInterval] = []
        var deleteTimes: [TimeInterval] = []

        let lockedTitle = app.staticTexts["KeyVault is locked"]
        let unlockButton = app.buttons["Unlock"]
        let addButton = app.buttons["Add credential"]

        // ----------------------------------------------------
        // Initial vault authentication
        // ----------------------------------------------------

        XCTAssertTrue(lockedTitle.waitForExistence(timeout: 5), "KeyVault did not start in the locked state.")
        XCTAssertTrue(unlockButton.waitForExistence(timeout: 5), "Unlock button was not found.")

        unlockButton.tap()

        signalFaceIDHelper()

        XCTAssertTrue(waitForDisappearance(lockedTitle, timeout: 10), "KeyVault could not be unlocked.")
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Vault screen was not displayed after authentication." )

        // ----------------------------------------------------
        // Credential-operation trials
        // ----------------------------------------------------
        for trial in 1...trials {

            print("")
            print("=== Credential Trial \(trial) ===")

            let service = "Performance Test \(trial)"
            let username = "test\(trial)@example.com"
            let updatedUsername = "updated\(trial)@example.com"

            // ====================================================
            // ADD
            // ====================================================
            XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add credential button was not found for trial \(trial).")

            addButton.tap()

            let serviceField = app.descendants(matching: .any)
                .matching(NSPredicate(format:"label BEGINSWITH %@", "Service"))
                .firstMatch
            let usernameField = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@", "Username or email"))
                .firstMatch
            let passwordField = app.descendants( matching: .any)
                .matching(NSPredicate(format: "label == %@", "Password"))
                .firstMatch
            let websiteField = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS[c] %@", "Website"))
                .firstMatch
            let saveButton = app.buttons["Save"]

            XCTAssertTrue(serviceField.waitForExistence(timeout: 5), "Service field was not found during trial \(trial).")
            XCTAssertTrue(usernameField.waitForExistence(timeout: 5), "Username field was not found during trial \(trial).")
            XCTAssertTrue(passwordField.waitForExistence(timeout: 5),"Password field was not found during trial \(trial).")
            XCTAssertTrue(websiteField.waitForExistence(timeout: 5), "Website field was not found during trial \(trial).")
            XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save button was not found during trial \(trial).")

            serviceField.tap()
            serviceField.typeText(service)

            usernameField.tap()
            usernameField.typeText(username)

            passwordField.tap()
            passwordField.typeText("TestPassword123!")

            websiteField.tap()
            websiteField.typeText("https://example.com")

            let savedCredential = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", service)).firstMatch
            let addStartTime = CFAbsoluteTimeGetCurrent()

            saveButton.tap()

            // Add no longer requires another
            // biometric authentication.
            XCTAssertTrue(savedCredential.waitForExistence(timeout: 10), "Saved credential did not appear during trial \(trial).")

            let addDuration = CFAbsoluteTimeGetCurrent() - addStartTime
            addTimes.append(addDuration)
            print(String(format: "ADD_RESULT Trial %d: %.3f s", trial, addDuration))

            // ====================================================
            // RETRIEVE
            // ====================================================
            let credentialToOpen = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", service)).firstMatch

            XCTAssertTrue(credentialToOpen.waitForExistence(timeout: 5), "Credential row was not found before retrieval during trial \(trial).")

            let editButton = app.buttons["Edit"]
            let retrievalStartTime = CFAbsoluteTimeGetCurrent()

            credentialToOpen.tap()

            XCTAssertTrue(editButton.waitForExistence(timeout: 5), "Credential details did not appear during trial \(trial).")

            let retrievalDuration = CFAbsoluteTimeGetCurrent() - retrievalStartTime
            retrievalTimes.append(retrievalDuration)

            print(String(format: "RETRIEVAL_RESULT Trial %d: %.3f s", trial, retrievalDuration))

            // ====================================================
            // EDIT
            // ====================================================
            editButton.tap()

            let editUsernameField = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@", "Username or email"))
                .firstMatch
            let editSaveButton = app.buttons["Save"]

            XCTAssertTrue(editUsernameField.waitForExistence(timeout: 5), "Username field was not found on Edit Credential screen during trial \(trial).")
            XCTAssertTrue(editSaveButton.waitForExistence(timeout: 5), "Save button was not found on Edit Credential screen during trial \(trial).")

            editUsernameField.tap()

            editUsernameField.press(forDuration: 1.0)

            let selectAll = app.menuItems["Select All"]

            XCTAssertTrue(selectAll.waitForExistence(timeout: 5), "Select All was not displayed for the username field during trial \(trial).")

            selectAll.tap()
            editUsernameField.typeText(updatedUsername)

            app.keyboards.buttons["done"].tap()

            let updatedCredential = app.buttons.matching(NSPredicate(format:"label CONTAINS[c] %@", updatedUsername)).firstMatch
            let editStartTime = CFAbsoluteTimeGetCurrent()

            editSaveButton.tap()

            // Editing an existing credential
            // deliberately requires reauthentication.
            signalFaceIDHelper()

            sleep(3)

            XCTAssertTrue(updatedCredential.waitForExistence( timeout: 10), "Updated credential did not appear in the vault during trial \(trial).")
            XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Vault screen did not appear after editing during trial \(trial).")

            let editDuration = CFAbsoluteTimeGetCurrent() - editStartTime

            editTimes.append(editDuration)

            print(String(format: "EDIT_RESULT Trial %d: %.3f s", trial, editDuration))

            // ====================================================
            // DELETE
            // ====================================================

            // Edit now returns directly to the vault.
            // Reopen the updated credential before deleting it.
            let credentialToDelete = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", updatedUsername)).firstMatch

            XCTAssertTrue(credentialToDelete.waitForExistence(timeout: 5),"Updated credential was not found before deletion during trial \(trial).")

            credentialToDelete.tap()

            let deleteButton = app.buttons["Delete"]

            XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "Delete button was not found during trial \(trial).")

            deleteButton.tap()

            let deleteConfirmationTitle = app.staticTexts["Delete credential?"]
            let confirmDeleteButton = app.buttons["Delete"]

            XCTAssertTrue(deleteConfirmationTitle.waitForExistence(timeout: 5),"Delete confirmation dialog was not displayed during trial \(trial).")
            XCTAssertTrue(confirmDeleteButton.waitForExistence(timeout: 5),"Delete confirmation button was not found during trial \(trial).")

            let detailsTitle = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@", service))
                .firstMatch

            let deleteStartTime = CFAbsoluteTimeGetCurrent()
            confirmDeleteButton.tap()

            // Deleting an existing credential
            // deliberately requires reauthentication.
            signalFaceIDHelper()

            XCTAssertTrue(waitForDisappearance(detailsTitle, timeout: 10 ), "Credential details did not disappear after deletion during trial \(trial)." )
            XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Vault screen did not appear after deletion during trial \(trial).")

            let deleteDuration = CFAbsoluteTimeGetCurrent() - deleteStartTime
            deleteTimes.append(deleteDuration)

            print(String(format: "DELETE_RESULT Trial %d: %.3f s", trial, deleteDuration))
            print("=== Trial \(trial) complete ===")
        }

        // ----------------------------------------------------
        // Performance statistics
        // ----------------------------------------------------
        print("")
        print("========== CREDENTIAL PERFORMANCE ==========")
        printStatistics(name: "ADD", values: addTimes)
        printStatistics(name: "RETRIEVE", values: retrievalTimes)
        printStatistics(name: "EDIT", values: editTimes)
        printStatistics(name: "DELETE", values: deleteTimes)
        print("============================================")
    }

    // MARK: - Performance Statistics

    private func printStatistics(name: String, values: [TimeInterval]) {
        guard !values.isEmpty else {
            return
        }

        let sorted = values.sorted()
        let mean = values.reduce(0, +) / Double(values.count)
        let minimum = sorted.first!
        let maximum = sorted.last!
        let median: Double

        if sorted.count % 2 == 0 {
            let middle = sorted.count / 2
            median = (sorted[middle - 1] + sorted[middle]) / 2
        } else {
            median = sorted[sorted.count / 2]
        }

        let variance = values
                .map {pow($0 - mean, 2)}
                .reduce(0, +) / Double(values.count)
        let standardDeviation = sqrt(variance)

        print("")
        print("---------- \(name) ----------")

        for (index, duration) in values.enumerated() {
            print(String(format: "Trial %d: %.3f s", index + 1, duration))
        }

        print(String(format:"Mean: %.3f s", mean))
        print(String(format: "Median: %.3f s", median))
        print(String(format: "Minimum: %.3f s", minimum))
        print(String(format: "Maximum: %.3f s", maximum))
        print(String(format: "Std. Dev.: %.3f s", standardDeviation))
    }

    // MARK: - Face ID Helper

    private func signalFaceIDHelper() {
        FileManager.default.createFile(atPath: faceIDSignalPath, contents: nil)
    }

    // MARK: - UI Helpers

    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)

        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}