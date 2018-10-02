//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

@testable import Cyborg
import XCTest

class XMLStringTests: XCTestCase {

    func test_subscript() {
        "abc"
            .withXMLString { string in
                XCTAssertEqual(string[0], "a".utf8["a".startIndex])
                XCTAssertEqual(string[1], "b".utf8["b".startIndex])
                XCTAssertEqual(string[2], "c".utf8["c".startIndex])
            }
        "abc"
            .withXMLString { string in
                XCTAssertEqual(string[safeIndex: 0], "a".utf8["a".startIndex])
                XCTAssertEqual(string[safeIndex: 1], "b".utf8["b".startIndex])
                XCTAssertEqual(string[safeIndex: 2], "c".utf8["c".startIndex])
                XCTAssertEqual(string[safeIndex: 3], nil)
            }
    }

    func test_range_subscript() {
        "abc"
            .withXMLString { string in
                XCTAssert("ab" ~= string[0..<2])
                XCTAssert("abc" ~= string[0..<3])
                XCTAssert(!("abd" ~= string[0..<3]))
                XCTAssert("" ~= string[0..<0])
            }
    }

    func test_equality() {
        "abc"
            .withXMLString { string in
                "abc"
                    .withXMLString { string2 in
                        XCTAssert(string == string2)
                    }
                "ab"
                    .withXMLString { string2 in
                        XCTAssert(string != string2)
                    }
            }
    }

    func test_matches() {
        "abc"
            .withXMLString { string in
                "ab"
                    .withXMLString { string2 in
                        XCTAssert(string.matches(string2,
                                                 at: 0))
                    }
                "bc"
                    .withXMLString { string2 in
                        XCTAssert(string.matches(string2,
                                                 at: 1))
                    }
                ""
                    .withXMLString { string2 in
                        XCTAssert(string.matches(string2,
                                                 at: 0))
                    }
                "ac"
                    .withXMLString { string2 in
                        XCTAssert(!string.matches(string2,
                                                  at: 0))
                    }
            }
    }

    func test_switch_equality() {
        XCTAssert("a" ~= XMLString.a)
        "abc"
            .withXMLString { str in
                XCTAssert("abc" ~= str)
            }
        ""
            .withXMLString { str in
                XCTAssert("" ~= str)
            }
        ""
            .withXMLString { str in
                XCTAssert(!("jldsa" ~= str))
            }
        "🇳🇱"
            .withXMLString { str in
                XCTAssert("🇳🇱" ~= str)
            }
    }

}

class ConversionTests: XCTestCase {

    func test_create_cgfloat() {
        "afd"
            .withXMLString { str in
                XCTAssertEqual(CGFloat(str), nil)
            }
        "134"
            .withXMLString { str in
                XCTAssertEqual(CGFloat(str), 134)
            }
        "0.12e25"
            .withXMLString { str in
                XCTAssertEqual(CGFloat(str), 0.12e25)
            }
        "0e45"
            .withXMLString { str in
                XCTAssertEqual(CGFloat(str), 0e45)
            }
        "-0e-45"
            .withXMLString { str in
                XCTAssertEqual(CGFloat(str), -0e-45)
            }
        "-1"
            .withXMLString { str in
                XCTAssertEqual(CGFloat(str), -1)
            }
    }

    func test_create_bool() {
        ""
            .withXMLString { str in
                XCTAssertEqual(Bool(str), nil)
            }
        "False"
            .withXMLString { str in
                XCTAssertEqual(Bool(str), nil)
            }
        "false"
            .withXMLString { str in
                XCTAssertEqual(Bool(str), false)
            }
        "True"
            .withXMLString { str in
                XCTAssertEqual(Bool(str), nil)
            }
        "true"
            .withXMLString { str in
                XCTAssertEqual(Bool(str), true)
            }
    }

}
