//
//  LexisUITests.swift
//  LexisUITests
//
//  Created by Aaron Goldman on 3/28/26.
//

import XCTest

final class LexisUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testInvestorDemoJourney() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-lexisInvestorDemo"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Apricity"].waitForExistence(timeout: 5.0))
        Thread.sleep(forTimeInterval: 1.2)

        app.tabBars.buttons["Archive"].tap()
        XCTAssertTrue(app.staticTexts["past words"].waitForExistence(timeout: 3.0))
        Thread.sleep(forTimeInterval: 0.8)

        app.buttons["Apricity"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 3.0))
        Thread.sleep(forTimeInterval: 1.2)
        app.buttons["Done"].tap()

        app.tabBars.buttons["Quiz"].tap()
        XCTAssertTrue(app.staticTexts["what does this word mean?"].waitForExistence(timeout: 3.0))
        Thread.sleep(forTimeInterval: 0.8)

        app.buttons["The warmth of the sun in winter."].tap()
        XCTAssertTrue(app.staticTexts["Correct — well done"].waitForExistence(timeout: 3.0))
        Thread.sleep(forTimeInterval: 1.1)

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["lock screen preview"].waitForExistence(timeout: 3.0))
        Thread.sleep(forTimeInterval: 1.2)
    }

    @MainActor
    func testAppLaunchAndNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        
        let archiveTab = app.tabBars.buttons["Archive"]
        XCTAssertTrue(archiveTab.waitForExistence(timeout: 5.0), "Archive tab should be present")
        
        archiveTab.tap()
        
        let settingsTab = app.tabBars.buttons["Settings"]
        settingsTab.tap()
        
        let previewText = app.staticTexts["lock screen preview"]
        XCTAssertTrue(previewText.waitForExistence(timeout: 2.0))
        
        let alert = app.alerts["Apple Intelligence Disabled"]
        if alert.exists {
            alert.buttons["Dismiss"].tap()
        }
    }

    @MainActor
    func testQuizLockScreen() throws {
        let app = XCUIApplication()
        app.launch()
        
        let alert = app.alerts["Apple Intelligence Disabled"]
        if alert.waitForExistence(timeout: 3.0) {
            alert.buttons["Dismiss"].tap()
        }

        let quizTab = app.tabBars.buttons["Quiz"]
        XCTAssertTrue(quizTab.waitForExistence(timeout: 5.0))
        quizTab.tap()
        
        let lockedText = app.staticTexts["Quiz not yet available"]
        let questionText = app.staticTexts["what does this word mean?"]
        let noWordText = app.staticTexts["Today's word isn't ready yet."]
        let completedText = app.staticTexts["today's quiz"]
        
        let foundSomething = lockedText.waitForExistence(timeout: 2.0) || 
                             questionText.exists || 
                             noWordText.exists ||
                             completedText.exists
                             
        XCTAssertTrue(foundSomething, "Quiz tab should load one of its specific states")
    }
}
