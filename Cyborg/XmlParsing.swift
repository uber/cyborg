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
    
    let underlying: UnsafeMutablePointer<xmlChar> // TODO: make fileprivate
    
    init(char: xmlChar) {
        underlying = UnsafeMutablePointer<xmlChar>.allocate(capacity: 1) // TODO: don't leak
        underlying.pointee = char
        count = 1
    }
    
    init(_ underlying: UnsafeMutablePointer<xmlChar>) {
        count = xmlStrlen(underlying)
        self.underlying = underlying
    }
    
    init(_ underlying: UnsafeMutablePointer<xmlChar>, count: Int32) {
        self.underlying = underlying
        self.count = count
    }
    
    static func ==(lhs: XMLString, rhs: XMLString) -> Bool {
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
    
    subscript (_ range: CountableRange<Int32>) -> XMLString {
        if range.upperBound <= count {
            let newUnderlying = underlying.advanced(by: Int(range.lowerBound))
            return XMLString(newUnderlying, count: range.upperBound - range.lowerBound)
        } else {
            fatalError("Index out of bounds")
        }
    }
    
    subscript (_ index: Int32) -> xmlChar {
        if index < count {
            return underlying.advanced(by: Int(index)).pointee
        } else {
            fatalError("Index out of bounds")
        }
    }
    
    var debugDescription: String {
        return String(self)
    }
    
    func isString(_ string: XMLString, at index: Int32) -> Bool {
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
        // This function is used in switch statements to allow us to match using string literals.
        // As ideas go, this is probably not the best.
        let count = lhs.count
        if count != rhs.count {
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
    
}

extension String {
    
    init(_ xmlString: XMLString) {
        // *If* libXML is implemented correctly, this should never fail. If not, we return a string that we think will
        // propogate the error in a reasonable way.
        self = String(bytesNoCopy: UnsafeMutableRawPointer(xmlString.underlying),
                      length: Int(xmlString.count),
                      encoding: .utf8,
                      freeWhenDone: false) ?? "Invalid Data" // TODO: better error message, or acknowledge taht this can fail
    }
    
}

extension UInt8 {
    
    static let whitespace: UInt8 = 10
    static let newline: UInt8 = 32
    
}

extension CGFloat {
    
    init?(_ xmlString: XMLString) {
        let count = Int(xmlString.count)
        if let float = (xmlString
            .underlying
            .withMemoryRebound(to: Int8.self,
                               capacity: count) { (buffer) -> (CGFloat?) in
                                var next: UnsafeMutablePointer<Int8>? = buffer
                                for i in 0..<count {
                                    var current = Int8(xmlString.underlying.advanced(by: i).pointee)
                                    buffer.advanced(by: i).assign(from: &current,
                                                                  count: 1)
                                }
                                let result = strtod(buffer, &next)
                                if result == 0.0,
                                    next == buffer {
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

protocol XMLStringRepresentable: RawRepresentable where RawValue == String {

}

extension XMLStringRepresentable {

    init?(_ xmlString: XMLString) {
        self.init(rawValue: String(xmlString))
    }

}
