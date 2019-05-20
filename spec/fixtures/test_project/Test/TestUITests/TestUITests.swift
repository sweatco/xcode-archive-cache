//
//  TestUITests.swift
//  TestUITests
//
//  Created by Ilya Dyakonov on 5/20/19.
//  Copyright © 2019 xcode-archive-cache. All rights reserved.
//

import XCTest

class TestUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false

        XCUIApplication().launch()
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testAppRunning() {
        XCUIApplication()/*@START_MENU_TOKEN@*/.buttons["TapMeButton"]/*[[".buttons[\"Tap me\"]",".buttons[\"TapMeButton\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
    }
}
