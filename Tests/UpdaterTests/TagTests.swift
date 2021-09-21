//
//  TagTests.swift
//  Updater
//
//  Created by Serhiy Mytrovtsiy on 20/09/2021.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2021 Serhiy Mytrovtsiy. All rights reserved.
//

import XCTest
@testable import Updater

final class TagTests: XCTestCase {
    func testEmptyTag() {
        let tag = Updater.Tag("")
        XCTAssertEqual(tag.major, 0)
        XCTAssertEqual(tag.minor, 0)
        XCTAssertEqual(tag.patch, 0)
        XCTAssertNil(tag.beta)
    }
    
    func testTagOnlyMajor() {
        let tag = Updater.Tag("1")
        XCTAssertEqual(tag.major, 1)
        XCTAssertEqual(tag.minor, 0)
        XCTAssertEqual(tag.patch, 0)
        XCTAssertNil(tag.beta)
    }
    
    func testTagOnlyMajorAndMinor() {
        let tag = Updater.Tag("1.2")
        XCTAssertEqual(tag.major, 1)
        XCTAssertEqual(tag.minor, 2)
        XCTAssertEqual(tag.patch, 0)
        XCTAssertNil(tag.beta)
    }
    
    func testTag() {
        let tag = Updater.Tag("1.2.3")
        XCTAssertEqual(tag.major, 1)
        XCTAssertEqual(tag.minor, 2)
        XCTAssertEqual(tag.patch, 3)
        XCTAssertNil(tag.beta)
    }
    
    func testTagWithV() {
        let tag = Updater.Tag("v1.2.3")
        XCTAssertEqual(tag.major, 1)
        XCTAssertEqual(tag.minor, 2)
        XCTAssertEqual(tag.patch, 3)
        XCTAssertNil(tag.beta)
    }
    
    func testTagWithBeta() {
        let tag = Updater.Tag("1.2.3-beta")
        XCTAssertEqual(tag.major, 1)
        XCTAssertEqual(tag.minor, 2)
        XCTAssertEqual(tag.patch, 3)
        XCTAssertEqual(tag.beta, 0)
    }
    
    func testTagWithBeta1() {
        let tag = Updater.Tag("1.2.3-beta1")
        XCTAssertEqual(tag.major, 1)
        XCTAssertEqual(tag.minor, 2)
        XCTAssertEqual(tag.patch, 3)
        XCTAssertEqual(tag.beta, 1)
    }
    
    func testCompareTags() {
        XCTAssertTrue(Updater.Tag("0.0.0") < Updater.Tag("v0.0.1"))
        XCTAssertTrue(Updater.Tag("0.0.1") > Updater.Tag("v0.0.0"))
        XCTAssertTrue(Updater.Tag("v1.2.3") < Updater.Tag("v1.2.4"))
        XCTAssertTrue(Updater.Tag("v1.2.4") == Updater.Tag("v1.2.4"))
        XCTAssertTrue(Updater.Tag("v1.2.4") > Updater.Tag("v1.2.3"))
        
        XCTAssertTrue(Updater.Tag("v0.0.0") < Updater.Tag("0.0.1"))
        XCTAssertTrue(Updater.Tag("v1.0.0") > Updater.Tag("0.0.1"))
        XCTAssertTrue(Updater.Tag("v0.53.0") > Updater.Tag("0.0.1"))
        XCTAssertTrue(Updater.Tag("v0.53.0") < Updater.Tag("1.0.1"))
        
        XCTAssertTrue(Updater.Tag("v15.53.0") > Updater.Tag("14.54.5"))
        XCTAssertFalse(Updater.Tag("v15.53.0") < Updater.Tag("14.54.5"))
    }
    
    func testCompareOneBetaTags() {
        XCTAssertTrue(Updater.Tag("0.0.0-beta1") < Updater.Tag("0.0.0"))
        XCTAssertTrue(Updater.Tag("0.0.1-beta1") < Updater.Tag("0.0.1"))
        XCTAssertTrue(Updater.Tag("0.0.1-beta1") < Updater.Tag("0.0.2"))
        XCTAssertTrue(Updater.Tag("0.0.5-beta1") < Updater.Tag("0.0.1"))
        XCTAssertTrue(Updater.Tag("0.5.0") < Updater.Tag("0.0.0-beta1"))
        XCTAssertTrue(Updater.Tag("6.44.1") < Updater.Tag("4.0.1-beta4"))
        XCTAssertTrue(Updater.Tag("v150.0.1") < Updater.Tag("0.2.2-beta4"))
        XCTAssertTrue(Updater.Tag("0.0.535") < Updater.Tag("0.5.1-beta32"))
    }
    
    func testCompareBothBetaTags() {
        XCTAssertTrue(Updater.Tag("0.0.0-beta1") < Updater.Tag("0.0.0-beta2"))
        XCTAssertTrue(Updater.Tag("0.5.0-beta15") > Updater.Tag("0.4.9-beta2"))
        XCTAssertTrue(Updater.Tag("v10.5.48-beta15") > Updater.Tag("9.5.48-beta20"))
        XCTAssertTrue(Updater.Tag("0.45.1-beta23") > Updater.Tag("0.45.1-beta22"))
    }
}
