//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

@testable import Cyborg
import XCTest

class CyborgTests: XCTestCase {
    let string = """
     <vector xmlns:android="http://schemas.android.com/apk/res/android"
         android:height="64dp"
         android:width="64dp"
         android:viewportHeight="600"
         android:viewportWidth="600" >
         <group
             android:name="rotationGroup"
             android:pivotX="300.0"
             android:pivotY="300.0"
             android:rotation="45.0" >
             <path
                 android:name="v"
                 android:fillColor="#000000"
                 android:pathData="M300,70 l 0,-70 70,70 0,0 -70,70z" />
         </group>
     </vector>
    """

    func test_Deserialize() {
        let data = string.data(using: .utf8)!
        let callbackIsCalled = expectation(description: "Callback is called")
        VectorDrawable
            .create(from: data) { result in
                callbackIsCalled.fulfill()
                switch result {
                case let .ok(drawable):
                    XCTAssert(drawable.viewPortWidth == 600)
                    XCTAssert(drawable.viewPortHeight == 600)
                    XCTAssert(((drawable.groups[0] as! VectorDrawable.Group).children[0] as! VectorDrawable.Path).data.count != 0)
                    let noResizing = CGSize(width: 1, height: 1)
                    let path = drawable.createPaths(in: noResizing)
                    var expected = CGMutablePath()
                    var relativeTo = CGPoint(x: 300, y: 70)
                    expected.move(to: relativeTo)
                    let list = [
                        CGPoint(x: 0, y: -70),
                        CGPoint(x: 70, y: 70),
                        CGPoint(x: 0, y: 0),
                        CGPoint(x: -70, y: 70),
                    ]
                    for point in list {
                        let point = point.add(relativeTo)
                        expected.addLine(to: point)
                        relativeTo = point
                    }
                    expected.closeSubpath()
                    let transform = (drawable
                        .groups[0] as! VectorDrawable.Group)
                        .transform
                    expected = transform
                        .apply(to: expected, in: noResizing)
                        .mutableCopy()!
                    XCTAssertEqual(path[0], expected)
                case let .error(error):
                    XCTFail(error)
                }
            }
        wait(for: [callbackIsCalled], timeout: 0.001) // note: this is actually synchronous, but just in case it isn't called, check to make sure it actually happens
    }

    func test_move() {
        let (move, buffer) = XMLString.create(from: "M300,70")
        defer {
            buffer.deallocate()
        }
        let result = parseMoveAbsolute()(move, 0)
        let path = CGMutablePath()
        let expected = CGMutablePath()
        let movement: PriorContext = CGPoint(x: 300, y: 70).asPriorContext
        expected.move(to: movement.point)
        switch result {
        case .ok(let pathSegment, _):
            let next = pathSegment(.zero, path, .init(width: 1, height: 1))
            XCTAssertEqual(path, expected)
            XCTAssertEqual(next, movement)
        case let .error(error):
            XCTFail(error)
        }
    }

    func test_closePath() {
        let (close, buffer) = XMLString.create(from: "   z")
        defer {
            buffer.deallocate()
        }
        let result = consumeTrivia(before: parseClosePath())(close, 0)
        let expected = CGMutablePath()
        expected.closeSubpath()
        switch result {
        case let .ok(wrapped, index):
            let path = CGMutablePath()
            _ = wrapped(.zero, path, .zero)
            XCTAssertEqual(index, close.count)
            XCTAssertEqual(path, expected)
        case let .error(error):
            XCTFail(error)
        }
    }

    func test_line() {
        "l 1,0 2,1 3,4".withXMLString { lineData in
            let expected = CGMutablePath()
            let points = [(1, 0), (2, 1), (3, 4)].map(CGPoint.init)
            var last: CGPoint = .zero
            for point in points {
                let point = point.add(last)
                last = point
                expected.addLine(to: point)
            }
            switch parseLine()(lineData, 0) {
            case .ok(let result, _):
                let path = createPath(from: result)
                XCTAssertEqual(path, expected)
            case let .error(error):
                XCTFail(error)
            }
        }
    }

    func test_oneorMoreOf() {
        "a".withXMLString { str in
            "aaa".withXMLString { contents in
                XCTAssertEqual(oneOrMore(of: literal(str))(contents, 0).asOptional?.0,
                               Array(repeating: str, count: 3))
                "   a a   a".withXMLString { contents2 in
                    XCTAssertEqual(oneOrMore(of: consumeTrivia(before: literal(str)))(contents2, 0).asOptional?.0,
                                   Array(repeating: str, count: 3))
                }
            }
        }
    }

    func test_number_parser() {
        "-432".withXMLString { str in
            switch Cyborg.number(from: str, at: 0) {
            case let .ok(result, index):
                XCTAssertEqual(result, -432)
                XCTAssertEqual(index, str.count)
            case let .error(error):
                XCTFail(error)
            }
        }
        "40".withXMLString { str2 in
            switch Cyborg.number(from: str2, at: 0) {
            case let .ok(result, index):
                XCTAssertEqual(result, 40)
                XCTAssertEqual(index, str2.count)
            case let .error(error):
                XCTFail(error)
            }
        }
        "4".withXMLString { str3 in
            switch Cyborg.number(from: str3, at: 0) {
            case let .ok(result, index):
                XCTAssertEqual(result, 4)
                XCTAssertEqual(index, str3.count)
            case let .error(error):
                XCTFail(error)
            }
        }
        "4.4 ".withXMLString { str4 in
            switch Cyborg.number(from: str4, at: 0) {
            case let .ok(result, index):
                XCTAssertEqual(result, 4.4)
                XCTAssertEqual(index, str4.count - 1)
            case let .error(error):
                XCTFail(error)
            }
        }
        ".9 ".withXMLString { str5 in
            switch Cyborg.number(from: str5, at: 0) {
            case let .ok(result, index):
                XCTAssertEqual(result, 0.9)
                XCTAssertEqual(index, str5.count - 1)
            case let .error(error):
                XCTFail(error)
            }
        }
        "-.9 ".withXMLString { str6 in
            switch Cyborg.number(from: str6, at: 0) {
            case let .ok(result, index):
                XCTAssertEqual(result, -0.9) // TODO: is this actually valid? Swift doesn't accept this
                XCTAssertEqual(index, str6.count - 1)
            case let .error(error):
                XCTFail(error)
            }
        }
    }

    func test_parse_curve() {
        let (curve, buffer) = XMLString.create(from: "c2,2 3,2 8,2")
        defer {
            buffer.deallocate()
        }
        let start = CGPoint(x: 6, y: 2)
        let expected = CGMutablePath()
        expected.move(to: start)
        expected.addCurve(to: CGPoint(x: 8, y: 2).add(start),
                          control1: CGPoint(x: 2, y: 2).add(start),
                          control2: CGPoint(x: 3, y: 2).add(start))
        switch parseCurve()(curve, 0) {
        case let .ok(wrapped, index):
            let result = CGMutablePath()
            result.move(to: start)
            _ = wrapped(start.asPriorContext, result, CGSize(width: 1, height: 1))
            XCTAssertEqual(result, expected)
            XCTAssertEqual(index, curve.count)
        case let .error(error):
            XCTFail(error)
        }
    }

    func test_complex_number() {
        let (text, buffer) = XMLString.create(from: "-2.38419e-08")
        defer {
            buffer.deallocate()
        }
        let expected: CGFloat = -2.38419e-08
        switch number(from: text, at: 0) {
        case let .ok(result, index):
            XCTAssert(result == expected)
            XCTAssertEqual(index, text.count)
        case let .error(error):
            XCTFail(error)
        }
    }

    func test_make_absolute() {
        let input = [(1, 1), (1, 1), (1, 1)].map(CGPoint.init)
        let first = input.makeAbsolute(startingWith: .init((1, 1)),
                                       in: .identity)
        XCTAssertEqual(first, [(2, 2), (3, 3), (4, 4)].map(CGPoint.init))
        let scaled = input.makeAbsolute(startingWith: .init((1, 1)),
                                        in: .init(width: 0.5, height: 0.5))
        XCTAssertEqual(scaled, [(1.5, 1.5), (2, 2), (2.5, 2.5)].map(CGPoint.init))
        let skipOne = input.makeAbsolute(startingWith: .init((1, 1)),
                                         in: .identity,
                                         elementSize: 1)
        XCTAssertEqual(skipOne, [(2, 2), (2, 2), (3, 3)].map(CGPoint.init))
        let input2 = [(1, 1), (1, 1), (1, 1), (1, 1)].map(CGPoint.init)
        let skipTwo = input2.makeAbsolute(startingWith: .init((1, 1)),
                                          in: .identity,
                                          elementSize: 2)
        XCTAssertEqual(skipTwo, [(2, 2), (2, 2), (2, 2), (3, 3)].map(CGPoint.init))
        let input3 = [(1, 1), (1, 1), (1, 1), (1, 1), (1, 1)].map(CGPoint.init)
        let skipThree = input3.makeAbsolute(startingWith: .init((1, 1)),
                                            in: .identity,
                                            elementSize: 3)
        XCTAssertEqual(skipThree, [(2, 2), (2, 2), (2, 2), (2, 2), (3, 3)].map(CGPoint.init))
    }
}

extension CGPoint {
    init(_ xy: (CGFloat, CGFloat)) {
        self.init(x: xy.0, y: xy.1)
    }
}

extension CGSize {
    static let identity = CGSize(width: 1, height: 1)
}

func createPath(from: PathSegment, start: PriorContext = .zero) -> CGMutablePath {
    let path = CGMutablePath()
    _ = from(start, path, .identity)
    return path
}

extension String {
    func withXMLString(_ function: (XMLString) -> Void) {
        let (string, buffer) = XMLString.create(from: self)
        defer {
            buffer.deallocate()
        }
        function(string)
    }
}

extension XMLString {
    static func create(from string: String) -> (XMLString, UnsafeMutablePointer<UInt8>) {
        return string.withCString { pointer in
            pointer.withMemoryRebound(to: UInt8.self,
                                      capacity: string.count + 1, { pointer in
                                          let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: string.count + 1)
                                          for i in 0 ..< string.count + 1 {
                                              buffer.advanced(by: i).pointee = pointer.advanced(by: i).pointee
                                          }
                                          return (XMLString(buffer, count: Int32(string.count)), buffer)
            })
        }
    }
}
