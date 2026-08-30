//
//  KeyVaultAuthenticationPerformanceTests.swift
//  RunnerUITests
//
//  Created by Oluwakemi Mafe on 2026-08-24.
//

import Foundation
import XCTest

final class KeyVaultAuthenticationPerformanceTests: XCTestCase {
    private let trials = 10
    private let faceIDSignalPath = "/tmp/keyvault_faceid_request"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAutomatedAuthenticationTrials() throws {
        var authenticationTimes: [TimeInterval] = []
        let app = XCUIApplication()

        app.launch()

        let lockedTitle = app.staticTexts["KeyVault is locked"]
        let unlockButton = app.buttons["Unlock"]
        let addButton = app.buttons["Add credential"]

        XCTAssertTrue(lockedTitle.waitForExistence(timeout: 5), "KeyVault did not start in the locked state.")
        XCTAssertTrue(unlockButton.waitForExistence(timeout: 5), "Unlock button was not found.")

        for trial in 1...trials {
            print("")
            print( "=== Authentication Trial \(trial) ===")

            XCTAssertTrue(lockedTitle.waitForExistence(timeout: 5), "KeyVault was not locked before trial \(trial).")
            XCTAssertTrue(unlockButton.waitForExistence(timeout: 5), "Unlock button not found for trial \(trial).")

            let startTime = CFAbsoluteTimeGetCurrent()

            unlockButton.tap()
            signalFaceIDHelper()

            XCTAssertTrue(waitForDisappearance(lockedTitle,timeout: 10), "KeyVault did not unlock during trial \(trial).")
            XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Vault screen was not displayed after authentication during trial \(trial).")

            let endTime = CFAbsoluteTimeGetCurrent()
            let duration = endTime - startTime

            authenticationTimes.append(duration)
            print( String(format: "AUTHENTICATION_RESULT Trial %d: %.3f s", trial,duration))

            // ----------------------------------------------------
            // Lock the vault before the next trial
            // ----------------------------------------------------

            let lockButton = app.buttons["Lock vault"]

            XCTAssertTrue(lockButton.waitForExistence(timeout: 5), "Lock button not found during trial \(trial)." )

            lockButton.tap()

            XCTAssertTrue(lockedTitle.waitForExistence(timeout: 5), "KeyVault did not return to the locked state after trial \(trial).")
            XCTAssertTrue(unlockButton.waitForExistence(timeout: 5),"Unlock button did not return after trial \(trial).")

            print("=== Trial \(trial) complete ===")
        }

        // ----------------------------------------------------
        // Performance statistics
        // ----------------------------------------------------

        let sorted = authenticationTimes.sorted()
        let mean = authenticationTimes.reduce(0, +) / Double(authenticationTimes.count)
        let minimum = sorted.first!
        let maximum = sorted.last!
        let median: Double

        if sorted.count % 2 == 0 {
            let middle = sorted.count / 2

            median = (sorted[middle - 1] + sorted[middle]) / 2
        } else {
            median = sorted[sorted.count / 2]
        }

        let variance = authenticationTimes
                .map {pow($0 - mean, 2)}
                .reduce(0,+) / Double(authenticationTimes.count)

        let standardDeviation = sqrt(variance)

        print("")
        print("========== AUTHENTICATION PERFORMANCE ==========")

        for (index, duration) in authenticationTimes.enumerated() {
            print(String(format: "Trial %d: %.3f s", index + 1, duration))
        }

        print(String(format: "Mean: %.3f s", mean))
        print(String(format: "Median: %.3f s", median))
        print(String(format: "Minimum: %.3f s", minimum))
        print(String(format: "Maximum: %.3f s", maximum))
        print(String(format: "Std. Dev.: %.3f s", standardDeviation))
        print("================================================")
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