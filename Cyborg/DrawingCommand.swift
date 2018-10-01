//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

import Foundation

enum DrawingCommand {

    case move(CGPoint)
    case moveAbsolute(CGPoint)
    case curve(CGPoint, CGPoint, CGPoint)
    case curveAbsolute(CGPoint, CGPoint, CGPoint)
    case line(CGPoint)
    case lineAbsolute(CGPoint)
    case horizontal(CGFloat)
    case horizontalAbsolute(CGFloat)
    case vertical(CGFloat)
    case verticalAbsolute(CGFloat)
    case smoothCurve(CGPoint, CGPoint)
    case quadratic(CGPoint, CGPoint)
    case quadraticAbsolute(CGPoint, CGPoint)
    case closePath
    case closePathAbsolute

    func apply(to path: CGMutablePath, using prior: PriorContext, in size: CGSize) -> PriorContext {
        switch self {
        case .move(let point):
            let next = point.times(size).add(prior.point)
            path.move(to: next)
            return next.asPriorContext
        case .moveAbsolute(let point):
            let next = point.times(size)
            path.move(to: next)
            return next.asPriorContext
        case .curve(let control1, let control2, let end):
            let intoAbsolute = prior.point
            let control1 = control1.times(size).add(intoAbsolute)
            let control2 = control2.times(size).add(intoAbsolute)
            let end = end.times(size).add(intoAbsolute)
            path.addCurve(to: end, control1: control1, control2: control2)
            return .lastAndControlPoint(end, control2.reflected(across: end))
        case .curveAbsolute(let control1, let control2, let end):
            let control1 = control1.times(size)
            let control2 = control2.times(size)
            let end = end.times(size)
            path.addCurve(to: end, control1: control1, control2: control2)
            return .lastAndControlPoint(end, control2.reflected(across: end))
        case .line(let point):
            let point = point.times(size).add(prior.point)
            path.addLine(to: point)
            return point.asPriorContext
        case .lineAbsolute(let point):
            let point = point.times(size)
            path.addLine(to: point)
            return point.asPriorContext
        case .horizontal(let magnitude):
            let last = prior.point
            let next = CGPoint(x: magnitude * size.width + last.x, y: last.y)
            path.addLine(to: next)
            return next.asPriorContext
        case .horizontalAbsolute(let magnitude):
            let last = prior.point
            let next = CGPoint(x: magnitude * size.width, y: last.y)
            path.addLine(to: next)
            return next.asPriorContext
        case .vertical(let magnitude):
            let last = prior.point
            let next = CGPoint(x: last.x, y: magnitude * size.height + last.y)
            path.addLine(to: next)
            return next.asPriorContext
        case .verticalAbsolute(let magnitude):
            let last = prior.point
            let next = CGPoint(x: last.x, y: magnitude * size.height)
            path.addLine(to: next)
            return next.asPriorContext
        case .smoothCurve(let control2, let end):
            let (last, control1) = prior.pointAndControlPoint
            let end = end.times(size).add(last)
            let control2 = control2.times(size).add(last)
            path.addCurve(to: end, control1: control1, control2: control2)
            return .lastAndControlPoint(end,
                                        control2.reflected(across: end))
        case .quadratic(let control1, let end):
            let last = prior.point
            let end = end.times(size).add(last)
            let control1 = control1.times(size).add(last)
            path.addQuadCurve(to: end, control: control1)
            return end.asPriorContext
        case .quadraticAbsolute(let control1, let end):
            let end = end.times(size)
            let control1 = control1.times(size)
            path.addQuadCurve(to: end, control: control1)
            return end.asPriorContext
        case .closePath, .closePathAbsolute:
            path.closeSubpath()
            return path.currentPoint.asPriorContext
        }
    }

}

enum PriorContext: Equatable {

    case last(CGPoint)
    case lastAndControlPoint(CGPoint, CGPoint)

    var point: CGPoint {
        switch self {
        case .last(let point): return point
        case .lastAndControlPoint(let point, _): return point
        }
    }

    var pointAndControlPoint: (point: CGPoint, controlPoint: CGPoint) {
        switch self {
        // per the spec, if there is no last control point, the
        // control point is coincident to the last point
        case .last(let point): return (point, point)
        case .lastAndControlPoint(let point, let controlPoint): return (point, controlPoint)
        }
    }

    static let zero: PriorContext = .last(.zero)

    static func == (lhs: PriorContext, rhs: PriorContext) -> Bool {
        switch (lhs, rhs) {
        case (.last(let lhs), .last(let rhs)): return lhs == rhs
        case (.lastAndControlPoint(let lhsPoint, let lhsControl),
              .lastAndControlPoint(let rhsPoint, let rhsControl)): return lhsPoint == rhsPoint && lhsControl == rhsControl
        default: return false
        }
    }

}

extension CGPoint {
    var asPriorContext: PriorContext {
        return .last(self)
    }
}

typealias PathSegment = [DrawingCommand]

func parse<T>(command: XMLString,
              followedBy: @escaping Parser<T>,
              convertToPathCommandsWith convert: @escaping (T) -> PathSegment) -> Parser<PathSegment> {
    return { stream, index in
        literal(command, discardErrorMessage: true)(stream, index)
            .chain(into: stream) { stream, index in
                followedBy(stream, index)
                    .map { result, index in
                        .ok(convert(result), index)
                    }
            }
    }
}

func parseCurve() -> Parser<PathSegment> {
    return parse(command: .c,
                 followedBy: 3.coordinatePairs(),
                 convertToPathCommandsWith: { (points: [[CGPoint]]) -> PathSegment in
                     points.map { points in
                         let control1 = points[0],
                             control2 = points[1],
                             end = points[2]
                         return .curve(control1, control2, end)
                     }
    })
}

func parseAbsoluteCurve() -> Parser<PathSegment> {
    return parse(command: .C,
                 followedBy: 3.coordinatePairs(),
                 convertToPathCommandsWith: { (points: [[CGPoint]]) -> PathSegment in
                     points.map { points in
                         let control1 = points[0],
                             control2 = points[1],
                             end = points[2]
                         return .curveAbsolute(control1, control2, end)
                     }
    })
}

func parseMoveAbsolute() -> Parser<PathSegment> {
    return parse(command: .M,
                 followedBy: 1.coordinatePairs(),
                 convertToPathCommandsWith: { (points) -> PathSegment in
                     points.map { points in
                         .moveAbsolute(points[0])
                     }
    })
}

func parseMove() -> Parser<PathSegment> {
    return parse(command: .m,
                 followedBy: 1.coordinatePairs(),
                 convertToPathCommandsWith: { (points) -> PathSegment in
                     points.map { points in
                         .move(points[0])
                     }
    })
}

func parseLine() -> Parser<PathSegment> {
    return parse(command: .l,
                 followedBy: oneOrMore(of: coordinatePair()),
                 convertToPathCommandsWith: { (points: [CGPoint]) -> PathSegment in
                     points.map { point in
                         .line(point)
                     }
    })
}

func parseLineAbsolute() -> Parser<PathSegment> {
    return parse(command: .L,
                 followedBy: oneOrMore(of: coordinatePair()),
                 convertToPathCommandsWith: { (points: [CGPoint]) -> PathSegment in
                     points.map { point in
                         .line(point)
                     }
    })
}

func parseClosePath() -> Parser<PathSegment> {
    return parse(command: .z,
                 followedBy: empty(),
                 convertToPathCommandsWith: {
                     [.closePath]
    })
}

func parseClosePathAbsolute() -> Parser<PathSegment> {
    return parse(command: .Z,
                 followedBy: empty(),
                 convertToPathCommandsWith: {
                     [.closePathAbsolute]
    })
}

func parseHorizontal() -> Parser<PathSegment> {
    return parse(command: .h,
                 followedBy: numbers(),
                 convertToPathCommandsWith: { (numbers: [CGFloat]) -> PathSegment in
                     numbers.map { magnitude in
                         .horizontal(magnitude)
                     }
    })
}

func parseHorizontalAbsolute() -> Parser<PathSegment> {
    return parse(command: .H,
                 followedBy: numbers(),
                 convertToPathCommandsWith: { (numbers: [CGFloat]) -> PathSegment in
                     numbers.map { magnitude in
                         .horizontalAbsolute(magnitude)
                     }
    })
}

func parseVertical() -> Parser<PathSegment> {
    return parse(command: .v,
                 followedBy: numbers(),
                 convertToPathCommandsWith: { (numbers: [CGFloat]) -> PathSegment in
                     numbers.map { magnitude in
                         .vertical(magnitude)
                     }
    })
}

func parseVerticalAbsolute() -> Parser<PathSegment> {
    return parse(command: .V,
                 followedBy: numbers(),
                 convertToPathCommandsWith: { (numbers: [CGFloat]) -> PathSegment in
                     numbers.map { magnitude in
                         .verticalAbsolute(magnitude)
                     }
    })
}

func parseSmoothCurve() -> Parser<PathSegment> {
    return parse(command: .s,
                 followedBy: 2.coordinatePairs(),
                 convertToPathCommandsWith: { (points: [[CGPoint]]) -> PathSegment in
                     points.map { pair in
                         let end = pair[1],
                             controlPoint = pair[0]
                         return .smoothCurve(controlPoint, end)
                     }
    })
}

func parseQuadratic() -> Parser<PathSegment> {
    return parse(command: .q,
                 followedBy: 2.coordinatePairs(),
                 convertToPathCommandsWith: { (points: [[CGPoint]]) -> PathSegment in
                     points.map { pair in
                         let end = pair[1],
                             controlPoint1 = pair[0]
                         return .quadratic(controlPoint1, end)
                     }
    })
}

func parseQuadraticAbsolute() -> Parser<PathSegment> {
    return parse(command: .Q,
                 followedBy: 2.coordinatePairs(),
                 convertToPathCommandsWith: { (points: [[CGPoint]]) -> PathSegment in
                     points.map { pair in
                         let end = pair[1],
                             controlPoint1 = pair[0]
                         return .quadraticAbsolute(controlPoint1, end)
                     }
    })
}

let allDrawingCommands: [Parser<PathSegment>] = [
    parseCurve(),
    parseAbsoluteCurve(),
    parseLine(),
    parseLineAbsolute(),
    parseMove(),
    parseMoveAbsolute(),
    parseHorizontal(),
    parseHorizontalAbsolute(),
    parseVertical(),
    parseVerticalAbsolute(),
    parseQuadratic(),
    parseQuadraticAbsolute(),
    parseSmoothCurve(),
    parseClosePath(),
    parseClosePathAbsolute(),
]

extension CGPoint {

    func add(_ rhs: CGPoint) -> CGPoint {
        return .init(x: x + rhs.x, y: y + rhs.y)
    }

    func subtract(_ rhs: CGPoint) -> CGPoint {
        return .init(x: x - rhs.x, y: y - rhs.y)
    }

    func times(_ x1: CGFloat, _ y1: CGFloat) -> CGPoint {
        return .init(x: x * x1, y: y * y1)
    }

    func times(_ size: CGSize) -> CGPoint {
        return .init(x: x * size.width, y: y * size.height)
    }

    func times(_ other: CGPoint) -> CGPoint {
        return times(other.x, other.y)
    }

    func dot(_ other: CGPoint) -> CGFloat {
        return (x * other.x) + (y * other.y)
    }

    func reflected(across current: CGPoint) -> CGPoint {
        let newX = current.x * 2 - x
        let newY = current.y * 2 - y
        return CGPoint(x: newX, y: newY)
    }

}

extension Int {

    func coordinatePairs() -> Parser<[[CGPoint]]> {
        return { stream, index in
            var floats = [CGFloat]()
            floats.reserveCapacity(self * 2)
            var found = 0
            var next = index
            while case .ok(let value, let index) = number(from: stream, at: next) {
                floats.insert(value, at: found)
                next = index
                found += 1
            }
            if found % 2 == 0 && (found / 2) % self == 0 {
                let numberOfCommandsFound = (found / 2) / self
                var results = [[CGPoint]](repeating: [CGPoint](repeating: .zero, count: self), count: numberOfCommandsFound)
                for i in 0..<numberOfCommandsFound {
                    for j in 0..<self {
                        results[i][j] = CGPoint(x: floats[(i * self + j) * 2],
                                                y: floats[(i * self + j) * 2 + 1])
                    }
                }
                return .ok(results, next)
            } else {
                return .error("")
            }
        }
    }

}
