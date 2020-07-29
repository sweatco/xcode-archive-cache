//
//  IntersectingBuildGraphsUITests.swift
//  IntersectingBuildGraphsUITests
//
//  Created by Ilya Dyakonov on 7/29/20.
//  Copyright © 2020 xcode-archive-test. All rights reserved.
//

import XCTest

class IntersectingBuildGraphsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaucnch() throws {
        let app = XCUIApplication()
        app.launch()
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTOSSignpostMetric.applicationLaunch]) {
                XCUIApplication().launch()
            }
        }
    }
}
