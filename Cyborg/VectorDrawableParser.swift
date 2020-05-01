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

import CoreGraphics
import Foundation
import libxml2
import QuartzCore

/// Contains either an instance of  `Wrapped`,
/// or an `error` if the instance could not be deserialized.
///
/// - note: XML errors are presented in <line:column:depth> format.
/// The line and column always correspond to the end of the relevant element.
public enum Result<Wrapped> {

    case ok(Wrapped)
    case error(ParseError)

    func flatMap<T>(_ function: (Wrapped) -> Result<T>) -> Result<T> {
        switch self {
        case .ok(let wrapped): return function(wrapped)
        case .error(let error): return .error(error)
        }
    }

}

extension Sequence {

    func mapAllOrFail<T>(_ function: (Element) -> Result<T>) -> Result<[T]> {
        var result = [T]()
        result.reserveCapacity(underestimatedCount)
        for element in self {
            switch function(element) {
            case .ok(let wrapped): result.append(wrapped)
            case .error(let error): return .error(error)
            }
        }
        return .ok(result)
    }

}

/// An Error encountered when parsing. Generally optional, the presence of a value indicates that
/// an error occurred.
public typealias ParseError = String

public extension VectorDrawable {

    /// Attempts to create a new `VectorDrawable` by opening the file in `url`.
    ///
    /// - parameter url: The `URL` to load.
    /// - returns: The `VectorDrawable`, or an error if parsing failed.
    static func create(from url: URL) -> Result<VectorDrawable> {
        do {
            let data = try Data(contentsOf: url)
            return create(from: data)
        } catch let error {
            return .error(error.localizedDescription)
        }
    }

    /// Attempts to create a new `VectorDrawable` by parsing `data`.
    ///
    /// - parameter data: The `Data` to parse.
    /// - returns: The `VectorDrawable`, or an error if parsing failed.
    static func create(from data: Data) -> Result<VectorDrawable> {
        let parser = VectorParser()
        return data.withBytes(or: .error("Empty data passed.")) { (bytes: UnsafePointer<Int8>) -> Result<VectorDrawable> in
            let xml = xmlReaderForMemory(bytes,
                                         Int32(data.count),
                                         nil,
                                         nil,
                                         Int32(XML_PARSE_NOENT.rawValue))
            var xmlError: UnsafeMutablePointer<CChar>?
            let errorHandler: xmlTextReaderErrorFunc =
            { (xmlError: UnsafeMutableRawPointer?,
                message: UnsafePointer<Int8>?,
                severity: xmlParserSeverities,
                location: xmlTextReaderLocatorPtr?) in
                if severity == XML_PARSER_SEVERITY_ERROR {
                    if let message = message,
                        let xmlError = xmlError {
                        let lineNumber = xmlTextReaderLocatorLineNumber(location)
                        let error = """
                        <line number: \(lineNumber)>: \(String(cString: message))
                        """.utf8CString + [0]
                        error.withUnsafeBufferPointer { (buffer) in
                            if let address = buffer.baseAddress {
                                let e = UnsafeMutablePointer<CChar>.allocate(capacity: error.count)
                                e.assign(from: address, count: error.count)
                                xmlError.storeBytes(of: e, as: UnsafeMutablePointer<CChar>.self)
                            }
                        }
                    } else {
                        assertionFailure("There was an error, but a message or output variable wasn't provided.")
                    }
                }
            }
            func xmlErrorOr(_ alternative: () -> (Result<VectorDrawable>)) -> Result<VectorDrawable> {
                if let xmlError = xmlError {
                    defer {
                        xmlError
                            .deallocate()
                    }
                    return .error(String(cString: xmlError))
                } else {
                    return alternative()
                }
            }
            xmlTextReaderSetErrorHandler(xml,
                                         errorHandler,
                                         &xmlError)
            defer {
                xmlFreeTextReader(xml)
            }
            while xmlTextReaderRead(xml) == 1 {
                let count = xmlTextReaderAttributeCount(xml)
                if let namePointer = xmlTextReaderConstName(xml) {
                    let elementName = String(cString: namePointer)
                    let isEmpty = xmlTextReaderIsEmptyElement(xml) == 1
                    let type = xmlTextReaderNodeType(xml)
                    if type == XML_READER_TYPE_SIGNIFICANT_WHITESPACE.rawValue {
                        // we don't care about these, they show up as "#text"
                        // which disrupts the parsing
                        continue
                    }
                    if type == XML_READER_TYPE_END_ELEMENT.rawValue {
                        // The return value here indicates whether the parser ended, which we don't care about in this case.
                        _ = parser.didEnd(element: elementName)
                        continue
                    }
                    var attributes = [(XMLString, XMLString)]()
                    attributes.reserveCapacity(Int(count))
                    for _ in 0..<count {
                        if xmlTextReaderMoveToNextAttribute(xml) == 1 {
                            if let namePointer = xmlTextReaderConstName(xml),
                                let valuePointer = xmlTextReaderConstValue(xml) {
                                attributes.append((XMLString(namePointer),
                                                   XMLString(valuePointer)))
                            } else {
                                return xmlErrorOr {
                                    "failed to parse attribute".withLocationInXML(xml)
                                }
                            }
                        } else {
                            return xmlErrorOr {
                                "failed to move to next attribute".withLocationInXML(xml)
                            }
                        }
                    }
                    if let parseError = parser.parse(element: elementName,
                                                     attributes: attributes) {
                        return parseError.withLocationInXML(xml)
                    }
                    if isEmpty {
                        // handle self closing tags (<tag ... />)
                        _ = parser.didEnd(element: elementName)
                    }
                } else {
                    return xmlErrorOr {
                        "Failed to read element name".withLocationInXML(xml)
                    }
                }
            }
            return xmlErrorOr {
                parser.createElement()
            }
        }
    }
    
}


fileprivate extension String {
    
    func withLocationInXML(_ xml: xmlTextReaderPtr?) -> Result<VectorDrawable> {
        let line = xmlTextReaderGetParserLineNumber(xml)
        let column = xmlTextReaderGetParserColumnNumber(xml)
        let depth = xmlTextReaderDepth(xml)
        return .error("VectorDrawable Parsing Error: at XML <\(line):\(column):\(depth)> \n\(self)")
    }
    
}

// MARK: - Element Parsers

fileprivate func assign<T>(_ string: XMLString,
                           to property: inout T,
                           creatingWith creator: (XMLString) -> (T?)) -> ParseError? {
    if let value = creator(string) {
        property = value
        return nil
    } else {
        return "Could not assign \(string)"
    }
}

fileprivate func assign<T>(_ string: XMLString,
                           to property: inout T?) -> ParseError? where T: XMLStringRepresentable {
    assign(string, to: &property, creatingWith: T.init(_: ))
}

fileprivate func assign<T>(_ string: XMLString,
                           to property: inout T) -> ParseError? where T: XMLStringRepresentable {
    assign(string, to: &property, creatingWith: T.init(_: ))
}


fileprivate func assignFloat(_ string: XMLString,
                             to path: inout CGFloat?) -> ParseError? {
    assign(string, to: &path, creatingWith: CGFloat.init)
}

fileprivate func assignFloat(_ string: XMLString,
                             to path: inout CGFloat) -> ParseError? {
    assign(string, to: &path, creatingWith: CGFloat.init)
}

protocol NodeParsing: AnyObject {

    func parse(element: String, attributes: [(XMLString, XMLString)]) -> ParseError?

    func didEnd(element: String) -> Bool

}

extension NodeParsing {
    
    func parseAttributes<Enum>(_ attributes: [(XMLString, XMLString)],
                               _ onEachSuccess: (Enum, XMLString) -> (ParseError?)) -> ParseError? where Enum: XMLStringRepresentable {
        for (key, value) in attributes {
            if let error = convertToEnumOrFail(key, value, onEachSuccess) {
                return error
            }
        }
        return nil
    }
    
    fileprivate func convertToEnumOrFail<Enum>(_ attribute: XMLString,
                                               _ value: XMLString,
                                               _ onSuccess: (Enum, XMLString) -> (ParseError?)) -> ParseError? where Enum: XMLStringRepresentable {
        if let result = Enum(attribute) {
            return onSuccess(result, value)
        } else {
            return "\(attribute) is not a valid key for \(String(describing: type(of: self)))"
        }
    }
    
}

class ParentParser<Child>: NodeParsing where Child: NodeParsing {

    var currentChild: Child?
    var children: [Child] = []
    var hasFoundElement = false
    // Hack: indicates whether this is just a shell we created for the case where there's a child
    // at a high level. For example a vector node with a path elemement as its child: we make a fake
    // group for it so it type checks.
    let isArtificial: Bool

    init(isArtificial: Bool = false) {
        self.isArtificial = isArtificial
    }

    var name: Element {
        return .vector
    }

    func parse(element: String, attributes: [(XMLString, XMLString)]) -> ParseError? {
        if let currentChild = currentChild {
            return currentChild.parse(element: element, attributes: attributes)
        } else if element == name.rawValue,
            !hasFoundElement {
            hasFoundElement = true
            return parseAttributes(attributes)
        } else if let (child, assignment) = childForElement(element) {
            currentChild = child
            assignment(child)
            return child.parse(element: element, attributes: attributes)
        } else {
            if !hasFoundElement {
                return "Element \"\(element)\" found, expected \(name.rawValue)."
            } else {
                return "Found element \"\(element)\" nested in \(type(of: self)), when it is not an acceptable child node."
            }
        }
    }

    func parseAttributes(_: [(XMLString, XMLString)]) -> ParseError? {
        nil
    }

    func appendChild(_ child: Child) {
        children.append(child)
    }

    func childForElement(_: String) -> (Child, (Child) -> ())? {
        nil
    }

    func didEnd(element: String) -> Bool {
        if let child = currentChild,
            child.didEnd(element: element) {
            currentChild = nil
            return isArtificial
        } else {
            return element == name.rawValue
        }
    }

}

final class VectorParser: ParentParser<GroupParser> {

    var baseWidth: CGFloat?
    var baseHeight: CGFloat?
    var viewPortWidth: CGFloat?
    var viewPortHeight: CGFloat?
    var tintMode: BlendMode?
    var tintColor: Color?
    var autoMirrored: Bool = false
    var alpha: CGFloat = 1

    override func parseAttributes(_ attributes: [(XMLString, XMLString)]) -> ParseError? {
        var foundSchema = false
        for (key, value) in attributes {
            if let property = VectorProperty(rawValue: String(withoutCopying: key)) {
                let result: ParseError?
                switch property {
                case .resourceSchema:
                    result = nil
                case .schema:
                    foundSchema = true
                    result = nil
                case .height: result = assign(value, to: &baseHeight, creatingWith: parseAndroidMeasurement(from:))
                case .width: result = assign(value, to: &baseWidth, creatingWith: parseAndroidMeasurement(from:))
                case .viewPortHeight: result = assignFloat(value, to: &viewPortHeight)
                case .viewPortWidth: result = assignFloat(value, to: &viewPortWidth)
                case .tint: result = assign(value, to: &tintColor, creatingWith: Color.init)
                case .tintMode:
                    if let blendMode = BlendMode(value) {
                        tintMode = blendMode
                        result = nil
                    } else {
                        result = "Could not assign \(value)"
                    }
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
        if foundSchema {
            return nil
        } else {
            return "Schema not found in <vector>"
        }
    }

    override func childForElement(_ element: String) -> (GroupParser, (GroupParser) -> ())? {
        switch Element(rawValue: element) {
        // The group parser already has all its elements filled out,
        // so it'll "fall through" directly to the path.
        // All we need to do is give it a name for it to complete.
        case .some(.path): return (GroupParser(groupName: "anonymous", isArtificial: true), appendChild)
        case .some(.group): return (GroupParser(), appendChild)
        default: return nil
        }
    }

    func createElement() -> Result<VectorDrawable> {
        if let baseWidth = baseWidth,
            let baseHeight = baseHeight,
            let viewPortWidth = viewPortWidth,
            let viewPortHeight = viewPortHeight {
            return children.mapAllOrFail { group in
                group.createElement(in: CGSize(width: viewPortWidth, height: viewPortHeight))
            }
            .flatMap { (groups) -> Result<VectorDrawable> in
                .ok(.init(baseWidth: baseWidth,
                          baseHeight: baseHeight,
                          viewPortWidth: viewPortWidth,
                          viewPortHeight: viewPortHeight,
                          baseAlpha: alpha,
                          groups: groups,
                          autoMirrored: autoMirrored))
            }
        } else {
            return .error("Could not parse a <vector> element, but there was no error. This is a bug in the VectorDrawable Library.")
        }
    }

    func parseAndroidMeasurement(from text: XMLString) -> CGFloat? {
        if case .ok(let number, let index) = number(from: text, at: 0),
            let _ = AndroidUnitOfMeasure(rawValue: String(withoutCopying: text[index..<text.count])) {
            return number
        } else {
            return nil
        }
    }

}

final class PathParser: ParentParser<GradientParser>, GroupChildParser {

    static let name: Element = .path
    
    override var name: Element {
        .path
    }

    var pathName: String?
    var commands: ContiguousArray<PathSegment>?
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
    var fillType: CAShapeLayerFillRule = .nonZero

    override func parseAttributes(_ attributes: [(XMLString, XMLString)]) -> ParseError? {
        let baseError = "Error parsing the <android:pathData> tag: "
        for (key, value) in attributes {
            if let property = PathProperty(rawValue: String(withoutCopying: key)) {
                let result: ParseError?
                switch property {
                case .name:
                    pathName = String(withoutCopying: value)
                    result = nil
                case .pathData:
                    let subResult: ParseError?
                    let parsers = allDrawingCommands
                    switch consumeAll(using: parsers)(value, 0) {
                    case .ok(let result, _):
                        commands = result
                        subResult = nil
                    case .error(let error):
                        subResult = baseError + error.message
                    }
                    result = subResult
                case .fillColor:
                    if let color = Color(value) {
                        fillColor = color
                        result = nil
                    } else {
                        result = "Failed to create a color from \"\(String(copying: value))\""
                    }
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
                    result = assign(value, to: &fillType, creatingWith: { (string) -> (CAShapeLayerFillRule?) in
                        switch string {
                        case "evenOdd": return .evenOdd
                        case "nonZero": return .nonZero
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
        return nil
    }

    override func didEnd(element: String) -> Bool {
        if let currentChild = currentChild {
            return currentChild.didEnd(element: element)
        } else {
            return element == Element.path.rawValue
        }
    }

    override func childForElement(_ element: String) -> (GradientParser, (GradientParser) -> ())? {
        if element == "aapt:attr" {
            return (GradientParser(), appendChild)
        } else {
            return nil
        }
    }
    
    func createElement(in viewportSize: CGSize) -> Result<GroupChild> {
        let gradient: VectorDrawable.Gradient?
        if let first = children.first,
            let definiteGradient = first.createElement(in: viewportSize) {
            gradient = definiteGradient
        } else {
            gradient = nil
        }
        if let commands = commands {
            return .ok(VectorDrawable.Path(name: pathName,
                                           fillColor: fillColor,
                                           fillAlpha: fillAlpha,
                                           data: Array(commands.joined()),
                                           strokeColor: strokeColor,
                                           strokeWidth: strokeWidth,
                                           strokeAlpha: strokeAlpha,
                                           trimPathStart: trimPathStart,
                                           trimPathEnd: trimPathEnd,
                                           trimPathOffset: trimPathOffset,
                                           strokeLineCap: strokeLineCap,
                                           strokeLineJoin: strokeLineJoin,
                                           fillType: fillType,
                                           gradient: gradient))
        } else {
            return .error("\(PathProperty.pathData.rawValue) is a required property of <\(PathParser.name.rawValue)>.")
        }
    }

}

protocol GroupChildParser: NodeParsing {

    func createElement(in viewportSize: CGSize) -> Result<GroupChild>

}

final class ClipPathParser: NodeParsing, GroupChildParser {

    func createElement(in viewportSize: CGSize) -> Result<GroupChild> {
        switch (createElement as () -> (Result<VectorDrawable.ClipPath>))() {
        case .ok(let element): return .ok(element)
        case .error(let error): return .error(error)
        }
    }

    var name: String?
    var commands: ContiguousArray<PathSegment>?
    var fillType: CAShapeLayerFillRule?

    func parse(element _: String, attributes: [(XMLString, XMLString)]) -> ParseError? {
        for (key, value) in attributes {
            if let property = ClipPathProperty(rawValue: String(withoutCopying: key)) {
                switch property {
                case .name: name = String(withoutCopying: value)
                case .pathData:
                    let parsers = allDrawingCommands
                    switch consumeAll(using: parsers)(value, 0) {
                    case .ok(let result, _):
                        commands = result
                    case .error(let error):
                        let baseError = "Error parsing the <android:clipPath> tag: "
                        return baseError + error.message
                    }
                case .fillType:
                    fillType = CAShapeLayerFillRule(rawValue: String(copying: value))
                case .fillColor, .strokeColor:
                    // TODO: determine whether this needs to be handled
                    break
                }
            } else {
                return "Key \"\(key)\" is not a valid property of ClipPath."
            }
        }
        return nil
    }

    func didEnd(element _: String) -> Bool {
        true
    }

    func createElement() -> Result<VectorDrawable.ClipPath> {
        if let commands = commands {
            return .ok(.init(name: name,
                             path: Array(commands.joined()),
                             fillType: fillType ?? .evenOdd))
        } else {
            return .error("Didn't find \(PathProperty.pathData.rawValue), which is required in elements of type <\(Element.clipPath.rawValue)>")
        }
    }

}

/// Necessary because we can't use a protocol to satisfy a generic with
/// type bounds, as that would make it impossible to dispatch static functions.
final class AnyGroupParserChild: GroupChildParser {

    let parser: GroupChildParser

    init(erasing parser: GroupChildParser) {
        self.parser = parser
    }

    func parse(element: String, attributes: [(XMLString, XMLString)]) -> ParseError? {
        parser.parse(element: element, attributes: attributes)
    }

    func didEnd(element: String) -> Bool {
        parser.didEnd(element: element)
    }

    func createElement(in viewportSize: CGSize) -> Result<GroupChild> {
        parser.createElement(in: viewportSize)
    }

}

final class GroupParser: ParentParser<AnyGroupParserChild>, GroupChildParser {

    override var name: Element {
        return .group
    }

    var groupName: String?
    var pivotX: CGFloat = 0
    var pivotY: CGFloat = 0
    var rotation: CGFloat = 0
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
    var translationX: CGFloat = 0
    var translationY: CGFloat = 0
    var clipPaths = [ClipPathParser]()

    init(groupName: String? = nil, isArtificial: Bool = false) {
        self.groupName = groupName
        super.init(isArtificial: isArtificial)
    }

    override func parseAttributes(_ attributes: [(XMLString, XMLString)]) -> ParseError? {
        for (key, value) in attributes {
            if let property = GroupProperty(rawValue: String(withoutCopying: key)) {
                let result: ParseError?
                switch property {
                case .name:
                    groupName = String(withoutCopying: value)
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

    func createElement(in viewportSize: CGSize) -> Result<GroupChild> {
        children.mapAllOrFail { parser in
            parser.createElement(in: viewportSize)
        }
        .flatMap { childElements in
            clipPaths
                .mapAllOrFail { $0.createElement() as Result<VectorDrawable.ClipPath> }
                .flatMap { clipPaths in
                    .ok(VectorDrawable.Group(name: groupName,
                                             transform: Transform(pivot: .init(x: pivotX, y: pivotY),
                                                                  rotation: rotation,
                                                                  scale: .init(x: scaleX, y: scaleY),
                                                                  translation: .init(x: translationX, y: translationY)),
                                             children: childElements,
                                             clipPaths: clipPaths))
            }
        }
    }

    override func childForElement(_ element: String) -> (AnyGroupParserChild, (AnyGroupParserChild) -> ())? {
        switch Element(rawValue: element) {
        case .some(.path): return (AnyGroupParserChild(erasing: PathParser()), appendChild)
        case .some(.group): return (AnyGroupParserChild(erasing: GroupParser()), appendChild)
        case .some(.clipPath):
            let parser = ClipPathParser()
            return (AnyGroupParserChild(erasing: parser), { _ in self.clipPaths.append(parser) })
        default: return nil
        }
    }

}

class GradientParser: NodeParsing {
    
    let androidResourceAttribute = "aapt:attr"
    
    var startX: CGFloat?
    var startY: CGFloat?
    var endX: CGFloat?
    var endY: CGFloat?
    var centerX: CGFloat?
    var centerY: CGFloat?
    var radius: CGFloat?
    var type: GradientType = .linear
    var offsets: [VectorDrawable.Gradient.Offset] = []
    var centerColor: Color?
    var startColor: Color?
    var endColor: Color?
    var tileMode: TileMode = .clamp
    
    func parse(element: String, attributes: [(XMLString, XMLString)]) -> ParseError? {
        if element == androidResourceAttribute {
            for (key, value) in attributes {
                if String(withoutCopying: key) != "name" || String(withoutCopying: value) != PathProperty.fillColor.rawValue {
                    return "Only \(PathProperty.fillColor.rawValue) is supported in \(androidResourceAttribute) elements."
                } else {
                    return nil
                }
            }
            return nil
        } else if element == "gradient" {
            return parseAttributes(attributes) { (property: GradientProperty, value) -> (ParseError?) in
                switch property {
                case .centerColor: return assign(value, to: &centerColor, creatingWith: Color.init)
                case .startY: return assignFloat(value, to: &startY)
                case .startX: return assignFloat(value, to: &startX)
                case .endY: return assignFloat(value, to: &endY)
                case .endX: return assignFloat(value, to: &endX)
                case .type: return assign(value, to: &type)
                case .startcolor: return assign(value, to: &startColor, creatingWith: Color.init)
                case .endColor: return assign(value, to: &endColor, creatingWith: Color.init)
                case .tileMode: return assign(value, to: &tileMode)
                case .centerX: return assignFloat(value, to: &centerX)
                case .centerY: return assignFloat(value, to: &centerY)
                case .gradientRadius: return assignFloat(value, to: &radius)
                }
            }
        } else if element == "item" {
            var offset: CGFloat?
            var color: Color?
            let error = parseAttributes(attributes) { (property: ItemProperty, value) -> (ParseError?) in
                switch property {
                case .offset: return assignFloat(value, to: &offset)
                case .color: return assign(value, to: &color, creatingWith: Color.init)
                }
            }
            if let error = error {
                return error
            } else {
                switch (color, offset) {
                case (.some(let color), .some(let offset)):
                    offsets.append(VectorDrawable.Gradient.Offset(amount: offset, color: color))
                    return nil
                case (.none, .some):
                    return "Missing color"
                case (.some, .none):
                    return "Missing offset"
                case (.none, .none):
                    return "Missing color and offset"
                }
            }
        } else {
            return "Invalid element \"\(element)\""
        }
    }
    
    func didEnd(element: String) -> Bool {
        element == androidResourceAttribute
    }
    
    
    func createElement(in viewportSize: CGSize) -> VectorDrawable.Gradient? {
        switch type {
        case .linear:
            if let startX = startX,
                let startY = startY,
                let endX = endX,
                let endY = endY {
                let startXUnit = startX / viewportSize.width
                let startYUnit = startY / viewportSize.height
                let endXUnit = endX / viewportSize.width
                let endYUnit = endY / viewportSize.height
                return VectorDrawable.LinearGradient(startColor: startColor,
                                                     centerColor: centerColor,
                                                     endColor: endColor,
                                                     tileMode: tileMode,
                                                     startX: startXUnit,
                                                     startY: startYUnit,
                                                     endX: endXUnit,
                                                     endY: endYUnit,
                                                     offsets: offsets)
            } else {
                return nil
            }
        case .radial:
            if let centerX = centerX,
                let centerY = centerY,
                let radius = radius {
                return VectorDrawable.RadialGradient(startColor: startColor,
                                                     centerColor: centerColor,
                                                     endColor: endColor,
                                                     tileMode: tileMode,
                                                     centerX: centerX,
                                                     centerY: centerY,
                                                     radius: radius,
                                                     offsets: offsets)
            } else {
                return nil
            }
        case .sweep:
            if let centerX = centerX,
                let centerY = centerY {
                return VectorDrawable.SweepGradient(startColor: startColor,
                                                    centerColor: centerColor,
                                                    endColor: endColor,
                                                    tileMode: tileMode,
                                                    centerX: centerX,
                                                    centerY: centerY,
                                                    offsets: offsets)
            } else {
                return nil
            }
        }
    }
    
}

// MARK: - Parser Combinators

func number(from stream: XMLString, at index: Int32) -> ParseResult<CGFloat> {
    let substring = stream[index..<stream.count]
    return substring
        .withSignedIntegers { buffer in
            var next: UnsafeMutablePointer<Int8>? = UnsafeMutablePointer(mutating: buffer)
            let result = strtod(buffer, &next)
            if result == 0.0,
                next == buffer {
                return .error(.failedToParseNumber(.init(index: index, stream: stream)))
            } else if var final = next {
                if final.pointee == .comma {
                    final = final.advanced(by: 1)
                }
                let index = index + Int32(buffer.distance(to: final))
                return .ok(CGFloat(result), index)
            } else {
                return .error(.failedToParseNumber(.init(index: index, stream: stream)))
            }
        }
}

func numbers() -> Parser<[CGFloat]> {
    return { stream, index in
        var result = [CGFloat]()
        var nextIndex = index
        while case .ok(let value, let index) = number(from: stream, at: nextIndex) {
            result.append(value)
            nextIndex = index
        }
        if result.count > 0 {
            return .ok(result, nextIndex)
        } else {
            return .error(.failedToParseNumber(.init(index: nextIndex, stream: stream)))
        }
    }
}

func coordinatePair() -> Parser<CGPoint> {
    return { stream, index in
        var point: CGPoint = .zero
        var next = index
        if case .ok(let found, let index) = number(from: stream, at: next) {
            point.x = CGFloat(found)
            next = index
        } else {
            return .error(.noFirstMemberInCoordinatePair(.init(index: next, stream: stream)))
        }
        if case .ok(let found, let index) = number(from: stream, at: next) {
            point.y = CGFloat(found)
            next = index
        } else {
            return .error(.noSecondMemberInCoordinatePair(.init(index: next, stream: stream)))
        }
        return .ok(point, next)
    }
}

extension Data {
    #if compiler(>=5.0)
    func withBytes<T, U>(or alternative: T, _ function: (UnsafePointer<U>) -> (T)) -> T {
        return withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> T in
            if let baseAddress = pointer.baseAddress, pointer.count != 0 {
                let bytes = baseAddress.assumingMemoryBound(to: U.self)
                return function(bytes)
            } else {
                return alternative
            }
        }
    }
    #else
    func withBytes<T, U>(or alternative: T, _ function: (UnsafePointer<U>) -> (T)) -> T {
        return withUnsafeBytes { (pointer: UnsafePointer<U>) -> T in
            if count == 0 {
                return alternative
            } else {
                return function(pointer)
            }
        }
    }
    #endif
}
