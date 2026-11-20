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

extension Updater {
    public struct Server: Provider {
        private let url: URL
        private let asset: String
        private let session: URLSession
        
        public init(url: URL, asset: String, includeMacOSVersion: Bool = false, session: URLSession = .shared) {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
            if includeMacOSVersion {
                let os = ProcessInfo.processInfo.operatingSystemVersion
                var items = components?.queryItems ?? []
                items.removeAll { $0.name == "macOS" }
                items.append(URLQueryItem(name: "macOS", value: "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"))
                components?.queryItems = items
            }
            self.url = components?.url ?? url
            self.asset = asset
            self.session = session
        }
        
        public func latest(_ completion: @escaping (_ result: Release?, _ error: Error?) -> Void) {
            Updater.fetchRelease(self.url, asset: self.asset, tagKey: "tag", urlKey: "download_url", session: self.session, completion: completion)
        }
    }

    static func fetchRelease(_ url: URL, asset: String, tagKey: String, urlKey: String, session: URLSession, completion: @escaping (Release?, Error?) -> Void) {
        let task = session.dataTask(with: url) { data, response, error in
            do {
                if let error = error { throw error }
                try self.validateResponse(response)
                guard let data = data,
                      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let value = json[tagKey] as? String, let tag = Tag(validating: value),
                      let assets = json["assets"] as? [Any] else {
                    throw "Invalid release metadata"
                }
                for case let item as [String: Any] in assets where item["name"] as? String == asset {
                    guard let value = item[urlKey] as? String, let url = URL(string: value),
                          let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme), url.host != nil else {
                        throw "Invalid download URL for '\(asset)'"
                    }
                    completion(Release(tag: tag, url: value), nil)
                    return
                }
                throw "Asset '\(asset)' not found in release"
            } catch {
                completion(nil, error)
            }
        }
        task.resume()
    }
}
