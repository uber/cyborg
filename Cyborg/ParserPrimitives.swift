//
//  Copyright (c) 2018. Uber Technologies
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

typealias Parser<T> = (XMLString, Int32) -> ParseResult<T>

indirect enum Failure: Equatable {
    
    struct Metadata: Equatable {
        let index: Int32
        let stream: XMLString
    }
    
    case literalNotFoundAtIndex(XMLString, Metadata)
    case noMatchesFound(Failure)
    case noParsersMatchedFirstCharacter(XMLString.Char, Metadata)
    case allParsersFailed([Failure], Metadata)
    case tooFewNumbers(expected: Int, found: Int, Metadata)
    case noFirstMemberInCoordinatePair(Metadata)
    case noSecondMemberInCoordinatePair(Metadata)
    case failedToParseNumber(Metadata)
    
    var message: String {
        func error(message: String, index: Int32, stream: XMLString) -> String {
            return """
            Error at \(index):
            \(message)
            \(stream[0..<index])\(stream[index..<min(stream.count, index + 30)])
            \(String(repeating: "~", count: Int(index)) + "^")
            """
        }
        switch self {
        case .literalNotFoundAtIndex(let literal, let metadata):
            return error(message: "Expected \"\(String(copying: literal))\".",
                         index: metadata.index,
                         stream: metadata.stream)
        case .noMatchesFound(let reason):
            return "Failed before finding any matches. The error was: \(reason.message)"
        case .noParsersMatchedFirstCharacter(let character, let metadata):
            return error(message: "Expected one of the path commands, but found \"\(UnicodeScalar(character))\".",
                index: metadata.index, stream:
                metadata.stream)
        case .allParsersFailed(let failures, let metadata):
            return error(message: "Expected to consume all of the input, but all parsers failed with errors: \(failures.map { $0.message }.joined(separator: "\n"))",
                index: metadata.index,
                stream: metadata.stream)
        case .tooFewNumbers(let expected, let found, let metadata):
            return error(message: "Expected a multiple of \(expected) numbers, found \(found).",
                         index: metadata.index,
                         stream: metadata.stream)
        case .noFirstMemberInCoordinatePair(let metadata):
            return error(message: "Expected a coordinate pair, but couldn't find any numbers.",
                         index: metadata.index,
                         stream: metadata.stream)
        case .noSecondMemberInCoordinatePair(let metadata):
            return error(message: "Expected a coordinate pair, but only found one number.",
                         index: metadata.index,
                         stream: metadata.stream)
        case .failedToParseNumber(let metadata):
            return error(message: "Expected a number.",
                         index: metadata.index,
                         stream: metadata.stream)
        }
    }
    
    var index: Int32 {
        switch self {
        case .literalNotFoundAtIndex(_, let metadata):
            return metadata.index
        case .noMatchesFound(let metadata):
            return metadata.index
        case .noParsersMatchedFirstCharacter(_, let metadata):
            return metadata.index
        case .allParsersFailed(_, let metadata):
            return metadata.index
        case .tooFewNumbers(_, _, let metadata):
            return metadata.index
        case .noFirstMemberInCoordinatePair(let metadata):
            return metadata.index
        case .noSecondMemberInCoordinatePair(let metadata):
            return metadata.index
        case .failedToParseNumber(let metadata):
            return metadata.index
        }
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

func consumeAll<T>(using parsers: [Parser<T>]) -> Parser<ContiguousArray<T>> {
    return { (stream: XMLString, index: Int32) in
        var index = index,
        results: ContiguousArray<T> = [],
        errors: ContiguousArray<Failure> = []
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
                    if errors.first(where: { (error: Failure) -> Bool in
                        if case .literalNotFoundAtIndex = error {
                            return false
                        } else {
                            return true
                        }
                    }) == nil {
                        return .error(.noParsersMatchedFirstCharacter(stream[next], .init(index: next, stream: stream)))
                    } else {
                        var furthestError = errors.first
                        var foundUnequalIndex = false
                        for error in errors.dropFirst() {
                            let lastIndex = furthestError?.index ?? -1
                            if error.index != lastIndex {
                                foundUnequalIndex = true
                                if error.index > lastIndex {
                                    furthestError = error
                                }
                            }
                        }
                        if let furthestError = furthestError,
                            foundUnequalIndex {
                            return .error(furthestError)
                        } else {
                            return .error(.allParsersFailed(Array(errors), .init(index: next, stream: stream)))
                        }
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
