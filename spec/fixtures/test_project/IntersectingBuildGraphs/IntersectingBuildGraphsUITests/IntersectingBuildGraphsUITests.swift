//
//  IntersectingBuildGraphsUITests.swift
//  IntersectingBuildGraphsUITests
//
//  Created by Ilya Dyakonov on 7/29/20.
//  Copyright © 2020 xcode-archive-test. All rights reserved.
//

import XCTest

class IntersectingBuildGraphsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testAppLaunch() {
        let app = XCUIApplication()
        app.launch()
    }
}
