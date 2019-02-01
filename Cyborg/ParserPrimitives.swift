//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

import Foundation

typealias Parser<T> = (XMLString, Int32) -> ParseResult<T>

indirect enum Failure {
    
    struct Metadata {
        let index: Int32
        let stream: XMLString
    }
    
    case literalNotFoundAtIndex(XMLString, Metadata)
    case noMatchesFound(Failure)
    case noParsersMatchedFirstCharacter(XMLString.Char, Metadata)
    case allParsersFailed([Failure], Metadata)
    case tooFewNumbers(Int, Metadata)
    case noFirstMemberInCoordinatePair(Metadata)
    case noSecondMemberInCoordinatePair(Metadata)
    case foundNoNumbers(Metadata)
    case failedToParseNumber(Metadata)
    
    var errorMessage: String {
        func error(message: String, index: Int32, stream: XMLString) -> String {
            return """
            Error at \(index): \(error)
            \(stream[0..<index])\(stream[index..<min(stream.count, index + 30)])
            \(String(repeating: "~", count: Int(index)) + "^")
            """
        }
        fatalError()
//        switch self {
//        case .literalNotFoundAtIndex(let literal, let metadata):
//            return error(message: String(copying: literal),
//                         index: metadata.index,
//                         stream: metadata.stream)
//        case .noMatchesFound(let reason, let metadata):
//
//        case .noParsersMatchedFirstCharacter(_, _):
//            <#code#>
//        case .allParsersFailed(_, _):
//            <#code#>
//        case .tooFewNumbers(_, _):
//            <#code#>
//        case .noFirstMemberInCoordinatePair(_):
//            <#code#>
//        case .noSecondMemberInCoordinatePair(_):
//            <#code#>
//        case .foundNoNumbers(_):
//            <#code#>
//        case .failedToParseNumber(_):
//            <#code#>
//        }
    }
}

enum ParseResult<Wrapped> {

    case ok(Wrapped, Int32)
    case error(Failure)

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
            return .error(.noMatchesFound(error))
        }
    }
}

func literal(_ text: XMLString) -> Parser<XMLString> {
    return { (stream: XMLString, index: Int32) in
        if stream.matches(text, at: index) {
            return .ok(text, index + text.count)
        } else {
            return .error(.literalNotFoundAtIndex(text, .init(index: index, stream: stream)))
        }
    }
}

func consumeAll<T>(using parsers: [Parser<T>]) -> Parser<[T]> {
    return { (stream: XMLString, index: Int32) in
        var index = index,
        results: [T] = [],
        errors: [Failure] = []
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
                        case .error(let error):
                            errors.append(error)
                        }
                }
                if index == stream.count {
                    return .ok(results, index)
                } else {
                    if errors.filter({ (error) -> Bool in
                        if case .literalNotFoundAtIndex = error {
                            return true
                        } else {
                            return false
                        }
                    }).count != 0 {
                        return .error(.noParsersMatchedFirstCharacter(stream[next], .init(index: next, stream: stream)))
                    } else {
                        return .error(.allParsersFailed(errors, .init(index: next, stream: stream)))
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
