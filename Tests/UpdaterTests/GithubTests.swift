//
//  GithubTests.swift
//  Updater
//
//  Created by Serhiy Mytrovtsiy on 20/09/2021.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2021 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation

import XCTest
@testable import Updater

final class GithubTests: XCTestCase {
    func testStatsVersion() {
        let gh = Updater.Github(user: "exelban", repo: "Stats", asset: "Stats.dmg")
        let completedExpectation = expectation(description: "Completed")
        
        gh.latest() { release, error in
            XCTAssertNil(error)
            XCTAssertNotNil(release)
            XCTAssertTrue(release!.url.contains("https://github.com/exelban/stats/releases/download/"))
            completedExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testNoAsset() {
        let gh = Updater.Github(user: "exelban", repo: "Stats", asset: "test.dmg")
        let completedExpectation = expectation(description: "Completed")
        
        gh.latest() { release, error in
            XCTAssertNotNil(error)
            XCTAssertNil(release)
            completedExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testNoRelease() {
        let gh = Updater.Github(user: "exelban", repo: "telemetry", asset: "test")
        let completedExpectation = expectation(description: "Completed")
        
        gh.latest() { release, error in
            XCTAssertNotNil(error)
            XCTAssertNil(release)
            completedExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
}
