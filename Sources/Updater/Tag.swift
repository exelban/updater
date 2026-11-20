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
        public var major: Int
        public var minor: Int
        public var patch: Int
        public var beta: Int? = nil
        
        public var raw: String
        
        public init(_ value: String) {
            self.raw = value
            let parts = Self.parse(value) ?? (0, 0, 0, nil)
            (self.major, self.minor, self.patch, self.beta) = parts
        }

        init?(validating value: String) {
            guard let parts = Self.parse(value) else { return nil }
            self.raw = value
            (self.major, self.minor, self.patch, self.beta) = parts
        }

        private static func parse(_ value: String) -> (Int, Int, Int, Int?)? {
            let number = value.hasPrefix("v") ? value.dropFirst() : value[...]
            let parts = number.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
            let components = parts[0].split(separator: ".", omittingEmptySubsequences: false)
            func integer(_ text: Substring) -> Int? {
                guard text.utf8.allSatisfy({ (48...57).contains($0) }) else { return nil }
                return Int(text)
            }
            let numbers = components.compactMap(integer)
            guard (1...3).contains(numbers.count), components.count == numbers.count else { return nil }
            var beta: Int?
            if parts.count == 2 {
                guard parts[1].hasPrefix("beta") else { return nil }
                let suffix = parts[1].dropFirst(4)
                guard let index = suffix.isEmpty ? 0 : integer(suffix) else { return nil }
                beta = index
            }
            return (numbers[0], numbers.count > 1 ? numbers[1] : 0, numbers.count > 2 ? numbers[2] : 0, beta)
        }

        public func isUpdate(for current: Tag, includingBetas: Bool = false) -> Bool {
            return self > current && (self.beta == nil || current.beta != nil || includingBetas)
        }

        public static func == (lhs: Tag, rhs: Tag) -> Bool {
            return (lhs.major, lhs.minor, lhs.patch, lhs.beta) == (rhs.major, rhs.minor, rhs.patch, rhs.beta)
        }
        
        public static func < (lhs: Tag, rhs: Tag) -> Bool {
            let left = (lhs.major, lhs.minor, lhs.patch)
            let right = (rhs.major, rhs.minor, rhs.patch)
            if left != right { return left < right }
            guard let beta = lhs.beta else { return false }
            guard let other = rhs.beta else { return true }
            return beta < other
        }
    }
}
