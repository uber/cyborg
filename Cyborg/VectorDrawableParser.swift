//
//  VectorDrawableParser.swift
//  Cyborg
//
//  Created by Ben Pious on 7/26/18.
//  Copyright © 2018 Ben Pious. All rights reserved.
//

import Foundation

public enum Result {
    case ok(VectorDrawable)
    case error(ParseError)
}

public typealias ParseError = String

final class DrawableParser: NSObject, XMLParserDelegate {
    
    let xml: XMLParser
    let onCompletion: (Result) -> ()
    
    var baseWidth: CGFloat?
    var baseHeight: CGFloat?
    var viewPortWidth: CGFloat?
    var viewPortHeight: CGFloat?
    var baseAlpha: CGFloat?
    var commands: [PathSegment]?
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
    }
    
    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {
        if let parent = ParentNode(rawValue: elementName) {
            switch parent {
            case .vectorShape:
                if let error = parseVectorShape(from: attributeDict) {
                    parseError = error
                }
            case .shapePath:
                if let error = parseShape(from: attributeDict) {
                    parseError = error
                }
            }
        }
    }
    
    private func parseVectorShape(from attributes: [String: String]) -> ParseError? {
        var attributes = attributes
        let schema = "xmlns:android"
        let baseError = "Error parsing the <vector> tag: "
        if attributes.keys.contains(schema) {
            attributes.removeValue(forKey: schema)
        } else {
            return baseError + "Schema not found."
        }
        for (key, value) in attributes {
            if let attribute = VectorProperty(rawValue: key),
                let intValue = parseAndroidMeasurement(from: value) {
                // TODO: convert to Android Coords
                self[keyPath: attribute.parserAttribute] = CGFloat(intValue)
            } else {
                return baseError + "Could not find attribute \(key)"
            }
        }
        return nil
    }
    
    private func parseShape(from attributes: [String: String]) -> ParseError? {
        // TODO: pick up fillcolor, name, etc
        let baseError = "Error parsing the <android:pathData> tag: "
        let parsers = DrawingCommand
            .all
            .map { (command) -> Parser<PathSegment> in
                command.parser
        }
        let pathData = attributes["android:pathData"]! // TODO
        switch consumeAll(using: parsers)(pathData, pathData.startIndex) {
        case .ok(let result, _):
            self.commands = result
            return nil
        case .error(let error): return baseError + error
        }
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        if let baseWidth = baseWidth,
            let baseHeight = baseHeight,
            let viewPortWidth = viewPortWidth,
            let viewPortHeight = viewPortHeight,
            let baseAlpha = baseAlpha,
            let commands = commands {
            let result = VectorDrawable(baseWidth: baseWidth,
                                        baseHeight: baseHeight,
                                        viewPortWidth: viewPortWidth,
                                        viewPortHeight: viewPortHeight,
                                        baseAlpha: baseAlpha,
                                        commands: commands)
            onCompletion(.ok(result))
        } else {
            onCompletion(.error(parseError ?? "The parse failed, but there is no parse error. This is a bug in the VectorDrawable Library."))
        }
    }
}

func assignment<T, U>(of property: U,
                      to valueCreator: @escaping (String) -> (T?))
    -> Parser<(U, T)>
    where U: RawRepresentable, U.RawValue == String {
        return { (stream: String, index: String.Index) in
            if let (_, index) = literal(property.rawValue)(stream, index).asOptional {
                if let (_, index) = literal("=")(stream, index).asOptional {
                    if let (rhs, index) = delimited(by: "\"")(stream, index).asOptional {
                        if let value = valueCreator(rhs) {
                            return .ok((property, value), index)
                        } else {
                            return ParseResult(error: "Could not transform \"\(rhs)\" to \(T.self)",
                                index: index,
                                stream: stream)
                        }
                    } else {
                        return ParseResult(error: "RHS was not delimited by quotes",
                                           index: index,
                                           stream: stream)
                    }
                } else {
                    return ParseResult(error: "Did not find an = sign",
                                       index: index,
                                       stream: stream)
                }
            } else {
                return ParseResult(error: "Could not find lhs: \(property.rawValue)",
                    index: index,
                    stream: stream)
            }
        }
}

func height() -> Parser<(VectorProperty, Int)> {
    return assignment(of: VectorProperty.height, to: createInt(from: ))
}

func width() -> (String, String.Index) -> ParseResult<(VectorProperty, Int)> {
    return assignment(of: VectorProperty.width, to: createInt(from: ))
}

func viewPortHeight() -> (String, String.Index) -> ParseResult<(VectorProperty, Int)> {
    return assignment(of: VectorProperty.viewPortWidth, to: parseAndroidMeasurement(from: ))
}

func viewPortWidth() -> (String, String.Index) -> ParseResult<(VectorProperty, Int)> {
    return assignment(of: VectorProperty.viewPortWidth, to: parseAndroidMeasurement(from: ))
}

func parseAndroidMeasurement(from text: String) -> Int? {
    for unit in AndroidUnitOfMeasure.all {
        if let (text, _) = take(until: literal(unit.rawValue))(text, text.startIndex).asOptional {
            return Int(text)
        }
    }
    return nil
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
        let whitespace: Set<Character> = [" ", "\n"]
        if whitespace.contains(stream[index]) {
            return .ok(stream, stream.index(after: index))
        } else {
            return ParseResult(error: "Character \"\(stream[index])\" is not whitespace.",
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
