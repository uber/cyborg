import UIKit

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
    
    func transform<T>(_ transformer: (Wrapped, String.Index) -> (ParseResult<T>)) -> ParseResult<T> {
        switch self {
        case .ok(let value, let index):
            return transformer(value, index)
        case .error(let error): return .error(error)
        }
    }
    
}

typealias ParseError = String

enum ParentNode: String {
    case vectorShape = "vector"
    case shapePath = "path"
}

enum AndroidUnitOfMeasure: String {
    case px
    case inch = "in"
    case mm
    case pt
    case dp
    case sp
    
    func convertToPoints(from value: Int) -> CGFloat {
        let floatValue = CGFloat(value)
        // TODO
        return floatValue
    }
    
    static var all: [AndroidUnitOfMeasure] = [
        .dp,
        .px,
        .pt,
        .inch,
        .mm,
        .pt,
        .sp,
        ]
    
}

enum VectorProperty: String {
    
    case height = "android:height"
    case width = "android:width"
    case viewPortHeight = "android:viewportHeight"
    case viewPortWidth = "android:viewportWidth"
    
    var parserAttribute: ReferenceWritableKeyPath<DrawableParser, CGFloat?> {
        switch self {
        case .height: return \.baseHeight
        case .width: return \.baseWidth
        case .viewPortWidth: return \.viewPortWidth
        case .viewPortHeight: return \.viewPortHeight
        }
    }
}

enum DrawableProperty: String {
    case pathShiftX = "shift-x"
    case pathShiftY = "shift-y"
    case shapeGroup = "group"
    case pathID = "android:name"
    case pathDescription = "android:pathData" // TODO
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
    
    func createSegment(using rawInput: [Int]) -> RelativePathSegment {
        let floats = rawInput.map(CGFloat.init(integerLiteral:))
        func relative(to point: CGPoint) -> (CGFloat, CGFloat) -> CGPoint {
            return { x, y in
                return CGPoint(x: x + point.x, y: y + point.y)
            }
        }
        switch self {
        case .closePathAbsolute, .closePath: return { point, path in
            path.closeSubpath()
            return point
            }
        case .move: return { point, path in
            let moveTo = CGPoint(x: floats[0] + point.x, y: floats[1] + point.y)
            path.move(to: point)
            return moveTo
            }
        case .moveAbsolute: return { point, path in
            let moveTo = CGPoint(x: floats[0], y: floats[1])
            path.move(to: point)
            return moveTo
            }
        case .horizontal: return { point, path in
            let moveTo = CGPoint(x: floats[0] + point.x, y: point.y)
            path.move(to: point)
            return moveTo
            }
        case .horizontalAbsolute: return { point, path in
            let moveTo = CGPoint(x: floats[0], y: point.y)
            path.move(to: point)
            return moveTo
            }
        case .vertical: return { point, path in
            let moveTo = CGPoint(x: point.x, y: floats[0] + point.y)
            path.move(to: point)
            return moveTo
            }
        case .verticalAbsolute: return { point, path in
            let moveTo = CGPoint(x: point.x, y: floats[0])
            path.move(to: point)
            return moveTo
            }
        case .curve: return { point, path in
            let point = relative(to: point)
            let first = point(floats[0], floats[1]),
            second = point(floats[2], floats[3]),
            end = point(floats[4], floats[5])
            path.addCurve(to: end, control1: first, control2: second)
            return end
            }
        case .curveAbsolute: return { point, path in
            let first = CGPoint(x: floats[0], y: floats[1]),
            second = CGPoint(x: floats[2], y: floats[3]),
            end = CGPoint(x: floats[4], y: floats[5])
            path.addCurve(to: end, control1: first, control2: second)
            return end
            }
        case .reflectedQuadratic: return { point, path in
            let pointMaker = relative(to: point)
            let destination = pointMaker(floats[0], floats[1])
            path.addQuadCurve(to: destination, control: point)
            return destination
            }
        case .reflectedQuadraticAbsolute: return { point, path in
            let destination = CGPoint(x: floats[0], y: floats[1])
            path.addQuadCurve(to: destination, control: point)
            return destination
            }
        case .quadratic: return { point, path in
            let point = relative(to: point)
            let first = point(floats[0], floats[1]),
            second = point(floats[2], floats[3])
            path.addQuadCurve(to: second, control: first)
            return second
            }
        case .quadraticAbsolute: return { point, path in
            let first = CGPoint(x: floats[0], y: floats[1]),
            second = CGPoint(x: floats[2], y: floats[3])
            path.addQuadCurve(to: second, control: first)
            return second
            }
        case .arc: return { point, path in
            fatalError()
            }
        case .arcAbsolute: return { point, path in
            fatalError() // TODO
            }
        case .line: return { point, path in
            let next = CGPoint(x: floats[0], y: floats[1])
            path.move(to: next)
            return next
            }
        case .smoothCurve: return { point, path in
            fatalError()
            }
        case .smoothCurveAbsolute: return { point, path in
            fatalError()
            }
        }
    }
    
    var parser: Parser<RelativePathSegment> {
        return { stream, index in
            if let (result, nextIndex) = consumeTrivia(before: pair(of: literal(self.rawValue),
                                              n(self.consumed,
                                                of: consumeTrivia(before: int()))))(stream, index)
                .asOptional {
                return .ok(self.createSegment(using: result.1), nextIndex)
            } else {
                return ParseResult(error: "Failed to parse \(self)",
                    index: index,
                    stream: stream)
            }
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

typealias RelativePathSegment = (CGPoint, CGMutablePath) -> (CGPoint)
typealias Parser<T> = (String, String.Index) -> ParseResult<T>

final class DrawableParser: NSObject, XMLParserDelegate {
    
    let xml: XMLParser
    let onCompletion: (VectorDrawable?) -> ()
    
    var baseWidth: CGFloat?
    var baseHeight: CGFloat?
    var viewPortWidth: CGFloat?
    var viewPortHeight: CGFloat?
    var baseAlpha: CGFloat?
    var commands: [RelativePathSegment]?
    
    init(data: Data, onCompletion: @escaping (VectorDrawable?) -> ()) {
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
                if !parseVectorShape(from: attributeDict) {
                    // TODO: write a good error message
                }
            case .shapePath:
                if let error = parseShape(from: attributeDict) {
                    print(error) // TODO
                }
            }
        }
    }
    
    private func parseVectorShape(from attributes: [String: String]) -> Bool {
        var attributes = attributes
        let schema = "xmlns:android"
        if attributes.keys.contains(schema) {
            attributes.removeValue(forKey: schema)
        } else {
            return false
        }
        for (key, value) in attributes {
            if let attribute = VectorProperty(rawValue: key),
                let intValue = parseAndroidMeasurement(from: value) {
                // TODO: convert to Android Coords
                self[keyPath: attribute.parserAttribute] = CGFloat(intValue)
            } else {
                return false
            }
        }
        return true
    }
    
    private func parseShape(from attributes: [String: String]) -> ParseError? {
        // TODO: pick up fillcolor, name, etc
        let parsers = DrawingCommand
            .all
            .map { (command) -> Parser<RelativePathSegment> in
                command.parser
        }
        let pathData = attributes["android:pathData"]!
        switch consumeAll(using: parsers)(pathData, pathData.startIndex) {
        case .ok(let result, _):
            self.commands = result
            return nil
        case .error(let error): return error
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
            onCompletion(result)
        } else {
            onCompletion(nil)
        }
    }
}

public class VectorDrawable {
    
    public let baseWidth: CGFloat
    public let baseHeight: CGFloat
    public let viewPortWidth: CGFloat
    public let viewPortHeight: CGFloat
    public let baseAlpha: CGFloat
    let commands: [RelativePathSegment]
    
    public static func create(from data: Data,
                              whenComplete run: @escaping (VectorDrawable?) -> ()) {
        var retainParser: DrawableParser? = nil
        let drawableParser = DrawableParser(data: data) { (drawable: VectorDrawable?) in
            retainParser?.stop()
            retainParser = nil
            run(drawable)
        }
        retainParser = drawableParser
        retainParser?.start()
    }
    
    init(baseWidth: CGFloat,
         baseHeight: CGFloat,
         viewPortWidth: CGFloat,
         viewPortHeight: CGFloat,
         baseAlpha: CGFloat,
         commands: [RelativePathSegment]) {
        self.baseWidth = baseWidth
        self.baseHeight = baseHeight
        self.viewPortWidth = viewPortWidth
        self.viewPortHeight = viewPortHeight
        self.baseAlpha = baseAlpha
        self.commands = commands
    }
    
    func createPath() -> CGPath {
        let path = CGMutablePath()
        var lastPoint: CGPoint = .zero
        for command in commands {
            lastPoint = command(lastPoint, path)
        }
        return path
    }
    
}

func shapeLayer(fillColor: CGColor, fillAlpha: CGFloat, fillType: String) -> () -> CAShapeLayer {
    return {
        let layer = CAShapeLayer()
        layer.fillRule = fillType
        layer.opacity = Float(fillAlpha)
        layer.fillColor = fillColor
        return layer
    }
}

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

func trivia() -> Parser<String> {
    return { stream, index in
        let whitespace: Set<Character> = [" ", "\n", ","] // TODO
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

func createInt(from text: String) -> Int? { // necessary to prevent ambiguity, otherwise I'd use Int.init(_ description:)
    return Int(text) // TODO: does not work, takes the entire strng
}


