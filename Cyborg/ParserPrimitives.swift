//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

import Foundation

typealias Parser<T> = (XMLString, Int32) -> ParseResult<T>

enum ParseResult<Wrapped> {

    case ok(Wrapped, Int32)
    case error(String)

    init(error: String, index: Int32, stream: XMLString) {
        self = .error("""
        Error at \(index): \(error)
        \(stream[0..<index])⏏️\(stream[index..<stream.count])
        """)
    }

    func map<T>(_ transformer: (Wrapped, Int32) -> (ParseResult<T>)) -> ParseResult<T> {
        switch self {
        case .ok(let value, let index):
            return transformer(value, index)
        case .error(let error): return .error(error)
        }
    }

    func chain<T>(into stream: XMLString, _ transformer: Parser<T>) -> ParseResult<T> {
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
                case .error:
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

func literal(_ text: XMLString, discardErrorMessage: Bool = false) -> Parser<XMLString> {
    return { (stream: XMLString, index: Int32) in
        if stream.matches(text, at: index) {
            return .ok(text, index + text.count)
        } else {
            if discardErrorMessage {
                return .error("")
            } else {
                return ParseResult(error: "Literal " + String(withoutCopying: text), index: index, stream: stream)
            }
        }
    }
}

func consumeAll<T>(using parsers: [Parser<T>]) -> Parser<[T]> {
    return { (stream: XMLString, index: Int32) in
        var index = index,
            results: [T] = [],
            errors: [String] = []
        errors.reserveCapacity(parsers.count)
        results.reserveCapacity(Int(stream.count) / 3)
        untilNoMatchFound:
            while true {
            var next = index
            while next != stream.count,
                (stream[next] == .whitespace || stream[next] == .newline) {
                next += 1
            }
            checkAllParsers:
                for parser in parsers {
                switch parser(stream, next) {
                case .ok(let result, let currentIndex):
                    results.append(result)
                    index = currentIndex
                    errors.removeAll()
                    continue untilNoMatchFound
                case .error(let error):
                    errors.append(error)
                }
            }
            if index == stream.count {
                return .ok(results, index)
            } else {
                return ParseResult(error: "Couldn't find a match for any parsers, errors were: \n\(errors.joined(separator: "\n"))",
                                   index: index,
                                   stream: stream)
            }
        }
    }
}

func empty() -> Parser<()> {
    return { _, index in
        .ok((), index)
    }
}

func not<T>(_ parser: @escaping Parser<T>, discardError: Bool = false) -> Parser<()> {
    return { stream, index in
        switch parser(stream, index) {
        case .ok(let result, let index):
            if discardError {
                return .error("")
            } else {
                return ParseResult(error: "Expected Failure, but succeeded with result \(result)",
                                   index: index,
                                   stream: stream)
            }
        case .error:
            return .ok((), index)
        }
    }
}
