import XCTest
@testable import Updater

final class UpdaterTests: XCTestCase {
    func testNoProviders() {
        let updater = Updater(name: "test", providers: [])
        let completedExpectation = expectation(description: "Completed")
        
        updater.check() { release, error in
            XCTAssertNotNil(error)
            XCTAssertNil(release)
            XCTAssertEqual(error!.first!.localizedDescription, "No providers")
            completedExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testGithubProvider() {
        let updater = Updater(name: "test", providers: [Updater.Github(user: "exelban", repo: "Stats", asset: "Stats.dmg")])
        let completedExpectation = expectation(description: "Completed")
        
        updater.check() { release, error in
            XCTAssertNil(error)
            XCTAssertNotNil(release)
            XCTAssertTrue(release!.tag.raw.contains("v"))
            XCTAssertTrue(release!.url.contains("https://github.com/exelban/stats/releases/download/"))
            completedExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
}
