//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

import Foundation
import libxml2

/// Wrapper around a string returned by libxml2.
/// Per the libxml2 spec, these are utf8 strings, and we take them at their word.
///
/// This string operates in UTF-8 code units. The strings we'll be parsing are
/// ASCII only anyway, user facing ones that might have complex grapheme clusters
/// will be immediately converting to `String` anyway, and we won't be processing them.
///
/// Note: These strings should never be stored. They are only valid
/// for the scope of the `xmlReaderPointer` they were created from.
struct XMLString: Equatable, CustomDebugStringConvertible {

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
        return String(self)
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

    static func ~=(lhs: String, rhs: XMLString) -> Bool {
        if lhs.count != rhs.count {
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
    
    func withSignedIntegers<T>(_ function: (UnsafeMutablePointer<Int8>) -> (T)) -> T {
        return underlying
            .withMemoryRebound(to: Int8.self,
                               capacity: Int(count),
                               function)
    }
    
}

extension String {

    init(_ xmlString: XMLString) {
        // *If* libXML is implemented correctly, this should never fail. If not, we return a string that we think will
        // propogate the error in a reasonable way.
        self = String(bytesNoCopy: UnsafeMutableRawPointer(xmlString.underlying),
                      length: Int(xmlString.count),
                      encoding: .utf8,
                      freeWhenDone: false) ?? "<String Conversion failed, this represents a serious bug in Cyborg>" // TODO: better error message, or acknowledge that this can fail
    }

}

extension Int8 {

    static let comma: Int8 = 44

}

extension UInt8 {

    static let whitespace: UInt8 = 10

    static let newline: UInt8 = 32
    
    static let questionMark: UInt8 = 64
    
}

extension XMLString {
    fileprivate static func globallyScoped(_ value: UInt8) -> XMLString {
        // It's okay not to deallocate this because it's only ever used at a global scope.
        // It is not recognized as a memory leak in instruments.
        let globallyScopedBuffer = UnsafeMutablePointer<xmlChar>.allocate(capacity: 1)
        globallyScopedBuffer.pointee = value
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
        self.init(String(xmlString))
    }

}

protocol XMLStringRepresentable: RawRepresentable where RawValue == String {}

extension XMLStringRepresentable {

    init?(_ xmlString: XMLString) {
        self.init(rawValue: String(xmlString))
    }

}
