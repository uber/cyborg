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

}
