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
import SystemConfiguration

public protocol Provider {
    func latest(_ completion: @escaping (_ result: Updater.Release?, _ error: Error?) -> Void)
}

extension String: LocalizedError {
    public var errorDescription: String? { return self }
}

public struct Updater {
    public struct Release {
        public let tag: Tag
        public let url: String
    }
    
    private let name: String
    private let providers: [Provider]
    
    public init(name: String, providers: [Provider]) {
        self.name = name
        self.providers = providers
    }
    
    public func check(_ completion: @escaping (_ result: Release?, _ error: [Error]?) -> Void) {
        if self.providers.isEmpty {
            completion(nil, ["No providers"])
            return
        }
        
        if !self.isConnectedToNetwork() {
            completion(nil, ["No internet connection"])
            return
        }
        
        var release: Release? = nil
        var error: [Error]? = nil
        let group = DispatchGroup()
        
        for i in 0..<self.providers.count {
            group.enter()
            self.providers[i].latest() { result, err in
                if let err = err {
                    error?.append(err)
                }
                if let result = result, release == nil {
                    release = result
                }
                group.leave()
            }
        }
        
        group.wait()
        completion(release, error)
    }
    
    public func download(_ url: URL, progressBar: @escaping (_ progress: Progress) -> Void = {_ in }, done: @escaping (_ path: String) -> Void = {_ in }) {
        let downloadTask = URLSession.shared.downloadTask(with: url) { urlOrNil, _, _ in
            guard let fileURL = urlOrNil else { return }
            do {
                let downloadsURL = try FileManager.default.url(for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                let destinationURL = downloadsURL.appendingPathComponent(url.lastPathComponent)
                
                self.copyFile(from: fileURL, to: destinationURL) { (path, error) in
                    if error != nil {
                        print("copy file error: \(error!)")
                        return
                    }
                    
                    done(path)
                }
            } catch {
                print("file error: \(error)")
            }
        }
        
        _ = downloadTask.progress.observe(\.fractionCompleted) { progress, _ in
            progressBar(progress)
        }
        
        downloadTask.resume()
    }
    
    public func install(path: String) {
        print("Started new version installation...")
        
        _ = syncShell("mkdir /tmp/\(self.name)") // make sure that directory exist
        let res = syncShell("/usr/bin/hdiutil attach \(path) -mountpoint /tmp/\(self.name) -noverify -nobrowse -noautoopen") // mount the dmg
        
        print("DMG is mounted")
        
        if res.contains("is busy") { // dmg can be busy, if yes, unmount it and mount again
            print("DMG is busy, remounting")
            
            _ = syncShell("/usr/bin/hdiutil detach $TMPDIR/\(self.name)")
            _ = syncShell("/usr/bin/hdiutil attach \(path) -mountpoint /tmp/\(self.name) -noverify -nobrowse -noautoopen")
        }
        
        // copy updater script to tmp folder
        _ = syncShell("cp -rf /tmp/\(self.name)/\(self.name).app/Contents/Resources/Updater_Updater.bundle/Contents/Resources/updater.sh $TMPDIR/updater.sh")
        
        print("Script is copied to $TMPDIR/updater.sh")
        
        let pwd = Bundle.main.bundleURL.absoluteString
            .replacingOccurrences(of: "file://", with: "")
            .replacingOccurrences(of: "\(self.name).app", with: "")
            .replacingOccurrences(of: "//", with: "/")
        
        let dmg = path.replacingOccurrences(of: "file://", with: "")
        self.asyncShell("sh $TMPDIR/updater.sh --name \(self.name) --mount /tmp/\(self.name) --app \(pwd) --dmg \(dmg) >/dev/null &") // run updater script in in background
        
        print("Run updater.sh with app: \(pwd) and dmg: \(dmg)")
        
        exit(0)
    }
    
    public func cleanup() {
        let args = CommandLine.arguments
        
        if let mountIndex = args.firstIndex(of: "--mount-path") {
            if args.indices.contains(mountIndex+1) {
                let mountPath = args[mountIndex+1]
                asyncShell("/usr/bin/hdiutil detach \(mountPath)")
                asyncShell("/bin/rm -rf \(mountPath)")
                
                print("DMG was unmounted and mountPath deleted")
            }
        }
        
        if let dmgIndex = args.firstIndex(of: "--dmg-path") {
            if args.indices.contains(dmgIndex+1) {
                asyncShell("/bin/rm -rf \(args[dmgIndex+1])")
                
                print("DMG was deleted")
            }
        }
    }
    
    // MARK: - helpers
    
    // https://stackoverflow.com/questions/30743408/check-for-internet-connection-with-swift
    private func isConnectedToNetwork() -> Bool {
        var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }
        
        var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags(rawValue: 0)
        if SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) == false {
            return false
        }
        
        let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        let ret = (isReachable && !needsConnection)
        
        return ret
    }
    
    private func copyFile(from: URL, to: URL, completionHandler: @escaping (_ path: String, _ error: Error?) -> Void) {
        var toPath = to
        let fileName = (URL(fileURLWithPath: to.absoluteString)).lastPathComponent
        let fileExt  = (URL(fileURLWithPath: to.absoluteString)).pathExtension
        var fileNameWithotSuffix: String!
        var newFileName: String!
        var counter = 0
        
        if fileName.hasSuffix(fileExt) {
            fileNameWithotSuffix = String(fileName.prefix(fileName.count - (fileExt.count+1)))
        }
        
        while FileManager.default.fileExists(atPath: toPath.path) {
            counter += 1
            newFileName =  "\(fileNameWithotSuffix!)-\(counter).\(fileExt)"
            toPath = to.deletingLastPathComponent().appendingPathComponent(newFileName)
        }
        
        do {
            try FileManager.default.moveItem(at: from, to: toPath)
            completionHandler(toPath.absoluteString, nil)
        } catch {
            completionHandler("", error)
        }
    }
    
    private func syncShell(_ args: String) -> String {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", args]
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!
        
        return output
    }
    
    private func asyncShell(_ args: String) {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", args]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
    }
}
