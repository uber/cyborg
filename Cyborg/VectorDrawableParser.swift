//
//  VectorDrawableParser.swift
//  Cyborg
//
//  Created by Ben Pious on 7/26/18.
//  Copyright © 2018 Ben Pious. All rights reserved.
//

import Foundation

/// Contains either a `VectorDrawable`, or an `error` if the `VectorDrawable` could not be deserialized.
public enum Result {
    case ok(VectorDrawable)
    case error(ParseError)
}

public typealias ParseError = String

// MARK: - Element Parsers

class NodeParser {
    
    let name: ParentNode
    
    init(name: ParentNode) {
        self.name = name
    }
    
    func parse(element: String, attributes: [String: String]) -> ParseError? {
        return nil
    }
    
    func ended(element: String) -> Bool {
        return false
    }
    
    final func assign<T>(_ string: String,
                     to path: inout T,
                     creatingWith creator: (String) -> (T?)) -> ParseError? {
        if let float = creator(string) {
            path = float
            return nil
        } else {
            return "Could not assign \(string)"
        }
    }
    
    final func assignFloat(_ string: String,
                     to path: inout CGFloat?) -> ParseError? {
        return assign(string, to: &path, creatingWith: { (string) in
            Double(string).flatMap(CGFloat.init(value:))
        })
    }
    
    final func assignFloat(_ string: String,
                     to path: inout CGFloat) -> ParseError? {
        return assign(string, to: &path, creatingWith: { (string) in
            Double(string).flatMap(CGFloat.init(value:))
        })
    }

    
}

class VectorParser: NodeParser {
    
    var baseWidth: CGFloat?
    var baseHeight: CGFloat?
    var viewPortWidth: CGFloat?
    var viewPortHeight: CGFloat?
    var tintMode: BlendMode?
    var tintColor: Color?
    var autoMirrored: Bool = false
    var alpha: CGFloat = 1
    
    init() {
        super.init(name: .vector)
    }

    override func parse(element: String, attributes: [String : String]) -> ParseError? {
        if element == name.rawValue {
            var attributes = attributes
            let schema = "xmlns:android"
            let baseError = "Error parsing the <vector> tag: "
            if attributes.keys.contains(schema) {
                attributes.removeValue(forKey: schema)
            } else {
                return baseError + "Schema not found."
            }
            for (key, value) in attributes {
                if let property = VectorProperty(rawValue: key) {
                    switch property {
                    case .height: return assignFloat(value, to: &baseHeight)
                    case .width: return assignFloat(value, to: &baseWidth)
                    case .viewPortHeight: return assignFloat(value, to: &viewPortHeight)
                    case .viewPortWidth: return assignFloat(value, to: &viewPortWidth)
                    case .tint: return assign(value, to: &tintColor, creatingWith: Color.init)
                    case .tintMode: return assign(value, to: &tintMode, creatingWith: BlendMode.init)
                    case .autoMirrored: return assign(value, to: &autoMirrored, creatingWith: Bool.init)
                    case .alpha: return assignFloat(value, to: &alpha)
                    }
                } else {
                    return "Key \(key) is not a valid attribute of <vector>"
                }
            }
            return nil
        } else {
            return "Unexpected element found at the top level"
        }
    }
    
    func createElement(with groups: [VectorDrawable.Group]) -> Result {
        if let baseWidth = baseWidth,
            let baseHeight = baseHeight,
            let viewPortWidth = viewPortWidth,
            let viewPortHeight = viewPortHeight {
        return .ok(.init(baseWidth: baseWidth,
                         baseHeight: baseHeight,
                         viewPortWidth: viewPortWidth,
                         viewPortHeight: viewPortHeight,
                         baseAlpha: alpha,
                         groups: groups))
        } else {
            return .error("Could not parse a <vector> element, but there was no error. This is a bug in the VectorDrawable Library.")
        }
    }
    
}

class PathParser: NodeParser {
    
    var pathName: String?
    var commands: [PathSegment]?
    var fillColor: Color?
    var strokeColor: Color?
    var strokeWidth: CGFloat = 0
    var strokeAlpha: CGFloat = 1
    var fillAlpha: CGFloat = 1
    var trimPathStart: CGFloat = 0
    var trimPathEnd: CGFloat = 1
    var trimPathOffset: CGFloat = 0
    var strokeLineCap: LineCap = .butt
    var strokeMiterLimit: CGFloat = 4
    var strokeLineJoin: LineJoin = .miter
    var fillType: CGPathFillRule = .winding
    
    override func parse(element: String, attributes: [String : String]) -> ParseError? {
        let baseError = "Error parsing the <android:pathData> tag: "
        let parsers = DrawingCommand
            .all
            .compactMap { (command) -> Parser<PathSegment>? in
                command.parser
        }
        for (key, value) in attributes {
            if let property = PathProperty(rawValue: key) {
                switch property {
                case .name:
                    pathName = value
                    return nil
                case .pathData:
                    switch consumeAll(using: parsers)(value, value.startIndex) {
                    case .ok(let result, _):
                        self.commands = result
                        return nil
                    case .error(let error):
                        return baseError + error
                    }
                case .fillColor:
                    fillColor = Color(value)
                case .strokeWidth:
                    return assignFloat(value, to: &strokeWidth)
                case .strokeColor:
                    return assign(value, to: &strokeColor, creatingWith: Color.init)
                case .strokeAlpha:
                    return assignFloat(value, to: &strokeAlpha)
                case .fillAlpha:
                    return assignFloat(value, to: &fillAlpha)
                case .trimPathStart:
                    return assignFloat(value, to: &trimPathStart)
                case .trimPathEnd:
                    return assignFloat(value, to: &trimPathEnd)
                case .trimPathOffset:
                    return assignFloat(value, to: &trimPathOffset)
                case .strokeLineCap:
                    return assign(value, to: &strokeLineCap, creatingWith: LineCap.init)
                case .strokeLineJoin:
                    return assign(value, to: &strokeLineJoin, creatingWith: LineJoin.init)
                case .strokeMiterLimit:
                    return assignFloat(value, to: &strokeMiterLimit)
                case .fillType:
                    return assign(value, to: &fillType, creatingWith: { (string) -> (CGPathFillRule?) in
                        switch string {
                        case "evenOdd": return .evenOdd
                        case "nonZero": return .winding
                        default: return nil
                        }
                    })
                }
            } else {
                return "Key \(key) is not a valid attribute of <path>."
            }
        }
        let pathData = attributes["android:pathData"]! // TODO
        switch consumeAll(using: parsers)(pathData, pathData.startIndex) {
        case .ok(let result, _):
            self.commands = result
            return nil
        case .error(let error):
            return baseError + error
        }
    }
    
    func createElement() -> VectorDrawable.Path? {
        if let pathName = pathName,
            let commands = commands,
            let fillColor = fillColor,
            let strokeColor = strokeColor {
            return VectorDrawable.Path(name: pathName,
                                       fillColor: fillColor,
                                       fillAlpha: fillAlpha,
                                       data: commands,
                                       strokeColor: strokeColor,
                                       strokeWidth: strokeWidth,
                                       strokeAlpha: strokeAlpha,
                                       trimPathStart: trimPathStart,
                                       trimPathEnd: trimPathEnd,
                                       trimPathOffset: trimPathOffset,
                                       strokeLineCap: strokeLineCap,
                                       strokeLineJoin: strokeLineJoin,
                                       fillType: fillType)
        } else {
            return nil
        }
    }
    
}

class GroupParser: NodeParser {
    
    var groupName: String?
    var pivotX: CGFloat?
    var pivotY: CGFloat?
    var rotation: CGFloat?
    var scaleX: CGFloat?
    var scaleY: CGFloat?
    var translationX: CGFloat?
    var translationY: CGFloat?
    
    init() {
        super.init(name: .group)
    }
    
    override func parse(element: String, attributes: [String : String]) -> ParseError? {
        if element == name.rawValue {
            for (key, value) in attributes {
                if let property = GroupProperty(rawValue: key) {
                    switch property {
                    case .name:
                        groupName = value
                        return nil
                    case .rotation:
                        return assignFloat(value, to: &rotation)
                    case .pivotX:
                        return assignFloat(value, to: &pivotX)
                    case .pivotY:
                        return assignFloat(value, to: &pivotY)
                    case .scaleX:
                        return assignFloat(value, to: &scaleX)
                    case .scaleY:
                        return assignFloat(value, to: &scaleY)
                    case .translateX:
                        return assignFloat(value, to: &translationX)
                    case .translateY:
                        return assignFloat(value, to: &translationY)
                    }
                } else {
                    return "Unrecognized Attribute: \(key)"
                }
            }
        } else {
            return "Unrecognized Element"
        }
        return "No attributes found"
    }
    
}

final class DrawableParser: NSObject, XMLParserDelegate {
    
    let xml: XMLParser
    let onCompletion: (Result) -> ()
    let vector: VectorParser
    var parserStack: [NodeParser]
    var parseError: ParseError?
    
    
    init(data: Data, onCompletion: @escaping (Result) -> ()) {
        vector = VectorParser()
        parserStack = [vector]
        xml = XMLParser(data: data)
        self.onCompletion = onCompletion
        super.init()
        xml.delegate = self
    }
    
    func start() {
        xml.parse()
    }
    
    func stop() {
        xml.abortParsing()
        if let parseError = parseError {
            onCompletion(.error(parseError))
        }
    }
    
    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {
        if let errorMessage = parserStack[0].parse(element: elementName, attributes: attributeDict) {
            parseError = errorMessage
            stop()
        }
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
//        onCompletion()
    }
}

// MARK: - Parser Combinators

func parseAndroidMeasurement(from text: String) -> ParseResult<Int> {
    var lastError = ParseResult<Int>.error("no text found")
    for unit in AndroidUnitOfMeasure.all {
        switch take(until: literal(unit.rawValue))(text, text.startIndex) {
        case .ok(let text, let index):
            if let int = Int(text[text.startIndex..<text.index(text.endIndex, offsetBy: -unit.rawValue.count)]) {
                return .ok(int, index)
            } else {
                return .error("Could not convert \"\(text)\" to Int.")
            }
        case .error(let error):
            lastError = .error(error)
        }
    }
    return lastError
}

func parseInt(from text: String) -> ParseResult<Int> {
    if let int = Int(text) {
        return .ok(int, text.endIndex)
    } else {
        return .error("Couldn't parse int from \"\(text)\"")
    }
}

func consumeTrivia<T>(before: @escaping Parser<T>) -> Parser<T> {
    return { stream, input in
        let parser: Parser<(String, T)> = pair(of: take(until: not(trivia())), before)
        let result: ParseResult<(String, T)> = parser(stream, input)
        switch  result {
        case .ok((_, let result), let index): return .ok(result, index)
        case .error(let error): return .error(error)
        }
    }
}

func trivia() -> Parser<String> {
    return { stream, index in
        if stream.distance(from: index, to: stream.endIndex) > 1 {
            let whitespace: Set<Character> = [" ", "\n"]
            if whitespace.contains(stream[index]) {
                return .ok(stream, stream.index(after: index))
            } else {
                return ParseResult(error: "Character \"\(stream[index])\" is not whitespace.",
                    index: index,
                    stream: stream)
            }
        } else {
            return ParseResult(error: "String empty",
                               index: index,
                               stream: stream)
        }
    }
}

func int() -> Parser<Int> {
    return { (string: String, index: String.Index) in
        var digits = CharacterSet.decimalDigits
        let (result, _) = digits.insert("-")
        assert(result)
        var next = index
        while next != string.endIndex {
            let character = string[next]
            if character.unicodeScalars.count == 1 {
                let scalar = character.unicodeScalars[character.unicodeScalars.startIndex]
                if digits.contains(scalar) {
                    next = string.index(next, offsetBy: 1)
                } else {
                    break
                }
            } else {
                break
            }
        }
        if let integer = Int(string[index..<next]) {
            return .ok(integer, next)
        } else {
            return ParseResult(error: "Could not create Integer",
                               index: next,
                               stream: string)
        }
    }
}

func coordinatePair() -> Parser<CGPoint> {
    return { stream, input in
        return pair(of: pair(of: int(), literal(",")), int())(stream, input)
            .map { (arg, index) -> (ParseResult<CGPoint>) in
                let ((x, _), y) = arg
                return .ok(CGPoint.init(x: x, y: y), index)
        }
    }
}

func createInt(from text: String) -> Int? { // necessary to prevent ambiguity, otherwise I'd use Int.init(_ description:)
    return Int(text)
}

infix operator ?=
func ?=<T>(lhs: inout T?, rhs: T) {
    if lhs == nil {
        lhs = rhs
    }
}

extension CGFloat {
    init(value: Double) {
        self.init(value)
    }
}
