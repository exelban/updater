//
//  Updater.swift
//  Updater
//
//  Created by Serhiy Mytrovtsiy on 20/09/2021.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2021 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Security

public protocol Provider {
    func latest(_ completion: @escaping (_ result: Updater.Release?, _ error: Error?) -> Void)
}

#if compiler(>=6.0)
extension String: @retroactive LocalizedError {}
#else
extension String: LocalizedError {}
#endif

extension String {
    public var errorDescription: String? { return self }
}

public struct Updater {
    public struct Release {
        public let tag: Tag
        public let url: String

        public init(tag: Tag, url: String) {
            self.tag = tag
            self.url = url
        }
    }

    private final class Observation {
        var token: NSKeyValueObservation?
    }

    private struct DownloadIdentity: Equatable {
        let device: dev_t
        let inode: ino_t
        let modified: Int
        let nanoseconds: Int

        init?(_ url: URL) {
            var info = stat()
            guard lstat(url.path, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG else { return nil }
            self.device = info.st_dev
            self.inode = info.st_ino
            self.modified = info.st_mtimespec.tv_sec
            self.nanoseconds = info.st_mtimespec.tv_nsec
        }
    }

    private final class Downloads {
        let lock = NSLock()
        var files: [URL: DownloadIdentity] = [:]
    }
    
    private let name: String
    private let providers: [Provider]
    private let downloads = Downloads()
    private static let checkLock = NSLock()
    
    public init(name: String, providers: [Provider]) {
        self.name = name
        self.providers = providers
    }
    
    public func check(_ completion: @escaping (_ result: Release?, _ error: [Error]?) -> Void) {
        self.check(force: true, completion: completion)
    }

    public func check(force: Bool, completion: @escaping (_ result: Release?, _ error: [Error]?) -> Void) {
        guard !self.providers.isEmpty else {
            completion(nil, ["No providers"])
            return
        }
        
        let key = "Updater.\(self.name).lastCheck"
        Self.checkLock.lock()
        let recent = self.isRecent(key, interval: 600)
        if force || !recent { UserDefaults.standard.set(Date(), forKey: key) }
        Self.checkLock.unlock()
        guard force || !recent else {
            completion(nil, ["An update check was performed recently"])
            return
        }
        
        func fetch(_ index: Int, errors: [Error]) {
            self.providers[index].latest { release, error in
                if let release = release, error == nil {
                    completion(release, nil)
                    return
                }
                let failures = errors + [error ?? "Provider returned no release"]
                if index + 1 < self.providers.count {
                    fetch(index + 1, errors: failures)
                } else {
                    completion(nil, failures)
                }
            }
        }
        fetch(0, errors: [])
    }
    
    public func download(_ url: URL, progressBar: @escaping (_ progress: Progress) -> Void = {_ in }, done: @escaping (_ path: String) -> Void = {_ in }) {
        self.downloadFile(url, progress: progressBar) { result in
            switch result {
            case .success(let file): done(file.absoluteString)
            case .failure(let error): NSLog("Updater: %@", error.localizedDescription)
            }
        }
    }

    @discardableResult
    public func downloadFile(_ url: URL, session: URLSession = .shared, progress: @escaping (Progress) -> Void = {_ in }, completion: @escaping (Result<URL, Error>) -> Void) -> URLSessionDownloadTask {
        let observation = Observation()
        let task = session.downloadTask(with: url) { file, response, error in
            observation.token?.invalidate()
            do {
                if let error = error { throw error }
                try Self.validateResponse(response)
                guard let file = file else { throw "Download produced no file" }
                let directory = try FileManager.default.url(for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                let destination = try self.storeDownload(file, in: directory, name: url.lastPathComponent)
                completion(.success(destination))
            } catch {
                completion(.failure(error))
            }
        }
        observation.token = task.progress.observe(\.fractionCompleted) { value, _ in progress(value) }
        task.resume()
        return task
    }
    
    static func validateResponse(_ response: URLResponse?) throws {
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw "HTTP \(http.statusCode) from \(http.url?.host ?? "server")"
        }
        guard response != nil else { throw "Missing response" }
    }
    
    func storeDownload(_ file: URL, in directory: URL, name: String) throws -> URL {
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/") else {
            throw "Invalid download filename"
        }
        let base = directory.appendingPathComponent(name)
        let stem = base.deletingPathExtension().lastPathComponent
        let suffix = base.pathExtension.isEmpty ? "" : ".\(base.pathExtension)"
        var destination = base
        var index = 0
        while true {
            do {
                try FileManager.default.moveItem(at: file, to: destination)
                break
            } catch CocoaError.fileWriteFileExists {
                index += 1
                destination = directory.appendingPathComponent("\(stem)-\(index)\(suffix)")
            }
        }
        if let identifier = DownloadIdentity(destination) {
            self.downloads.lock.lock()
            self.downloads.files[destination.standardizedFileURL] = identifier
            self.downloads.lock.unlock()
        }
        return destination
    }

    func removeDownload(_ file: URL) {
        self.downloads.lock.lock()
        defer { self.downloads.lock.unlock() }
        let original = self.downloads.files.removeValue(forKey: file.standardizedFileURL)
        let current = DownloadIdentity(file)
        if let original = original, original == current {
            _ = unlink(file.path)
        }
    }

    public func install(path: String) {
        self.install(path: path) { error in NSLog("Updater: %@", error.localizedDescription) }
    }

    public func install(path: String, onError: @escaping (Error) -> Void) {
        if path.hasPrefix("file://"), let url = URL(string: path) {
            self.install(url, onError: onError)
        } else {
            self.install(URL(fileURLWithPath: path), onError: onError)
        }
    }

    public func install(_ image: URL, includingBetas: Bool = false, onError: @escaping (Error) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.installImage(image, includingBetas: includingBetas)
                exit(0)
            } catch {
                onError(error)
            }
        }
    }
    
    @available(*, deprecated, message: "Installation now cleans up its own files.")
    public func cleanup() {}
    
    // MARK: - installation

    private func installImage(_ image: URL, includingBetas: Bool) throws {
        let files = FileManager.default
        let host = Bundle.main.bundleURL
        guard image.isFileURL, try image.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
            throw "The disk image must be a local file"
        }
        guard host.pathExtension == "app", let id = Bundle.main.bundleIdentifier, !id.contains("/"),
              !self.name.isEmpty, !self.name.contains("/") else { throw "Invalid application bundle" }

        let lockURL = files.temporaryDirectory.appendingPathComponent("Updater-\(id).lock")
        let lock = open(lockURL.path, O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard lock >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        defer { close(lock) }
        guard flock(lock, LOCK_EX | LOCK_NB) == 0 else { throw "Another installation is in progress" }
        let key = "Updater.\(self.name).lastInstall"
        guard !self.isRecent(key, interval: 180) else { throw "An update was installed recently" }
        
        let staging = try files.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: host, create: true)
        var keepBackup = false
        defer {
            if !keepBackup { try? files.removeItem(at: staging) }
        }
        let candidate = staging.appendingPathComponent(host.lastPathComponent)
        try self.stageImage(image, at: candidate)
        try self.validateSignature(candidate)
        try self.validateVersion(candidate, includingBetas: includingBetas)
        
        do {
            try self.replaceApplication(host, with: candidate) {
                try self.relaunch(host)
            }
        } catch let error as RecoveryError {
            keepBackup = true
            throw error
        }
        UserDefaults.standard.set(Date(), forKey: key)
        self.removeDownload(image)
    }
    
    private func stageImage(_ image: URL, at candidate: URL) throws {
        let files = FileManager.default
        let mount = files.temporaryDirectory.appendingPathComponent("Updater-\(UUID().uuidString)")
        try files.createDirectory(at: mount, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { _ = rmdir(mount.path) }
        var directory = stat()
        guard stat(mount.path, &directory) == 0 else { throw "Unable to inspect the mount directory" }
        func isMounted() -> Bool {
            var volume = stat()
            return stat(mount.path, &volume) == 0 && volume.st_dev != directory.st_dev
        }
        defer {
            if isMounted() {
                do { try self.run("/usr/bin/hdiutil", ["detach", mount.path, "-force"]) }
                catch { NSLog("Updater: %@", error.localizedDescription) }
            }
        }
        try self.run("/usr/bin/hdiutil", ["attach", image.path, "-mountpoint", mount.path, "-readonly", "-nobrowse", "-noautoopen", "-verify"])
        guard isMounted() else { throw "The image was not mounted at the requested location" }
        let source = mount.appendingPathComponent("\(self.name).app")
        guard try source.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == false else {
            throw "The update must contain an application bundle"
        }
        try self.run("/usr/bin/ditto", [source.path, candidate.path])
        do {
            try self.run("/usr/bin/hdiutil", ["detach", mount.path])
        } catch {
            if isMounted() { try self.run("/usr/bin/hdiutil", ["detach", mount.path, "-force"]) }
        }
    }

    private struct RecoveryError: LocalizedError {
        let backup: URL
        let cause: Error
        
        var errorDescription: String? {
            return "\(self.cause.localizedDescription). Previous application retained at \(self.backup.path)"
        }
    }

    func replaceApplication(_ app: URL, with candidate: URL, launch: () throws -> Void) throws {
        if renamex_np(candidate.path, app.path, UInt32(RENAME_SWAP)) == 0 {
            do {
                try launch()
            } catch {
                guard renamex_np(candidate.path, app.path, UInt32(RENAME_SWAP)) == 0 else {
                    throw RecoveryError(backup: candidate, cause: error)
                }
                throw error
            }
            return
        }
        let manager: FileManager
        switch errno {
        case EACCES, EPERM:
            manager = try self.authorizedManager(for: app)
        case ENOTSUP, EXDEV:
            manager = .default
        default:
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        try self.replaceApplication(app, with: candidate, using: manager, launch: launch)
    }

    func replaceApplication(_ app: URL, with candidate: URL, using manager: FileManager, launch: () throws -> Void) throws {
        let directory = candidate.deletingLastPathComponent().appendingPathComponent("previous")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let backup = directory.appendingPathComponent(app.lastPathComponent)
        try self.run("/usr/bin/ditto", [app.path, backup.path])
        do {
            _ = try manager.replaceItemAt(app, withItemAt: candidate)
        } catch {
            throw RecoveryError(backup: backup, cause: error)
        }
        do {
            try launch()
        } catch let launchError {
            do {
                _ = try manager.replaceItemAt(app, withItemAt: backup)
            } catch {
                throw RecoveryError(backup: backup, cause: error)
            }
            throw launchError
        }
    }
    
    private func relaunch(_ app: URL) throws {
        let semaphore = DispatchSemaphore(value: 0)
        var launchError: Error?
        DispatchQueue.main.async {
            let options = NSWorkspace.OpenConfiguration()
            options.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: app, configuration: options) { running, error in
                if let running = running, running.processIdentifier != getpid(), !running.isTerminated {
                    launchError = nil
                } else {
                    launchError = error ?? "Unable to launch a new instance of the updated application"
                }
                semaphore.signal()
            }
        }
        semaphore.wait()
        if let error = launchError { throw error }
    }

    func validateSignature(_ app: URL) throws {
        var running: SecCode?
        var original: SecStaticCode?
        var candidate: SecStaticCode?
        var requirement: SecRequirement?
        guard SecCodeCopySelf([], &running) == errSecSuccess, let code = running,
              SecCodeCopyStaticCode(code, [], &original) == errSecSuccess, let host = original,
              SecCodeCopyDesignatedRequirement(host, [], &requirement) == errSecSuccess, let identity = requirement,
              SecStaticCodeCreateWithPath(app as CFURL, [], &candidate) == errSecSuccess, let update = candidate else {
            throw "Unable to determine the application signing identity"
        }
        let flags = SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode)
        let status = SecStaticCodeCheckValidity(update, flags, identity)
        guard status == errSecSuccess else {
            throw "Update signature validation failed (\(status))"
        }
        func team(_ code: SecStaticCode) -> String? {
            var info: CFDictionary?
            guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess else { return nil }
            return (info as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String
        }
        guard let expected = team(host), !expected.isEmpty, team(update) == expected else {
            throw "The update must be signed by the application's developer team"
        }
    }
    
    func validateVersion(_ app: URL, host: Bundle = .main, includingBetas: Bool) throws {
        guard let bundle = Bundle(url: app), let identifier = host.bundleIdentifier, bundle.bundleIdentifier == identifier,
              let latest = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              let current = host.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              let candidate = Tag(validating: latest), let installed = Tag(validating: current),
              candidate.isUpdate(for: installed, includingBetas: includingBetas) else {
            throw "The image does not contain a newer compatible release of this application"
        }
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let currentOS = Tag("\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)")
        var minimums = [bundle.object(forInfoDictionaryKey: "LSMinimumSystemVersion") as? String]
        let perArchitecture = bundle.object(forInfoDictionaryKey: "LSMinimumSystemVersionByArchitecture") as? [String: String]
        #if arch(arm64)
        minimums.append(perArchitecture?["arm64"])
        #elseif arch(x86_64)
        minimums.append(perArchitecture?["x86_64"])
        #endif
        for case let minimum? in minimums {
            guard let required = Tag(validating: minimum), required <= currentOS else {
                throw "This update requires macOS \(minimum)"
            }
        }
    }

    private func authorizedManager(for app: URL) throws -> FileManager {
        guard let task = SecTaskCreateFromSelf(nil),
              SecTaskCopyValueForEntitlement(task, "com.apple.developer.security.privileged-file-operations" as CFString, nil) as? Bool == true else {
            throw "Administrator access is required. The host app needs the Privileged File Operations entitlement to replace \(app.path)"
        }
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<FileManager, Error> = .failure("File replacement authorization was denied")
        DispatchQueue.main.async {
            NSWorkspace.shared.requestAuthorization(to: .replaceFile) { authorization, error in
                if let authorization = authorization {
                    result = .success(FileManager(authorization: authorization))
                } else if let error = error {
                    result = .failure(error)
                }
                semaphore.signal()
            }
        }
        semaphore.wait()
        return try result.get()
    }

    private func isRecent(_ key: String, interval: TimeInterval) -> Bool {
        guard let last = UserDefaults.standard.object(forKey: key) as? Date else { return false }
        return (0..<interval).contains(Date().timeIntervalSince(last))
    }

    private func run(_ executable: String, _ arguments: [String]) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments
        task.standardInput = FileHandle.nullDevice
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        try task.run()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else {
            let message = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw "\((executable as NSString).lastPathComponent) failed (\(task.terminationStatus)): \(message)"
        }
    }
}
