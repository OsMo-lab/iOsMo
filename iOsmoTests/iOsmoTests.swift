//
//  iOsmoTests.swift
//  iOsmoTests
//
//  Created by Olga Grineva on 07/12/14.
//  Copyright (c) 2014 Olga Grineva. All rights reserved.
//

import UIKit
import XCTest
import Foundation

class iOsmoTests: XCTestCase {
    
    private var launched = false
    let app = XCUIApplication()
    
    override func setUp() {
        super.setUp()
        
        continueAfterFailure = false
        launchIfNecessary()
    }
    
    private func launchIfNecessary() {
        if !launched {
            launched = true
            app.launchArguments = ["https://osmo.mobi/g/xynspxrncxiodsoh"]
            app.launchEnvironment = ["url":"https://osmo.mobi/g/xynspxrncxiodsoh"]
            app.launch()
        }
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        XCTAssert(true, "Pass")
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure() {
            // Put the code you want to measure the time of here.
        }
    }
    
}
