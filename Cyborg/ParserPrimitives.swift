//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

import Foundation

typealias Parser<T> = (XMLString, Int32) -> ParseResult<T>

enum ParseResult<Wrapped> {

    case ok(Wrapped, Int32)
    case error(String, Int32)

    init(error: String, index: Int32, stream: XMLString) {
        self = .error("""
            Error at \(index): \(error)
            \(stream[0..<index])\(stream[index..<min(stream.count, index + 30)])
            \(String(repeating: "~", count: Int(index)) + "^")
            """, index)
    }

    func map<T>(_ transformer: (Wrapped, Int32) -> (ParseResult<T>)) -> ParseResult<T> {
        switch self {
        case .ok(let value, let index):
            return transformer(value, index)
        case .error(let error, let index): return .error(error, index)
        }
    }

    func chain<T>(into stream: XMLString, _ transformer: Parser<T>) -> ParseResult<T> {
        switch self {
        case .ok(_, let index):
            return transformer(stream, index)
        case .error(let error, let index): return .error(error, index)
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
                return .error("", index)
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
        errors: [(String, Int32)] = []
        errors.reserveCapacity(parsers.count)
        results.reserveCapacity(Int(stream.count) / 3)
        var next = index
        untilNoMatchFound:
            while true {
                next = index
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
                        case .error(let error, let index):
                            errors.append((error, index))
                        }
                }
                if index == stream.count {
                    return .ok(results, index)
                } else {
                    func defaultError() -> ParseResult<[T]> {
                        return ParseResult(error: "Couldn't find a match for any parsers, errors were: \n\(errors.map { $0.0 }.joined(separator: "\n"))",
                            index: index,
                            stream: stream)
                    }
                    if errors.count > 2 {
                        let errors = errors.sorted(by: { (lhs, rhs) -> Bool in
                            lhs.1 > rhs.1
                        })
                        let first = errors[0]
                        if first.1 > errors[1].1 {
                            return .error(first.0, first.1)
                        } else {
                            let firstIndex = errors[0].1
                            let equalIndices = errors.first(where: { (_, index) -> Bool in
                                index != firstIndex
                            }) == nil
                            if equalIndices {
                                return ParseResult(error: "No parsers matched the first character \"\(Character(Unicode.Scalar(stream[next])))\"",
                                    index: next,
                                    stream: stream)
                            } else {
                                return defaultError()
                            }
                        }
                    } else {
                        return defaultError()
                    }
                }
        }
    }
}

func empty() -> Parser<()> {
    return { _, index in
        .ok((), index)
    }
}
