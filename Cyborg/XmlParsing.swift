//
//  Copyright (c) 2018. Uber Technologies
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import CoreGraphics
import Foundation
import libxml2

/// Wrapper around a string returned by libxml2.
/// Per the libxml2 spec, these are utf8 strings, and we take them at their word.
///
/// This string operates in UTF-8 code units. The strings we'll be parsing are
/// ASCII only anyway, user facing ones that might have complex grapheme clusters
/// will be immediately converting to `String` anyway, and we won't be processing them.
///
/// Note: These strings generally should never be stored. They are only valid
/// for the scope of the `xmlReaderPointer` they were created from.
struct XMLString: Equatable, CustomDebugStringConvertible {
    
    typealias Char = xmlChar

    /// Count in UTF-8 code units.
    let count: Int32

    fileprivate let underlying: UnsafeMutablePointer<xmlChar>

    init(_ underlying: UnsafePointer<xmlChar>) {
        self.init(UnsafeMutablePointer(mutating: underlying))
    }

    init(_ underlying: UnsafeMutablePointer<xmlChar>) {
        count = xmlStrlen(underlying)
        self.underlying = underlying
    }

    init(_ underlying: UnsafeMutablePointer<xmlChar>, count: Int32) {
        self.underlying = underlying
        self.count = count
    }

    static func == (lhs: XMLString, rhs: XMLString) -> Bool {
        if lhs.count != rhs.count {
            return false
        } else {
            for i in 0..<Int(lhs.count) {
                if lhs.underlying.advanced(by: i).pointee != rhs.underlying.advanced(by: i).pointee {
                    return false
                }
            }
            return true
        }
    }

    subscript(_ range: CountableRange<Int32>) -> XMLString {
        if range.upperBound <= count && range.lowerBound >= 0 {
            let newUnderlying = underlying.advanced(by: Int(range.lowerBound))
            return XMLString(newUnderlying, count: range.upperBound - range.lowerBound)
        } else {
            fatalError("Index out of bounds")
        }
    }

    subscript(_ index: Int32) -> xmlChar {
        if index < count && index >= 0 {
            return underlying.advanced(by: Int(index)).pointee
        } else {
            fatalError("Index out of bounds")
        }
    }

    subscript(safeIndex index: Int32) -> xmlChar? {
        if index < count && index >= 0 {
            return underlying.advanced(by: Int(index)).pointee
        } else {
            return nil
        }
    }

    var debugDescription: String {
        return String(withoutCopying: self)
    }

    func matches(_ string: XMLString, at index: Int32) -> Bool {
        let upperbound = index + string.count
        if upperbound <= count {
            for i in 0..<string.count {
                if underlying.advanced(by: Int(i + index)).pointee != string.underlying.advanced(by: Int(i)).pointee {
                    return false
                }
            }
            return true
        } else {
            return false
        }
    }

    static func ~= (lhs: String, rhs: XMLString) -> Bool {
        if lhs.utf8.count != rhs.count {
            return false
        } else {
            for (index, character) in lhs.utf8.enumerated() {
                if character != rhs.underlying.advanced(by: index).pointee {
                    return false
                }
            }
            return true
        }
    }

    func withSignedIntegers<T>(_ function: (UnsafeMutablePointer<Int8>) -> T) -> T {
        return underlying
            .withMemoryRebound(to: Int8.self,
                               capacity: Int(count),
                               function)
    }

}

extension String {

    init(withoutCopying xmlString: XMLString) {
        // *If* libXML is implemented correctly, this should never fail. If not, we return a string that we think will
        // propogate the error in a reasonable way.
        self = String(bytesNoCopy: UnsafeMutableRawPointer(xmlString.underlying),
                      length: Int(xmlString.count),
                      encoding: .utf8,
                      freeWhenDone: false) ?? "<String Conversion failed, this represents a serious bug in Cyborg>"
    }

    init(copying xmlString: XMLString) {
        var result = String()
        for i in 0..<xmlString.count {
            result
                .append(Character(Unicode.Scalar(xmlString
                        .underlying
                        .advanced(by: Int(i))
                        .pointee)))
        }
        self = result
    }

}

extension Int8 {

    static let comma: Int8 = 44

}

extension UInt8 {

    static let whitespace: UInt8 = 32

    static let newline: UInt8 = 10

    static let questionMark: UInt8 = 63

    static let at: UInt8 = 64

}

extension XMLString {

    fileprivate static func globallyScoped(_ value: UInt8) -> XMLString {
        // It's okay not to deallocate this because it's only ever used at a global scope.
        // It is not recognized as a memory leak in instruments.
        let globallyScopedBuffer = UnsafeMutablePointer<xmlChar>.allocate(capacity: 2)
        globallyScopedBuffer.pointee = value
        globallyScopedBuffer.advanced(by: 1).pointee = 0
        return XMLString(globallyScopedBuffer)
    }

    static let m: XMLString = globallyScoped(109)

    static let M: XMLString = globallyScoped(77)

    static let l: XMLString = globallyScoped(108)

    static let L: XMLString = globallyScoped(76)

    static let v: XMLString = globallyScoped(118)

    static let V: XMLString = globallyScoped(86)

    static let h: XMLString = globallyScoped(104)

    static let H: XMLString = globallyScoped(72)

    static let c: XMLString = globallyScoped(99)

    static let C: XMLString = globallyScoped(67)

    static let s: XMLString = globallyScoped(115)

    static let S: XMLString = globallyScoped(83)

    static let q: XMLString = globallyScoped(113)

    static let Q: XMLString = globallyScoped(81)

    static let t: XMLString = globallyScoped(116)

    static let T: XMLString = globallyScoped(84)

    static let a: XMLString = globallyScoped(97)

    static let A: XMLString = globallyScoped(65)

    static let z: XMLString = globallyScoped(122)

    static let Z: XMLString = globallyScoped(90)
}

extension CGFloat {

    init?(_ xmlString: XMLString) {
        let count = Int(xmlString.count)
        if let float = (xmlString
            .withSignedIntegers { (buffer) -> (CGFloat?) in
                var next: UnsafeMutablePointer<Int8>? = buffer
                for i in 0..<count {
                    var current = Int8(xmlString.underlying.advanced(by: i).pointee)
                    buffer.advanced(by: i).assign(from: &current,
                                                  count: 1)
                }
                let result = strtod(buffer, &next)
                if result == 0.0 && next == buffer {
                    return nil
                } else {
                    return CGFloat(result)
                }
        }) {
            self = float
        } else {
            return nil
        }
    }

}

extension Bool {

    init?(_ xmlString: XMLString) {
        self.init(String(withoutCopying: xmlString))
    }

}

protocol XMLStringRepresentable: RawRepresentable where RawValue == String {}

extension XMLStringRepresentable {

    init?(_ xmlString: XMLString) {
        self.init(rawValue: String(withoutCopying: xmlString))
    }

}
