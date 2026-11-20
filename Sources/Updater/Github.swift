//
//  Github.swift
//  Updater
//
//  Created by Serhiy Mytrovtsiy on 20/09/2021.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2021 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation

extension Updater {
    public struct Github: Provider {
        private let user: String
        private let repo: String
        private let asset: String
        private let session: URLSession
        
        public init(user: String, repo: String, asset: String, session: URLSession = .shared) {
            self.user = user
            self.repo = repo
            self.asset = asset
            self.session = session
        }
        
        public func latest(_ completion: @escaping (_ result: Release?, _ error: Error?) -> Void) {
            guard let base = URL(string: "https://api.github.com/repos"),
                  !self.user.isEmpty, !self.repo.isEmpty,
                  !self.user.contains("/"), !self.repo.contains("/") else {
                completion(nil, "Invalid GitHub repository")
                return
            }
            let url = base.appendingPathComponent(self.user).appendingPathComponent(self.repo).appendingPathComponent("releases/latest")
            Updater.fetchRelease(url, asset: self.asset, tagKey: "tag_name", urlKey: "browser_download_url", session: self.session, completion: completion)
        }
    }
}
