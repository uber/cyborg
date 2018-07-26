//
//  ParserPrimitives.swift
//  Cyborg
//
//  Created by Ben Pious on 7/25/18.
//  Copyright © 2018 Ben Pious. All rights reserved.
//

import Foundation

func literal(_ text: String) -> Parser<String> {
    return { (stream: String, index: String.Index) in
        if let endOfRange = stream.index(index, offsetBy: text.count, limitedBy: stream.endIndex) {
            let potentialMatch = stream[index..<endOfRange]
            if potentialMatch == text {
                return .ok(String(potentialMatch), endOfRange)
            } else {
                return ParseResult(error: "Literal ", index: index, stream: stream)
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
                if let nextIndex = stream.index(index, offsetBy: 1, limitedBy: stream.endIndex) {
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
        results: [T] = []
        untilNoMatchFound: while true {
            for parser in parsers {
                if let (match, currentIndex) = parser(stream, index).asOptional {
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
        first(stream, index).transform { firstResult, index in
            second(stream, index).transform { (secondResult, index) in
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

