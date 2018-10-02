//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

@testable import Cyborg
import XCTest

class NoTheme: ValueProviding {

    func colorFromResources(named _: String) -> UIColor {
        return .black
    }

    func colorFromTheme(named _: String) -> UIColor {
        return .black
    }
}

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
        switch VectorDrawable.create(from: data) {
        case .ok(let drawable):
            XCTAssert(drawable.viewPortWidth == 600)
            XCTAssert(drawable.viewPortHeight == 600)
            XCTAssert(((drawable.groups[0] as! VectorDrawable.Group).children[0] as! VectorDrawable.Path).data.count != 0)
            let noResizing = CGSize(width: 1, height: 1)
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
                .apply(to: expected,
                       relativeTo: .init(width: 64 / 600, height: 64 / 600))
                .mutableCopy()!
            let layers = drawable.layerRepresentation(in: CGRect(origin: .zero,
                                                                 size: noResizing),
                                                      using: NoTheme())
            let layer = layers[0] as! ThemeableShapeLayer
            layer.frame = .init(origin: .zero,
                                size: .init(width: 64, height: 64))
            layer.layoutSublayers()
            XCTAssertEqual(layer.path, expected)
        case .error(let error):
            XCTFail(error)
        }
    }

    func test_move() {
        let (move, buffer) = XMLString.create(from: "M300,70")
        defer {
            buffer.deallocate()
        }
        let result = parseMoveAbsolute()(move, 0)
        let expected = CGMutablePath()
        let distance = CGPoint(x: 300, y: 70)
        let movement: DrawingCommand = .moveAbsolute(distance)
        expected.move(to: distance)
        switch result {
        case .ok(let pathSegment, _):
            let path = createPath(from: pathSegment)
            XCTAssertEqual(path, expected)
            XCTAssertEqual(movement, pathSegment[0])
        case .error(let error):
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
        case .ok(let wrapped, let index):
            let path = createPath(from: wrapped)
            XCTAssertEqual(index, close.count)
            XCTAssertEqual(path, expected)
        case .error(let error):
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
            case .error(let error):
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
            case .ok(let result, let index):
                XCTAssertEqual(result, -432)
                XCTAssertEqual(index, str.count)
            case .error(let error):
                XCTFail(error)
            }
        }
        "40".withXMLString { str2 in
            switch Cyborg.number(from: str2, at: 0) {
            case .ok(let result, let index):
                XCTAssertEqual(result, 40)
                XCTAssertEqual(index, str2.count)
            case .error(let error):
                XCTFail(error)
            }
        }
        "4".withXMLString { str3 in
            switch Cyborg.number(from: str3, at: 0) {
            case .ok(let result, let index):
                XCTAssertEqual(result, 4)
                XCTAssertEqual(index, str3.count)
            case .error(let error):
                XCTFail(error)
            }
        }
        "4.4 ".withXMLString { str4 in
            switch Cyborg.number(from: str4, at: 0) {
            case .ok(let result, let index):
                XCTAssertEqual(result, 4.4)
                XCTAssertEqual(index, str4.count - 1)
            case .error(let error):
                XCTFail(error)
            }
        }
        ".9 ".withXMLString { str5 in
            switch Cyborg.number(from: str5, at: 0) {
            case .ok(let result, let index):
                XCTAssertEqual(result, 0.9)
                XCTAssertEqual(index, str5.count - 1)
            case .error(let error):
                XCTFail(error)
            }
        }
        "-.9 ".withXMLString { str6 in
            switch Cyborg.number(from: str6, at: 0) {
            case .ok(let result, let index):
                XCTAssertEqual(result, -0.9)
                XCTAssertEqual(index, str6.count - 1)
            case .error(let error):
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
        case .ok(let wrapped, let index):
            let result = CGMutablePath()
            result.move(to: start)
            _ = createPath(from: wrapped, start: start.asPriorContext, path: result)
            XCTAssertEqual(result, expected)
            XCTAssertEqual(index, curve.count)
        case .error(let error):
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
        case .ok(let result, let index):
            XCTAssert(result == expected)
            XCTAssertEqual(index, text.count)
        case .error(let error):
            XCTFail(error)
        }
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

func createPath(from pathSegment: PathSegment,
                start: PriorContext = .zero,
                path: CGMutablePath = CGMutablePath()) -> CGMutablePath {
    var priorContext: PriorContext = start
    for segment in pathSegment {
        priorContext = segment.apply(to: path, using: priorContext, in: .identity)
    }
    return path
}

extension String {

    func withXMLString(_ function: (XMLString) -> ()) {
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
                                      capacity: string.utf8.count + 1, { pointer in
                                          let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: string.count + 1)
                                          for i in 0..<string.utf8.count + 1 {
                                              buffer.advanced(by: i).pointee = pointer.advanced(by: i).pointee
                                          }
                                          return (XMLString(buffer, count: Int32(string.utf8.count)), buffer)
            })
        }
    }

}

extension ParseResult {

    var asOptional: (Wrapped, Int32)? {
        switch self {
        case .ok(let wrapped): return wrapped
        case .error: return nil
        }
    }

}
