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
    func testGithubStatsVersion() {
        let gh = Updater.Github(user: "exelban", repo: "Stats", asset: "Stats.dmg", session: ReleaseProtocol.session())
        let completedExpectation = expectation(description: "Completed")
        
        gh.latest() { release, error in
            XCTAssertNil(error)
            XCTAssertNotNil(release)
            XCTAssertEqual(release?.url, "https://github.com/exelban/stats/releases/download/v2.0/Stats.dmg")
            completedExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testGithubNoAsset() {
        let gh = Updater.Github(user: "exelban", repo: "Stats", asset: "test.dmg", session: ReleaseProtocol.session())
        let completedExpectation = expectation(description: "Completed")
        
        gh.latest() { release, error in
            XCTAssertNotNil(error)
            XCTAssertNil(release)
            completedExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testGithubNoRelease() {
        let gh = Updater.Github(user: "exelban", repo: "telemetry", asset: "test", session: ReleaseProtocol.session())
        let completedExpectation = expectation(description: "Completed")
        
        gh.latest() { release, error in
            XCTAssertNotNil(error)
            XCTAssertNil(release)
            completedExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
}
