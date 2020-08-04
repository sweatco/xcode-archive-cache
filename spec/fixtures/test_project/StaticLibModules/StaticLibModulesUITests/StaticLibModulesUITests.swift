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

    func testLottiePresence() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertEqual(XCUIApplication().staticTexts["ReportedClassName"].label, "Lottie.AnimatedButton")
    }
}
