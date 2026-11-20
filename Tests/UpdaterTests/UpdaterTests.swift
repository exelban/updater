import XCTest
@testable import Updater

final class ReleaseProtocol: URLProtocol {
    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ReleaseProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { return true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { return request }

    override func startLoading() {
        let url = self.request.url!
        let github = url.host == "api.github.com"
        let missing = url.path.contains("telemetry") || url.path.contains("not-found")
        let status = missing ? 404 : 200
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
        let download = "https://github.com/exelban/stats/releases/download/v2.0/Stats.dmg"
        let json: [String: Any] = [
            github ? "tag_name" : "tag": "v2.0",
            "assets": [["name": 0], ["name": "Stats.dmg", github ? "browser_download_url" : "download_url": download]]
        ]
        self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        self.client?.urlProtocol(self, didLoad: try! JSONSerialization.data(withJSONObject: json))
        self.client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class UpdaterTests: XCTestCase {
    private struct Stub: Provider {
        let fetch: (@escaping (Updater.Release?, Error?) -> Void) -> Void
        
        func latest(_ completion: @escaping (Updater.Release?, Error?) -> Void) {
            self.fetch(completion)
        }
    }

    func testNoProviders() {
        Updater(name: "test", providers: []).check { release, errors in
            XCTAssertNil(release)
            XCTAssertEqual(errors?.first?.localizedDescription, "No providers")
        }
    }
    
    func testOrderedFallback() {
        let done = expectation(description: "Completed")
        let first = Stub { callback in DispatchQueue.main.async { callback(nil, "offline") } }
        let release = Updater.Release(tag: Updater.Tag("2"), url: "https://example.com/test.dmg")
        let second = Stub { $0(release, nil) }
        let third = Stub { _ in XCTFail("Queried a provider after success") }
        Updater(name: "test", providers: [first, second, third]).check { result, errors in
            XCTAssertEqual(result?.tag, release.tag)
            XCTAssertNil(errors)
            done.fulfill()
        }
        waitForExpectations(timeout: 3)
    }

    func testAllErrorsAndThrottle() {
        let name = UUID().uuidString
        defer { UserDefaults.standard.removeObject(forKey: "Updater.\(name).lastCheck") }
        let updater = Updater(name: name, providers: [Stub { $0(nil, "first") }, Stub { $0(nil, "second") }])
        updater.check(force: false) { _, errors in
            XCTAssertEqual(errors?.map { $0.localizedDescription }, ["first", "second"])
        }
        updater.check(force: false) { _, errors in
            XCTAssertEqual(errors?.first?.localizedDescription, "An update check was performed recently")
        }
        updater.check(force: true) { _, errors in XCTAssertEqual(errors?.count, 2) }
    }

    func testDownloadHTTPError() {
        let done = expectation(description: "Failed download")
        let updater = Updater(name: "test", providers: [])
        updater.downloadFile(URL(string: "https://example.invalid/not-found")!, session: ReleaseProtocol.session()) { result in
            switch result {
            case .success: XCTFail("Accepted HTTP 404")
            case .failure(let error): XCTAssertTrue(error.localizedDescription.contains("404"))
            }
            done.fulfill()
        }
        waitForExpectations(timeout: 3)
    }

    func testDownloadCollisionsAndOwnership() throws {
        let files = FileManager.default
        let root = files.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try files.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? files.removeItem(at: root) }
        let updater = Updater(name: "test", providers: [])
        let original = root.appendingPathComponent("My Update.dmg")
        let temp = root.appendingPathComponent("download")
        try Data([1]).write(to: original)
        try Data([2]).write(to: temp)
        let saved = try updater.storeDownload(temp, in: root, name: original.lastPathComponent)
        XCTAssertEqual(saved.lastPathComponent, "My Update-1.dmg")
        updater.removeDownload(original)
        XCTAssertEqual(try Data(contentsOf: original), Data([1]))
        try files.moveItem(at: saved, to: temp)
        try Data([3]).write(to: saved)
        updater.removeDownload(saved)
        XCTAssertEqual(try Data(contentsOf: saved), Data([3]))
        let owned = try updater.storeDownload(temp, in: root, name: "another.dmg")
        updater.removeDownload(owned)
        XCTAssertFalse(files.fileExists(atPath: owned.path))
    }

    func testStagedBundleValidation() throws {
        let files = FileManager.default
        let root = files.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try files.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? files.removeItem(at: root) }
        func bundle(_ version: String, id: String = "test.updater", minimum: String = "10.13") throws -> URL {
            let app = root.appendingPathComponent("\(UUID().uuidString).app")
            let contents = app.appendingPathComponent("Contents")
            try files.createDirectory(at: contents, withIntermediateDirectories: true)
            let info = ["CFBundlePackageType": "APPL", "CFBundleIdentifier": id, "CFBundleShortVersionString": version, "LSMinimumSystemVersion": minimum]
            let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            try data.write(to: contents.appendingPathComponent("Info.plist"))
            return app
        }
        let updater = Updater(name: "test", providers: [])
        let host = try XCTUnwrap(Bundle(url: bundle("2.0")))
        let newer = try bundle("3.0")
        XCTAssertNoThrow(try updater.validateVersion(newer, host: host, includingBetas: false))
        XCTAssertThrowsError(try updater.validateSignature(newer))
        XCTAssertThrowsError(try updater.validateVersion(bundle("1.0"), host: host, includingBetas: false))
        XCTAssertThrowsError(try updater.validateVersion(bundle("3", id: "test.other"), host: host, includingBetas: false))
        XCTAssertThrowsError(try updater.validateVersion(bundle("3", minimum: "999"), host: host, includingBetas: false))
        XCTAssertThrowsError(try updater.validateVersion(bundle("3.0-rc1"), host: host, includingBetas: false))
    }

    func testReplacementAndRelaunchRollback() throws {
        let files = FileManager.default
        let root = files.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try files.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? files.removeItem(at: root) }
        let app = root.appendingPathComponent("Original app.app")
        let candidate = root.appendingPathComponent("Replacement.app")
        try files.createDirectory(at: app, withIntermediateDirectories: false)
        try files.createDirectory(at: candidate, withIntermediateDirectories: false)
        let marker = app.appendingPathComponent("version")
        try Data([1]).write(to: marker)
        try Data([2]).write(to: candidate.appendingPathComponent("version"))
        let updater = Updater(name: "test", providers: [])
        XCTAssertThrowsError(try updater.replaceApplication(app, with: candidate) {
            XCTAssertEqual(try Data(contentsOf: marker), Data([2]))
            throw "Launch failed"
        })
        XCTAssertEqual(try Data(contentsOf: marker), Data([1]))
        let staged = root.appendingPathComponent("staged")
        try files.createDirectory(at: staged, withIntermediateDirectories: false)
        let copy = staged.appendingPathComponent("Another.app")
        try files.copyItem(at: candidate, to: copy)
        XCTAssertThrowsError(try updater.replaceApplication(app, with: copy, using: files) {
            XCTAssertEqual(try Data(contentsOf: marker), Data([2]))
            throw "Launch failed"
        })
        XCTAssertEqual(try Data(contentsOf: marker), Data([1]))
        try updater.replaceApplication(app, with: candidate) {}
        XCTAssertEqual(try Data(contentsOf: marker), Data([2]))
    }
}
