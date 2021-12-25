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
        
        public init(url: URL, asset: String) {
            self.url = url
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
                    
                    guard let lastVersion = jsonArray["tag"] as? String else {
                        completion(nil, "tag_name not found in response")
                        return
                    }
                    
                    guard let assets = jsonArray["assets"] as? [[String: Any]] else {
                        completion(nil, "parse assets error")
                        return
                    }
                    
                    if let asset = assets.first(where: {$0["name"] as! String == self.asset}) {
                        guard let downloadURL = asset["download_url"] as? String else {
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
