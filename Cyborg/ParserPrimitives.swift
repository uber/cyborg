//
//  ParserPrimitives.swift
//  Cyborg
//
//  Created by Ben Pious on 7/25/18.
//  Copyright © 2018 Ben Pious. All rights reserved.
//

import Foundation

typealias Parser<T> = (String, String.Index) -> ParseResult<T>

enum ParseResult<Wrapped> {
    
    case ok(Wrapped, String.Index)
    case error(String)
    
    init(error: String, index: String.Index, stream: String) {
        self = .error("""
            Error at \(index.encodedOffset): \(error)
            \(stream[stream.startIndex..<index])⏏️\(stream[index..<stream.endIndex])
            """)
    }
    
    var asOptional: (Wrapped, String.Index)? {
        switch self {
        case .ok(let wrapped): return wrapped
        case .error(_): return nil
        }
    }
    
    var asParseError: ParseError? {
        switch self {
        case .error(let error): return error
        case .ok(_, _): return nil
        }
    }
    
    func map<T>(_ transformer: (Wrapped, String.Index) -> (ParseResult<T>)) -> ParseResult<T> {
        switch self {
        case .ok(let value, let index):
            return transformer(value, index)
        case .error(let error): return .error(error)
        }
    }
    
    func chain<T>(into stream: String, _ transformer: Parser<T>) -> ParseResult<T> {
        switch self {
        case .ok(_, let index):
            return transformer(stream, index)
        case .error(let error): return .error(error)
        }
    }
}

func oneOrMore<T>(of parser: @escaping Parser<T>) -> Parser<[T]> {
    return { stream, index in
        switch parser(stream, index) {
        case .ok(let result, let index):
            var nextIndex = index
            var results = [result]
            findMoreMatches: while true {
                switch parser(stream, nextIndex) {
                case .ok(let result, let index):
                    nextIndex = index
                    results.append(result)
                case .error(_):
                    break findMoreMatches
                }
            }
            return .ok(results, nextIndex)
        case .error(let error):
            return ParseResult(error: "Could not find one match: subparser error was: \(error)",
                index: index,
                stream: stream)
        }
    }
}

func optional<T>(_ parser: @escaping Parser<T>) -> Parser<T?> {
    return { stream, index in
        switch parser(stream, index) {
        case .ok(let result, let index):
            return .ok(result, index)
        case .error(_):
            return .ok(nil, index)
        }
    }
}

func literal(_ text: String) -> Parser<String> {
    return { (stream: String, index: String.Index) in
        if let endOfRange = stream.index(index, offsetBy: text.count, limitedBy: stream.endIndex) {
            let potentialMatch = stream[index..<endOfRange]
            if potentialMatch == text {
                return .ok(String(potentialMatch), endOfRange)
            } else {
                return ParseResult(error: "Literal \(text)", index: index, stream: stream)
            }
        } else {
            return ParseResult(error: "Literal was too long for remaining stream", index: index, stream: stream)
        }
    }
}

func delimited(by delimiter: String) -> Parser<String> {
    let delimiterParser = literal(delimiter)
    return { (stream: String, index: String.Index) in
        if let (_, index) = delimiterParser(stream, index).asOptional {
            return take(until: delimiterParser)(stream, index)
        } else {
            return ParseResult(error: "Could not find second delimiter",
                               index: index,
                               stream: stream)
        }
    }
}

func take<T>(until match: @escaping Parser<T>) -> Parser<String> {
    return { (stream: String, index: String.Index) in
        let startIndex = index
        var index = index
        while true {
            if let (_, index) = match(stream, index).asOptional {
                return .ok(String(stream[startIndex..<index]), index)
            } else {
                if let endIndex = stream
                    .index(stream.endIndex,
                offsetBy: -1,
                limitedBy: stream.startIndex),
                    let nextIndex = stream
                        .index(index,
                               offsetBy: 1,
                               limitedBy: endIndex) {
                    index = nextIndex
                } else {
                    return ParseResult(error: "Stream ended before match",
                                       index: index,
                                       stream: stream)
                }
            }
        }
    }
}

func consumeAll<T>(using parsers: [Parser<T>]) -> Parser<[T]> {
    return { (stream: String, index: String.Index) in
        var
        index = index,
        results: [T] = [],
        errors: [String] = []
        errors.reserveCapacity(parsers.count)
        untilNoMatchFound: while true {
            checkAllParsers: for parser in parsers {
                switch parser(stream, index) {
                case .ok(let result, let currentIndex):
                    results.append(result)
                    index = currentIndex
                    errors.removeAll()
                    continue untilNoMatchFound
                case .error(let error):
                    errors.append(error)
                }
            }
            if index == stream.endIndex {
                return .ok(results, index)
            } else {
                return ParseResult(error: "Couldn't find a match for any parsers, errors were: \n\(errors.joined(separator: "\n"))",
                    index: index,
                    stream: stream)
            }
        }
    }
}

func anyOrder<T>(of parsers: [Parser<T>]) -> Parser<[T]> {
    return { (stream: String, index: String.Index) in
        var
        parsers = parsers,
        index = index,
        results: [T] = []
        untilNoMatchFound: while true {
            for (parserIndex, parser) in parsers.enumerated() {
                if let (match, currentIndex) = parser(stream, index).asOptional {
                    _ = parsers.remove(at: parserIndex)
                    results.append(match)
                    index = currentIndex
                    break
                }
            }
            if index == stream.endIndex {
                return .ok(results, index)
            } else {
                return ParseResult(error: "Couldn't find a match for all parsers",
                                   index: index,
                                   stream: stream)
            }
        }
    }
}

func anyOrder<T>(of parsers: Parser<T>...) -> Parser<[T]> {
    return anyOrder(of: parsers)
}

func pair<T, U>(of first: @escaping Parser<T>, _ second: @escaping Parser<U>) -> Parser<(T, U)> {
    return { (stream: String, index: String.Index) in
        first(stream, index).map { firstResult, index in
            second(stream, index).map { (secondResult, index) in
                return .ok((firstResult, secondResult), index)
            }
        }
    }
}

func n<T>(_ n: Int, of parser: @escaping Parser<T>) -> Parser<[T]> {
    return { (stream: String, index: String.Index) in
        var taken = 0,
        index = index,
        result = [T]()
        while taken != n {
            if let (currentResult, nextIndex) = parser(stream, index).asOptional {
                result.append(currentResult)
                index = nextIndex
                taken += 1
            } else {
                return ParseResult(error: "Could not take until \(n), only found \(taken)",
                    index: index,
                    stream: stream)
            }
        }
        return .ok(result, index)
    }
}

func empty() -> Parser<()> {
    return { _, index in
        .ok((), index)
    }
}

func not<T>(_ parser: @escaping Parser<T>) -> Parser<()> {
    return { stream, index in
        switch parser(stream, index) {
        case .ok(let result, let index): return ParseResult(error: "Expected Failure, but succeeded with result \(result)",
            index: index,
            stream: stream)
        case .error(_): return .ok((), index)
        }
    }
}

func or<T>(_ first: @escaping Parser<T>, _ second: @escaping Parser<T>) -> Parser<T> {
    return { stream, index in
        let result = first(stream, index)
        if let error = result.asParseError {
            let result = second(stream, index)
            if let secondError = result.asParseError {
                return ParseResult(error: "Or: Couldn't match either parser, errors were: \(error), \(secondError)",
                                   index: index,
                                   stream: stream)
            } else {
                return result
            }
        } else {
            return result
        }
    }
}

