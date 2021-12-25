//
//  File.swift
//  
//
//  Created by Serhiy Mytrovtsiy on 23/12/2021.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2021 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation

import XCTest
@testable import Updater

final class ServerTests: XCTestCase {
    func testServerStatsVersion() {
        let gh = Updater.Server(url: URL(string: "https://api.serhiy.io/v1/stats/latest")!, asset: "Stats.dmg")
        let completedExpectation = expectation(description: "Completed")
        
        gh.latest() { release, error in
            XCTAssertNil(error)
            XCTAssertNotNil(release)
            if let release = release {
                XCTAssertTrue(release.url.contains("https://github.com/exelban/stats/releases/download/"))
            }
            completedExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testServerNoAsset() {
        let gh = Updater.Server(url: URL(string: "https://api.serhiy.io/v1/stats/latest")!, asset: "test.dmg")
        let completedExpectation = expectation(description: "Completed")
        
        gh.latest() { release, error in
            XCTAssertNotNil(error)
            XCTAssertNil(release)
            completedExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testServerNotFound() {
        let gh = Updater.Server(url: URL(string: "https://api.serhiy.io/v1/stats/not-found")!, asset: "Stats.dmg")
        let completedExpectation = expectation(description: "Completed")
        
        gh.latest() { release, error in
            XCTAssertNotNil(error)
            XCTAssertNil(release)
            completedExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
}
