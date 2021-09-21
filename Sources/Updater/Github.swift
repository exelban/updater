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
    struct Github: Provider {
        private let user: String
        private let repo: String
        private let asset: String
        
        private var url: URL {
            return URL(string: "https://api.github.com/repos/\(self.user)/\(self.repo)/releases/latest")!
        }
        
        public init(user: String, repo: String, asset: String) {
            self.user = user
            self.repo = repo
            self.asset = asset
        }
        
        public func latest(_ completion: @escaping (_ result: Release?, _ error: Error?) -> Void) {
            let task = URLSession.shared.dataTask(with: self.url) { data, response, error in
                guard let data = data, error == nil else {
                    completion(nil, error)
                    return
                }
                
                do {
                    let jsonResponse = try JSONSerialization.jsonObject(with: data, options: [])
                    
                    guard let jsonArray = jsonResponse as? [String: Any] else {
                        completion(nil, "parse json error")
                        return
                    }
                    
                    guard let lastVersion = jsonArray["tag_name"] as? String else {
                        completion(nil, "tag_name not found in response")
                        return
                    }
                    
                    guard let assets = jsonArray["assets"] as? [[String: Any]] else {
                        completion(nil, "parse assets error")
                        return
                    }
                    
                    if let asset = assets.first(where: {$0["name"] as! String == self.asset}) {
                        guard let downloadURL = asset["browser_download_url"] as? String else {
                            completion(nil, "browser_download_url not found in response")
                            return
                        }
                        completion(Release(tag: Tag(lastVersion), url: downloadURL), nil)
                    } else {
                        completion(nil, "asset with name '\(self.asset)' not found in the release")
                        return
                    }
                } catch let error {
                    completion(nil, error)
                }
            }
            task.resume()
        }
    }
}
