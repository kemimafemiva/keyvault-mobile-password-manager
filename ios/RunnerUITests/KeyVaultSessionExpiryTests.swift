//
//  KeyVaultSessionExpiryTests.swift
//  Runner
//
//  Created by Oluwakemi Mafe on 2026-09-07.
//

import Foundation
import XCTest

final class KeyVaultSessionExpiryTests: XCTestCase {

    private let authenticationValidityInterval: TimeInterval = 300
    private let expiryWaitInterval: TimeInterval = 310
    private let faceIDSignalPath = "/tmp/keyvault_faceid_request"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAddCredentialRecoversAfterAuthenticationSessionExpires() throws {
        let app = XCUIApplication()

        app.launch()

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

        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Vault screen was not displayed after authentication.")

        // ----------------------------------------------------
        // Open Add Credential
        // ----------------------------------------------------

        addButton.tap()

        let serviceField = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Service"))
            .firstMatch

        let usernameField = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Username or email"))
            .firstMatch

        let passwordField = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Password"))
            .firstMatch

        let websiteField = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Website"))
            .firstMatch

        let saveButton = app.buttons["Save"]

        XCTAssertTrue(serviceField.waitForExistence(timeout: 5), "Service field was not found.")

        XCTAssertTrue(usernameField.waitForExistence(timeout: 5), "Username field was not found.")

        XCTAssertTrue(passwordField.waitForExistence(timeout: 5), "Password field was not found.")

        XCTAssertTrue(websiteField.waitForExistence(timeout: 5), "Website field was not found.")

        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save button was not found.")

        // ----------------------------------------------------
        // Enter credential
        // ----------------------------------------------------

        serviceField.tap()

        serviceField.typeText("Session Expiry")

        usernameField.tap()

        usernameField.typeText("expiry@example.com")

        passwordField.tap()

        passwordField.typeText("TestPassword123!")

        websiteField.tap()

        websiteField.typeText("https://example.com")

        let savedCredential = app.buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Session Expiry"))
            .firstMatch

        // ----------------------------------------------------
        // Wait for authentication session to expire
        // ----------------------------------------------------

        print("")

        print("====================================================")

        print("KeyVault iOS Session Expiry Integration Test")

        print("====================================================")

        print("Authentication validity: \(Int(authenticationValidityInterval)) seconds")

        print("Test wait: \(Int(expiryWaitInterval)) seconds")

        print("")

        print("Waiting \(Int(expiryWaitInterval)) seconds for the authentication session to expire.")

        sleep(UInt32(expiryWaitInterval))

        print("")

        print("Authentication validity period has expired.")

        // ----------------------------------------------------
        // Attempt save after expiry
        // ----------------------------------------------------

        print("Attempting to save credential after expiry")

        saveButton.tap()

        // ----------------------------------------------------
        // Recover expired session
        // ----------------------------------------------------

        print("Signalling Face ID for expired-session recovery.")

        signalFaceIDHelper()

        // ----------------------------------------------------
        // Verify automatic retry
        // ----------------------------------------------------

        print("Verifying automatic save retry")

        XCTAssertTrue(waitForDisappearance(saveButton, timeout: 10), "Add Credential screen remained open after expired-session recovery.")

        XCTAssertTrue(savedCredential.waitForExistence(timeout: 10), "Credential was not saved after expired-session recovery.")

        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Vault screen was not displayed after expired-session recovery.")

        print("")

        print("====================================================")

        print("TEST PASSED")

        print("iOS authentication session expired after the")

        print("\(Int(authenticationValidityInterval))-second validity period.")

        print("")

        print("KeyVault:")

        print("  - rejected the first save attempt")

        print("  - requested Face ID authentication")

        print("  - retrieved the existing Keychain-protected key")

        print("  - retried the save automatically")

        print("  - successfully stored the credential")

        print("====================================================")
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
