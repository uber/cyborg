//
//  DrawingCommand.swift
//  Cyborg
//
//  Created by Ben Pious on 7/26/18.
//  Copyright © 2018 Ben Pious. All rights reserved.
//

import Foundation

typealias PathSegment = (CGPoint, CGMutablePath) -> (CGPoint)

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
                            return { point, path in
                                points.reduce(.zero) { (result, points) -> CGPoint in
                                    let points = points.map(point.add)
                                    let control1 = points[0],
                                    control2 = points[1],
                                    end = points[2]
                                    path.addCurve(to: end, control1: control1, control2: control2)
                                    return end
                                }
                            }
    })
}

func parseAbsoluteCurve() -> Parser<PathSegment> {
    return parseCommand(.curve,
                        subparser: oneOrMore(of: n(3,
                                                   of: consumeTrivia(before: coordinatePair()))),
                        creator: { (points: [[CGPoint]]) -> (PathSegment) in
                            return { point, path in
                                points.reduce(.zero) { (result, points) -> CGPoint in
                                    let control1 = points[0],
                                    control2 = points[1],
                                    end = points[2]
                                    path.addCurve(to: end, control1: control1, control2: control2)
                                    return end
                                }
                            }
    })
}

func parseMoveAbsolute() -> Parser<PathSegment> {
    return parseCommand(.moveAbsolute,
                        subparser: consumeTrivia(before: coordinatePair()),
                        creator: { (point) -> (PathSegment) in
                            return { _, path in
                                path.move(to: point)
                                return point
                            }
    })
}

func parseLine() -> Parser<PathSegment> {
    return parseCommand(.line,
                        subparser: oneOrMore(of: consumeTrivia(before: coordinatePair())),
                        creator: { (points: [CGPoint]) -> (PathSegment) in
                            return { (point: CGPoint, path: CGMutablePath) -> CGPoint in
                                let points = points.map(point.add)
                                return points.reduce(.zero) { result, point -> CGPoint in
                                    path.move(to: point)
                                    return point
                                }
                            }
    })
}

func parseClosePath() -> Parser<PathSegment> {
    return parseCommand(.closePath,
                        subparser: empty(),
                        creator: { (_) -> (PathSegment) in
                            return { point, path in
                                path.closeSubpath()
                                return point
                            }
    })
}

func parseClosePathAbsolute() -> Parser<PathSegment> {
    return parseCommand(.closePathAbsolute,
                        subparser: empty(),
                        creator: { (_) -> (PathSegment) in
                            return { point, path in
                                path.closeSubpath()
                                return point
                            }
    })
}


enum DrawingCommand: String {
    
    case closePath = "z"
    case closePathAbsolute = "Z"
    case move = "m"
    case moveAbsolute = "M"
    case line = "l"
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
    
    var consumed: Int {
        switch self {
        case .closePathAbsolute, .closePath: return 0
        case .move, .line, .moveAbsolute: return 2
        case .horizontal, .horizontalAbsolute, .vertical, .verticalAbsolute: return 1
        case .curve, .curveAbsolute: return 6
        case .reflectedQuadratic, .reflectedQuadraticAbsolute, .quadratic, .quadraticAbsolute: return 4
        case .arc, .arcAbsolute: return 7
        case .smoothCurve, .smoothCurveAbsolute: return 2
        }
    }
    
//    func createSegment(using rawInput: [Int]) -> PathSegment {
//        let floats = rawInput.map(CGFloat.init(integerLiteral:))
//        func relative(to point: CGPoint) -> (CGFloat, CGFloat) -> CGPoint {
//            return { x, y in
//                return CGPoint(x: x + point.x, y: y + point.y)
//            }
//        }
//        switch self {
//        case .closePathAbsolute, .closePath: return { point, path in
//            path.closeSubpath()
//            return point
//            }
//        case .move: return { point, path in
//            let moveTo = CGPoint(x: floats[0] + point.x, y: floats[1] + point.y)
//            path.move(to: point)
//            return moveTo
//            }
//        case .moveAbsolute: return { point, path in
//            let moveTo = CGPoint(x: floats[0], y: floats[1])
//            path.move(to: point)
//            return moveTo
//            }
//        case .horizontal: return { point, path in
//            let moveTo = CGPoint(x: floats[0] + point.x, y: point.y)
//            path.move(to: point)
//            return moveTo
//            }
//        case .horizontalAbsolute: return { point, path in
//            let moveTo = CGPoint(x: floats[0], y: point.y)
//            path.move(to: point)
//            return moveTo
//            }
//        case .vertical: return { point, path in
//            let moveTo = CGPoint(x: point.x, y: floats[0] + point.y)
//            path.move(to: point)
//            return moveTo
//            }
//        case .verticalAbsolute: return { point, path in
//            let moveTo = CGPoint(x: point.x, y: floats[0])
//            path.move(to: point)
//            return moveTo
//            }
//        case .curve: return { point, path in
//            let point = relative(to: point)
//            let first = point(floats[0], floats[1]),
//            second = point(floats[2], floats[3]),
//            end = point(floats[4], floats[5])
//            path.addCurve(to: end, control1: first, control2: second)
//            return end
//            }
//        case .curveAbsolute: return { point, path in
//            let first = CGPoint(x: floats[0], y: floats[1]),
//            second = CGPoint(x: floats[2], y: floats[3]),
//            end = CGPoint(x: floats[4], y: floats[5])
//            path.addCurve(to: end, control1: first, control2: second)
//            return end
//            }
//        case .reflectedQuadratic: return { point, path in
//            let pointMaker = relative(to: point)
//            let destination = pointMaker(floats[0], floats[1])
//            path.addQuadCurve(to: destination, control: point)
//            return destination
//            }
//        case .reflectedQuadraticAbsolute: return { point, path in
//            let destination = CGPoint(x: floats[0], y: floats[1])
//            path.addQuadCurve(to: destination, control: point)
//            return destination
//            }
//        case .quadratic: return { point, path in
//            let point = relative(to: point)
//            let first = point(floats[0], floats[1]),
//            second = point(floats[2], floats[3])
//            path.addQuadCurve(to: second, control: first)
//            return second
//            }
//        case .quadraticAbsolute: return { point, path in
//            let first = CGPoint(x: floats[0], y: floats[1]),
//            second = CGPoint(x: floats[2], y: floats[3])
//            path.addQuadCurve(to: second, control: first)
//            return second
//            }
//        case .arc: return { point, path in
//            fatalError()
//            }
//        case .arcAbsolute: return { point, path in
//            fatalError() // TODO
//            }
//        case .line: return { point, path in
//            let next = CGPoint(x: floats[0], y: floats[1])
//            path.move(to: next)
//            return next
//            }
//        case .smoothCurve: return { point, path in
//            fatalError()
//            }
//        case .smoothCurveAbsolute: return { point, path in
//            fatalError()
//            }
//        }
//    }
    
    var parser: Parser<PathSegment>? { // TODO: should not be optional
        switch self {
        case .curve: return parseCurve()
        case .curveAbsolute: return parseAbsoluteCurve()
        case .moveAbsolute: return parseMoveAbsolute()
        case .line: return parseLine()
        case .closePath: return parseClosePath()
        case .closePathAbsolute: return parseClosePathAbsolute()
        default:
            return nil // TODO
        }
    }
    
    static let all: [DrawingCommand] = [
        .move,
        .moveAbsolute,
        .line,
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
}
