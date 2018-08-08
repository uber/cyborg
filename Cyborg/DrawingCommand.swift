//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

import Foundation

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
    
    static func ==(lhs: PriorContext, rhs: PriorContext) -> Bool {
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

typealias PathSegment = (PriorContext, CGMutablePath, CGSize) -> (PriorContext)

func consumeTrivia(before lit: String , _ next: @escaping Parser<PathSegment>) -> Parser<PathSegment> {
    return consumeTrivia { stream, index in
        return literal(lit)(stream, index)
            .chain(into: stream, next)
    }
}

func parseCommand<T>(_ command: DrawingCommand,
                     subparser: @escaping Parser<T>,
                     creator: @escaping (T) -> (PathSegment)) -> Parser<PathSegment> {
    return consumeTrivia(before: command.rawValue) { stream, index in
        subparser(stream, index)
            .map { result, index in
                .ok(creator(result), index)
        }
    }
}

func parseCurve() -> Parser<PathSegment> {
    return parseCommand(.curve,
                        subparser: oneOrMore(of: n(3,
                                                   of: consumeTrivia(before: coordinatePair()))),
                        creator: { (points: [[CGPoint]]) -> (PathSegment) in
                            return { prior, path, size in
                                points.reduce(.zero) { (result, points) -> PriorContext in
                                    let points = points.makeAbsolute(startingWith: prior.point,
                                                                     in: size,
                                                                     elementSize: 3)
                                    let control1 = points[0],
                                    control2 = points[1],
                                    end = points[2]
                                    path.addCurve(to: end,
                                                  control1: control1,
                                                  control2: control2)
                                    return end.asPriorContext
                                }
                            }
    })
}

func parseAbsoluteCurve() -> Parser<PathSegment> {
    return parseCommand(.curveAbsolute,
                        subparser: oneOrMore(of: n(3,
                                                   of: consumeTrivia(before: coordinatePair()))),
                        creator: { (points: [[CGPoint]]) -> (PathSegment) in
                            return { prior, path, size in
                                points.reduce(.zero) { (result, points) -> PriorContext in
                                    let points = points.scaleTo(size: size)
                                    let control1 = points[0],
                                    control2 = points[1],
                                    end = points[2]
                                    path.addCurve(to: end,
                                                  control1: control1,
                                                  control2: control2)
                                    return end.asPriorContext
                                }
                            }
    })
}

func parseMoveAbsolute() -> Parser<PathSegment> {
    return parseCommand(.moveAbsolute,
                        subparser: consumeTrivia(before: coordinatePair()),
                        creator: { (point) -> (PathSegment) in
                            return { _, path, size in
                                let point = point.times(size.width, size.height)
                                path.move(to: point)
                                return point.asPriorContext
                            }
    })
}

func parseMove() -> Parser<PathSegment> {
    return parseCommand(.move,
                        subparser: consumeTrivia(before: coordinatePair()),
                        creator: { (point) -> (PathSegment) in
                            return { prior, path, size in
                                let point = point.times(size.width, size.height).add(prior.point)
                                path.move(to: point)
                                return point.asPriorContext
                            }
    })
}


func parseLine() -> Parser<PathSegment> {
    return parseCommand(.line,
                        subparser: oneOrMore(of: consumeTrivia(before: coordinatePair())),
                        creator: { (points: [CGPoint]) -> (PathSegment) in
                            return { (prior: PriorContext, path: CGMutablePath, size: CGSize) -> PriorContext in
                                let points = points.makeAbsolute(startingWith: prior.point, in: size)
                                return points.reduce(.zero) { result, point -> PriorContext in
                                    path.addLine(to: point)
                                    return point.asPriorContext
                                }
                            }
    })
}

func parseLineAbsolute() -> Parser<PathSegment> {
    return parseCommand(.lineAbsolute,
                        subparser: oneOrMore(of: consumeTrivia(before: coordinatePair())),
                        creator: { (points: [CGPoint]) -> (PathSegment) in
                            return { (prior: PriorContext, path: CGMutablePath, size: CGSize) -> PriorContext in
                                let points = points.scaleTo(size: size)
                                return points.reduce(.zero) { result, point -> PriorContext in
                                    path.addLine(to: point)
                                    return point.asPriorContext
                                }
                            }
    })
}


func parseClosePath() -> Parser<PathSegment> {
    return parseCommand(.closePath,
                        subparser: empty(),
                        creator: { (_) -> (PathSegment) in
                            return { prior, path, _ in
                                path.closeSubpath()
                                return prior
                            }
    })
}

func parseClosePathAbsolute() -> Parser<PathSegment> {
    return parseCommand(.closePathAbsolute,
                        subparser: empty(),
                        creator: { (_) -> (PathSegment) in
                            return { prior, path, _ in
                                path.closeSubpath()
                                return prior
                            }
    })
}

func parseHorizontal() -> Parser<PathSegment> {
    return parseCommand(.horizontal,
                        subparser: oneOrMore(of: consumeTrivia(before: number())),
                        creator: { (xs: [CGFloat]) -> (PathSegment) in
                            return { prior, path, size in
                                let points = xs.map { x in
                                    CGPoint(x: x * size.width + prior.point.x, y: prior.point.y)
                                }
                                return points.reduce(.zero) { (result, point) -> PriorContext in
                                    path.addLine(to: point)
                                    return point.asPriorContext
                                }
                            }
    })
}

func parseHorizontalAbsolute() -> Parser<PathSegment> {
    return parseCommand(.horizontalAbsolute,
                        subparser: oneOrMore(of: consumeTrivia(before: number())),
                        creator: { (xs: [CGFloat]) -> (PathSegment) in
                            return { prior, path, size in
                                let points = xs.map { x in
                                    CGPoint(x: x * size.width, y: prior.point.y)
                                }
                                return points.reduce(.zero) { (result, point) -> PriorContext in
                                    path.addLine(to: point)
                                    return point.asPriorContext
                                }
                            }
    })
}

func parseVertical() -> Parser<PathSegment> {
    return parseCommand(.vertical,
                        subparser: oneOrMore(of: consumeTrivia(before: number())),
                        creator: { (ys: [CGFloat]) -> (PathSegment) in
                            return { prior, path, size in
                                let points = ys.map { y in
                                    CGPoint(x: prior.point.x, y: y * size.height + prior.point.y)
                                }
                                return points.reduce(.zero) { (result, point) -> PriorContext in
                                    path.addLine(to: point)
                                    return point.asPriorContext
                                }
                            }
    })
}

func parseVerticalAbsolute() -> Parser<PathSegment> {
    return parseCommand(.verticalAbsolute,
                        subparser: oneOrMore(of: consumeTrivia(before: number())),
                        creator: { (ys: [CGFloat]) -> (PathSegment) in
                            return { prior, path, size in
                                let points = ys.map { y in
                                    CGPoint(x: prior.point.x, y: y * size.height)
                                }
                                return points.reduce(.zero) { (result, point) -> PriorContext in
                                    path.addLine(to: point)
                                    return point.asPriorContext
                                }
                            }
    })
}

func parseSmoothCurve() -> Parser<PathSegment> {
    return parseCommand(.smoothCurve,
                        subparser: oneOrMore(of: n(2, of: consumeTrivia(before: coordinatePair()))),
                        creator: { (points: [[CGPoint]]) -> (PathSegment) in
                            return { prior, path, size in
                                let (lastPoint, lastControlPoint) = prior.pointAndControlPoint
                                return points.reduce(.zero, { (result, pair) -> PriorContext in
                                    let points = pair.makeAbsolute(startingWith: lastPoint,
                                                                   in: size,
                                                                   elementSize: 1)
                                    let end = points[1]
                                    let controlPoint = points[0]
                                    path.addCurve(to: end,
                                                  control1: lastControlPoint,
                                                  control2: controlPoint)
                                    return .lastAndControlPoint(end, controlPoint.reflected(across: end, lastPoint))
                                })
                            }
    })
}

enum DrawingCommand: String {
    
    case closePath = "z"
    case closePathAbsolute = "Z"
    case move = "m"
    case moveAbsolute = "M"
    case line = "l"
    case lineAbsolute = "L"
    case vertical = "v"
    case verticalAbsolute = "V"
    case horizontal = "h"
    case horizontalAbsolute = "H"
    case curve = "c"
    case curveAbsolute = "C"
    case smoothCurve = "s"
    case smoothCurveAbsolute = "S"
    case quadratic = "q"
    case quadraticAbsolute = "Q"
    case reflectedQuadratic = "t"
    case reflectedQuadraticAbsolute = "T"
    case arc = "a"
    case arcAbsolute = "A"
    
    var parser: Parser<PathSegment>? { // TODO: should not be optional
        switch self {
        case .curve: return parseCurve()
        case .curveAbsolute: return parseAbsoluteCurve()
        case .moveAbsolute: return parseMoveAbsolute()
        case .move: return parseMove()
        case .line: return parseLine()
        case .lineAbsolute: return parseLineAbsolute()
        case .closePath: return parseClosePath()
        case .closePathAbsolute: return parseClosePathAbsolute()
        case .horizontal: return parseHorizontal()
        case .horizontalAbsolute: return parseHorizontalAbsolute()
        case .vertical: return parseVertical()
        case .verticalAbsolute: return parseVerticalAbsolute()
        case .smoothCurve: return parseSmoothCurve()
        default:
            return nil // TODO
        }
    }
    
    static let all: [DrawingCommand] = [
        .move,
        .moveAbsolute,
        .line,
        .lineAbsolute,
        .vertical,
        .verticalAbsolute,
        .horizontal,
        .horizontalAbsolute,
        .curve,
        .curveAbsolute,
        .smoothCurve,
        .smoothCurveAbsolute,
        .quadratic,
        .quadraticAbsolute,
        .reflectedQuadratic,
        .reflectedQuadraticAbsolute,
        .arc,
        .arcAbsolute,
        .closePath,
        .closePathAbsolute,
        ]
}

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
    
    func times(_ other: CGPoint) -> CGPoint {
        return times(other.x, other.y)
    }
    
    func dot(_ other: CGPoint) -> CGFloat {
        return (x * other.x) + (y * other.y)
    }
    
    func reflected(across first: CGPoint, _ second: CGPoint) -> CGPoint {
        let p = CGPoint(x: x - first.x, y: y - first.y)
        let q = CGPoint(x: second.x - first.x, y: second.y - first.y)
        let quotient = pow(sqrt(pow(q.x - p.x, 2) + pow(q.y - p.y, 2)), 2)
        let projection = (p.dot(q) / quotient) * 2
        return q
            .times(projection, projection)
            .subtract(p)
            .add(first)
    }
}

extension Array where Element == CGPoint {
    
    func scaleTo(size: CGSize) -> [CGPoint] {
        return map { next in
            next.times(size.width, size.height)
        }
    }
    
    func makeAbsolute(startingWith start: CGPoint,
                      in size: CGSize,
                      elementSize: Int = 0) -> [CGPoint] {
        var lastAbsolutePoint = start
        var loopIndex = 0
        return map { next in
            let result = next
                .times(size.width, size.height)
                .add(lastAbsolutePoint)
            if loopIndex == elementSize {
                lastAbsolutePoint = result
                loopIndex = 0
            } else {
                loopIndex += 1
            }
            return result
        }
    }
    
}
