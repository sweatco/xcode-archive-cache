//
//  SiblingProjectsUITests.swift
//  SiblingProjectsUITests
//
//  Created by Ilya Dyakonov on 14.09.2022.
//

import XCTest

class SiblingProjectsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIApplication().launch()
    }

    func testExample() throws {
        XCTAssertEqual(XCUIApplication().staticTexts["Label"].label, "Here is something")
    }
}
