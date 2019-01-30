//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

@testable import Cyborg
import XCTest

class DrawingCommandTests: XCTestCase {

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
        case .error(let error, _):
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
        case .error(let error, _):
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
            case .error(let error, _):
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
        case .error(let error, _):
            XCTFail(error)
        }
    }

    func test_parse_vertical() {
        "v 1 4 5"
            .withXMLString { string in
                switch parseVertical()(string, 0) {
                case .ok(let wrapped, let index):
                    XCTAssertEqual(index, string.count)
                    let expected = CGMutablePath()
                    expected.move(to: .zero)
                    expected.addLine(to: .init(x: 0, y: 1))
                    expected.addLine(to: .init(x: 0, y: 5))
                    expected.addLine(to: .init(x: 0, y: 10))
                    let result = CGMutablePath()
                    result.move(to: .zero)
                    _ = createPath(from: wrapped, path: result)
                    XCTAssertEqual(result, expected)
                case .error(let error, _):
                    XCTFail(error)
                }
            }
    }

    func test_parse_absolute_vertical() {
        "V 1 4 5"
            .withXMLString { string in
                switch parseVerticalAbsolute()(string, 0) {
                case .ok(let wrapped, let index):
                    XCTAssertEqual(index, string.count)
                    let expected = CGMutablePath()
                    expected.move(to: .zero)
                    expected.addLine(to: .init(x: 0, y: 1))
                    expected.addLine(to: .init(x: 0, y: 4))
                    expected.addLine(to: .init(x: 0, y: 5))
                    let result = CGMutablePath()
                    result.move(to: .zero)
                    _ = createPath(from: wrapped, path: result)
                    XCTAssertEqual(result, expected)
                case .error(let error, _):
                    XCTFail(error)
                }
            }
    }

    func test_Matrix2x2d_multiplication() {
        let point = CGPoint(x: 1, y: 0)
        assertAlmostEqual(rotation(angle: 90 * .pi / 180).times(point), CGPoint(x: 0, y: 1))
        assertAlmostEqual(rotation(angle: 360 * .pi / 180).times(point), point)
        assertAlmostEqual(rotation(angle: 180 * .pi / 180).times(point), CGPoint(x: -1, y: 0))
    }

    func test_sphericalArc() {
        let arc = EllipticArc(center: .zero,
                              radius: .init(x: 5, y: 5),
                              xAngle: 0)
        XCTAssertEqual(arc.point(for: 0), CGPoint(x: 5, y: 0))
        assertAlmostEqual(arc.point(for: 90 * .pi / 180), CGPoint(x: 0, y: 5))
        assertAlmostEqual(arc.point(for: 180 * .pi / 180), CGPoint(x: -5, y: 0))
    }

    func test_ellipticArc() {
        let arc = EllipticArc(center: .zero,
                              radius: .init(x: 10, y: 5),
                              xAngle: 0)
        XCTAssertEqual(arc.point(for: 0), CGPoint(x: 10, y: 0))
    }

    func test_ellipticArcXAngle() {
        let arc = EllipticArc(center: .zero,
                              radius: .init(x: 10, y: 5),
                              xAngle: .pi)
        assertAlmostEqual(arc.point(for: 0), CGPoint(x: -10, y: 0))
        assertAlmostEqual(arc.point(for: .pi), CGPoint(x: 10, y: 0))
    }

    func rotation(angle: CGFloat) -> Matrix2x2 {
        return .init(m00: cos(angle),
                     m01: sin(angle),
                     m10: -sin(angle),
                     m11: cos(angle))
    }

}

func assertAlmostEqual(_ lhs: CGPoint,
                       _ rhs: CGPoint,
                       line: UInt = #line) {
    let error: CGFloat = 0.001 // TODO: I just picked this number arbitrarily
    XCTAssert(abs(lhs.x - rhs.x) < error && abs(lhs.y - rhs.y) < error,
              "\(lhs), \(rhs) are not close to equal.", line: line)
}

func consumeTrivia<T>(before: @escaping Parser<T>) -> Parser<T> {
    return { stream, index in
        var next = index
        while next != stream.count,
            stream[next] == .whitespace || stream[next] == .newline {
                next += 1
        }
        return before(stream, next)
    }
}
