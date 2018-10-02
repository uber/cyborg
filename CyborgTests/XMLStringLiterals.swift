//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

@testable import Cyborg
import XCTest

class LiteralTests: XCTestCase {

    func test_ensureXMLLiteralsWork() {
        func ensureEqual(_ xmlStr: XMLString, _ str: String) -> Bool {
            return str.utf8[str.startIndex] == xmlStr[0]
        }
        XCTAssert(ensureEqual(.m, "m"))
        XCTAssert(ensureEqual(.M, "M"))
        XCTAssert(ensureEqual(.l, "l"))
        XCTAssert(ensureEqual(.v, "v"))
        XCTAssert(ensureEqual(.V, "V"))
        XCTAssert(ensureEqual(.h, "h"))
        XCTAssert(ensureEqual(.H, "H"))
        XCTAssert(ensureEqual(.c, "c"))
        XCTAssert(ensureEqual(.C, "C"))
        XCTAssert(ensureEqual(.s, "s"))
        XCTAssert(ensureEqual(.S, "S"))
        XCTAssert(ensureEqual(.q, "q"))
        XCTAssert(ensureEqual(.Q, "Q"))
        XCTAssert(ensureEqual(.t, "t"))
        XCTAssert(ensureEqual(.T, "T"))
        XCTAssert(ensureEqual(.a, "a"))
        XCTAssert(ensureEqual(.A, "A"))
        XCTAssert(ensureEqual(.z, "z"))
        XCTAssert(ensureEqual(.Z, "Z"))
    }

    func test_ensure_int_literals() {
        let comma = ","
        XCTAssertEqual(Int8.comma, Int8(comma.utf8[comma.startIndex]))
        let space = " "
        XCTAssertEqual(UInt8.whitespace, space.utf8[space.startIndex])
        let newline = "\n"
        XCTAssertEqual(UInt8.newline, newline.utf8[newline.startIndex])
        let at = "@"
        XCTAssertEqual(UInt8.at, at.utf8[at.startIndex])
        let question = "?"
        XCTAssertEqual(UInt8.questionMark, question.utf8[question.startIndex])
    }

}
