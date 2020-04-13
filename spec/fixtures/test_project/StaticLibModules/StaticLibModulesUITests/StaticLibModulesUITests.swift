//
//  StaticLibModulesUITests.swift
//  StaticLibModulesUITests
//
//  Created by Ilya Dyakonov on 4/10/20.
//  Copyright © 2020 xcode-archive-cache. All rights reserved.
//

import XCTest

class StaticLibModulesUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        
    }

    func testExample() {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        XCTAssertEqual(XCUIApplication().staticTexts["ReportedClassName"].label, "Lottie.AnimatedButton")
    }
}
