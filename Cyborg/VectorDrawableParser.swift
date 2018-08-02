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

func assign<T>(_ string: String,
               to path: inout T,
               creatingWith creator: (String) -> (T?)) -> ParseError? {
    if let float = creator(string) {
        path = float
        return nil
    } else {
        return "Could not assign \(string)"
    }
}

func assignFloat(_ string: String,
                 to path: inout CGFloat?) -> ParseError? {
    return assign(string, to: &path, creatingWith: { (string) in
        Double(string).flatMap(CGFloat.init(value:))
    })
}

func assignFloat(_ string: String,
                 to path: inout CGFloat) -> ParseError? {
    return assign(string, to: &path, creatingWith: { (string) in
        Double(string).flatMap(CGFloat.init(value:))
    })
}

protocol NodeParsing: AnyObject {
    
    static var name: Element { get }
    
    func parse(element: String, attributes: [String: String]) -> ParseError?
    
    func ended(element: String)
    
    init()
    
}

extension NodeParsing {
    
    func ended(element: String) {
        
    }
    
}

class ParentParser<Child>: NodeParsing where Child: NodeParsing {
    
    required init() {
        
    }
    
    var currentChild: Child?
    var children: [Child] = []
    
    class var name: Element {
        return .vector
    }
    
    var name: Element {
        return ParentParser.name
    }
    
    func parse(element: String, attributes: [String : String]) -> ParseError? {
        if let currentChild = currentChild {
            return currentChild.parse(element: element, attributes: attributes)
        } else if element == name.rawValue {
            return parseAttributes(attributes)
        } else if element == Child.name.rawValue {
            let currentChild = Child()
            self.currentChild = currentChild
            children.append(currentChild)
            return currentChild.parse(element: element, attributes: attributes)
        } else {
            return "Element \"\(element)\" found, expected \(name.rawValue)."
        }
    }
    
    func parseAttributes(_ attributes: [String: String]) -> ParseError? {
        return nil
    }
    
    func ended(element: String) {
        currentChild?.ended(element: element)
    }
    
}

class VectorParser: ParentParser<GroupParser> {
    
    var baseWidth: CGFloat?
    var baseHeight: CGFloat?
    var viewPortWidth: CGFloat?
    var viewPortHeight: CGFloat?
    var tintMode: BlendMode?
    var tintColor: Color?
    var autoMirrored: Bool = false
    var alpha: CGFloat = 1
    
    override func parseAttributes(_ attributes: [String: String]) -> ParseError? {
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
                let result: ParseError?
                switch property {
                case .height: result = assign(value, to: &baseHeight, creatingWith: parseAndroidMeasurement(from: ))
                case .width: result = assign(value, to: &baseWidth,  creatingWith: parseAndroidMeasurement(from: ))
                case .viewPortHeight: result = assignFloat(value, to: &viewPortHeight)
                case .viewPortWidth: result = assignFloat(value, to: &viewPortWidth)
                case .tint: result = assign(value, to: &tintColor, creatingWith: Color.init)
                case .tintMode: result = assign(value, to: &tintMode, creatingWith: BlendMode.init)
                case .autoMirrored: result = assign(value, to: &autoMirrored, creatingWith: Bool.init)
                case .alpha: result = assignFloat(value, to: &alpha)
                }
                if result != nil {
                    return result
                }
            } else {
                return "Key \(key) is not a valid attribute of <vector>"
            }
        }
        return nil
    }
    
    
    func createElement() -> Result {
        if let baseWidth = baseWidth,
            let baseHeight = baseHeight,
            let viewPortWidth = viewPortWidth,
            let viewPortHeight = viewPortHeight {
            let groups = children.map { group in
                group.createPath()! // TODO
            }
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
    
    func parseAndroidMeasurement(from text: String) -> CGFloat? {
        for unit in AndroidUnitOfMeasure.all {
            switch take(until: literal(unit.rawValue))(text, text.startIndex) {
            case .ok(let text, _):
                if let int = Int(text[text.startIndex..<text.index(text.endIndex, offsetBy: -unit.rawValue.count)]) {
                    return CGFloat(int)
                } else {
                    return nil
                }
            case .error(_):
                return nil
            }
        }
        return nil
    }
    
}

class PathParser: NodeParsing {
    
    static let name: Element = .path
    
    required init() {
        
    }
    
    var pathName: String?
    var commands: [PathSegment]?
    var fillColor: Color = .clear
    var strokeColor: Color = .clear
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
    
    func parse(element: String, attributes: [String : String]) -> ParseError? {
        let baseError = "Error parsing the <android:pathData> tag: "
        let parsers = DrawingCommand
            .all
            .compactMap { (command) -> Parser<PathSegment>? in
                command.parser
        }
        for (key, value) in attributes {
            if let property = PathProperty(rawValue: key) {
                let result: ParseError?
                switch property {
                case .name:
                    pathName = value
                    result = nil
                case .pathData:
                    let subResult: ParseError?
                    switch consumeAll(using: parsers)(value, value.startIndex) {
                    case .ok(let result, _):
                        self.commands = result
                        subResult = nil
                    case .error(let error):
                        subResult = baseError + error
                    }
                    result = subResult
                case .fillColor:
                    fillColor = Color(value)! // TODO
                    result = nil // TODO
                case .strokeWidth:
                    result = assignFloat(value, to: &strokeWidth)
                case .strokeColor:
                    result = assign(value, to: &strokeColor, creatingWith: Color.init)
                case .strokeAlpha:
                    result = assignFloat(value, to: &strokeAlpha)
                case .fillAlpha:
                    result = assignFloat(value, to: &fillAlpha)
                case .trimPathStart:
                    result = assignFloat(value, to: &trimPathStart)
                case .trimPathEnd:
                    result = assignFloat(value, to: &trimPathEnd)
                case .trimPathOffset:
                    result = assignFloat(value, to: &trimPathOffset)
                case .strokeLineCap:
                    result = assign(value, to: &strokeLineCap, creatingWith: LineCap.init)
                case .strokeLineJoin:
                    result = assign(value, to: &strokeLineJoin, creatingWith: LineJoin.init)
                case .strokeMiterLimit:
                    result = assignFloat(value, to: &strokeMiterLimit)
                case .fillType:
                    result = assign(value, to: &fillType, creatingWith: { (string) -> (CGPathFillRule?) in
                        switch string {
                        case "evenOdd": return .evenOdd
                        case "nonZero": return .winding
                        default: return nil
                        }
                    })
                }
                if result != nil {
                    return result
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
            let commands = commands {
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

class GroupParser: ParentParser<PathParser> {
    
    override class var name: Element {
        return  .group
    }
    
    override var name: Element {
        return GroupParser.name
    }
    
    var groupName: String?
    var pivotX: CGFloat = 0
    var pivotY: CGFloat = 0
    var rotation: CGFloat = 0
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
    var translationX: CGFloat = 0
    var translationY: CGFloat = 0
    
    required init() {
        
    }
    
    override func parseAttributes(_ attributes: [String : String]) -> ParseError? {
        for (key, value) in attributes {
            if let property = GroupProperty(rawValue: key) {
                let result: ParseError?
                switch property {
                case .name:
                    groupName = value
                    result = nil
                case .rotation:
                    result = assignFloat(value, to: &rotation)
                case .pivotX:
                    result = assignFloat(value, to: &pivotX)
                case .pivotY:
                    result = assignFloat(value, to: &pivotY)
                case .scaleX:
                    result = assignFloat(value, to: &scaleX)
                case .scaleY:
                    result = assignFloat(value, to: &scaleY)
                case .translateX:
                    result = assignFloat(value, to: &translationX)
                case .translateY:
                    result = assignFloat(value, to: &translationY)
                }
                if result != nil {
                    return result
                }
            } else {
                return "Unrecognized Attribute: \(key)"
            }
        }
        return nil
    }
    
    func createPath() -> VectorDrawable.Group? {
        if let groupName = groupName {
            let paths = children.map { (parser) in
                parser.createElement()! // TODO
            }
            return VectorDrawable.Group(name: groupName,
                                        transform: Transform(pivot: .init(x: pivotX, y: pivotY),
                                                             rotation: rotation,
                                                             scale: .init(x: scaleX, y: scaleY),
                                                             translation: .init(x: translationX, y: translationY)),
                                        paths: paths)
        } else {
            return nil
        }
    }
    
}

final class DrawableParser: NSObject, XMLParserDelegate {
    
    let xml: XMLParser
    let onCompletion: (Result) -> ()
    let vector: VectorParser = VectorParser()
    var parseError: ParseError?
    
    
    init(data: Data, onCompletion: @escaping (Result) -> ()) {
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
        if let errorMessage = vector.parse(element: elementName, attributes: attributeDict) {
            parseError = errorMessage
            stop()
        }
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        onCompletion(vector.createElement())
    }
}

// MARK: - Parser Combinators

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
