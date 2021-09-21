//
//  Tag.swift
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
    public struct Tag: Comparable {
        var major: Int
        var minor: Int
        var patch: Int
        var beta: Int? = nil
        
        var raw: String
        
        public init(_ value: String) {
            self.raw = value
            
            let arr = value.replacingOccurrences(of: "v", with: "").split(separator: ".")
            
            var major: Int = 0
            var minor: Int = 0
            var patch: Int = 0
            var beta: Int? = nil
            
            switch arr.count {
            case 1:
                major = Int(arr[0]) ?? 0
            case 2:
                major = Int(arr[0]) ?? 0
                minor = Int(arr[1]) ?? 0
            case let count where count >= 3:
                major = Int(arr[0]) ?? 0
                minor = Int(arr[1]) ?? 0
                patch = Int(arr[2]) ?? 0
            default: break
            }
            
            if let patchStr = arr.last, patchStr.contains("-") {
                let arr = patchStr.split(separator: "-")
                if let patchNumber = arr.first {
                    patch = Int(patchNumber) ?? 0
                }
                if let betaStr = arr.last {
                    beta = Int(betaStr.replacingOccurrences(of: "beta", with: "")) ?? 0
                }
            }
            
            self.major = major
            self.minor = minor
            self.patch = patch
            self.beta = beta
        }
        
        public static func < (lhs: Tag, rhs: Tag) -> Bool {
            if lhs.beta == nil && rhs.beta == nil {
                if rhs.major > lhs.major {
                    return true
                }
                
                if rhs.minor > lhs.minor && rhs.major >= lhs.major {
                    return true
                }
                
                if rhs.patch > lhs.patch && rhs.minor >= lhs.minor && rhs.major >= lhs.major {
                    return true
                }
                
                return false
            }
            
            // current version is beta + last version is beta
            if lhs.beta != nil && rhs.beta != nil {
                if rhs.major > lhs.major {
                    return true
                }
                
                if rhs.minor > lhs.minor && rhs.major >= lhs.major {
                    return true
                }
                
                if rhs.patch >= lhs.patch && rhs.minor >= lhs.minor && rhs.major >= lhs.major {
                    return true
                }
                
                if rhs.beta! > lhs.beta! && rhs.patch >= lhs.patch && rhs.minor >= lhs.minor && rhs.major >= lhs.major {
                    return true
                }
                
                return false
            }
            
            // beta version is always lower than no-beta
            if lhs.beta != nil || rhs.beta != nil {
                return true
            }
            
            return false
        }
    }
}
