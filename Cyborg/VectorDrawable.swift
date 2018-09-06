//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

import UIKit
import libxml2

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

enum BlendMode: String, XMLStringRepresentable {
    
    // TODO: make these have values from the vector drawable spec, add conversion function
    case add
    case clear
    case darken
    case dst
    case dstAtop
    case dstIn
    case dstOut
    case dstOver
    case lighten
    case multiply
    case overlay
    case screen
    case src
    case srcAtop
    case srcIn
    case srcOut
    case srcOver
    case xor
    
}

/// Child of a group. Necessary because both Paths and Groups are allowed
/// to be children of Groups, apparently.
protocol GroupChild: AnyObject {
    
    func createPaths(in size: CGSize) -> [CGPath]
    
    func layerConfigurations() -> [(CAShapeLayer, Theme) -> ()]
    
}

/// A VectorDrawable. This can be displayed in a `VectorView`.
public final class VectorDrawable: CustomDebugStringConvertible {
    
    /// The intrinsic width in points.
    public let baseWidth: CGFloat
    
    /// The intrinsic height in points.
    public let baseHeight: CGFloat
    
    /// The width that all path and group translation coordinates are relative to. Used
    /// to resize the VectorDrawable if it's not displayed at `baseWidth`.
    public let viewPortWidth: CGFloat
    
    /// The height that all path and group translation coordinates are relative to. Used
    /// to resize the VectorDrawable if it's not displayed at `baseHeight`.
    public let viewPortHeight: CGFloat
    
    /// The overall alpha to apply to the drawable.
    public let baseAlpha: CGFloat
    
    let groups: [GroupChild]
    
    public var debugDescription: String {
        return """
        <\(type(of: self)) \(ObjectIdentifier(self)))
          viewPort: \(viewPortWidth), \(viewPortHeight),
          baseDimensions: \(baseWidth), \(baseHeight)
          alpha: \(baseAlpha)
          groups: \(groups)
        >
        """
    }
    
    public static func create(from url: URL,
                              whenComplete run: @escaping (Result) -> ()) {
        do {
            let data = try Data(contentsOf: url)
            create(from: data, whenComplete: run)
        } catch let error {
            run(.error(error.localizedDescription))
        }
    }
    
    public static func create(from data: Data,
                              whenComplete run: @escaping (Result) -> ()) {
        let parser = VectorParser()
        data.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> () in
            let xml = xmlReaderForMemory(bytes,
                                         Int32(data.count),
                                         nil,
                                         nil,
                                         Int32(XML_PARSE_NOENT.rawValue))
            var lastElement = ""
            while xmlTextReaderRead(xml) == 1 {
                let count = xmlTextReaderAttributeCount(xml)
                if let namePointer = xmlTextReaderConstName(xml) {
                    let elementName = String(cString: namePointer)
                    lastElement = elementName
                    let type = xmlTextReaderNodeType(xml)
                    if type == XML_READER_TYPE_SIGNIFICANT_WHITESPACE.rawValue {
                        // we don't care about these, they show up as "#text"
                        // which disrupts the parsing
                        continue
                    }
                    if type == XML_READER_TYPE_END_ELEMENT.rawValue {
                        // TODO: check what to do with result here
                        _ = parser.didEnd(element: lastElement)
                        continue
                    }
                    var attributes = [(XMLString, XMLString)]()
                    attributes.reserveCapacity(Int(count))
                    for _ in 0..<count {
                        if xmlTextReaderMoveToNextAttribute(xml) == 1 {
                            if let namePointer = xmlTextReaderName(xml),
                                let valuePointer = xmlTextReaderValue(xml) {
                                attributes.append((XMLString(namePointer),
                                                   XMLString(valuePointer)))
                            } else {
                                run(.error("failed to parse attribute"))
                                return
                            }
                        } else {
                            run(.error("failed to move to next attribute"))
                            return
                        }
                    }
                    if let parseError = parser.parse(element: elementName,
                                                     attributes: attributes) {
                        run(.error(parseError))
                        return
                    }
                    // hack: end path elements manually, since they never have children (or do they)
                    // After it's parsed.
                    if String(elementName) == "path" {
                        _ = parser.didEnd(element: lastElement)
                        continue
                    }
                } else {
                    run(.error("Failed to read element name"))
                    return
                }
            }
            run(parser.createElement())
            return
        }
    }
    
    init(baseWidth: CGFloat,
         baseHeight: CGFloat,
         viewPortWidth: CGFloat,
         viewPortHeight: CGFloat,
         baseAlpha: CGFloat,
         groups: [GroupChild]) {
        self.baseWidth = baseWidth
        self.baseHeight = baseHeight
        self.viewPortWidth = viewPortWidth
        self.viewPortHeight = viewPortHeight
        self.baseAlpha = baseAlpha
        self.groups = groups
    }
    
    func createPaths(in size: CGSize) -> [CGPath] {
        return Array(
            groups
                .map { (group) in
                    group.createPaths(in: size)
                }
                .joined()
        )
    }
    
    func layerConfigurations() -> [(CAShapeLayer, Theme) -> ()] {
        return Array(
            groups
                .map { group in
                    group.layerConfigurations()
                }
                .joined()
        )
    }
    
    /// Representation of a <group> element from a VectorDrawable document.
    public class Group: GroupChild, CustomDebugStringConvertible {
        
        /// The name of the group.
        public let name: String?
        
        /// The transform to apply to all children of the group.
        public let transform: Transform
        
        let children: [GroupChild]
        
        public var debugDescription: String {
            return """
            < \(type(of: self)) \(ObjectIdentifier(self))
              name: \(name ?? "nil")
              transform: \(transform)
              children: \(children)
            >
            """
        }
        
        init(name: String?,
             transform: Transform,
             children: [GroupChild]) {
            self.name = name
            self.transform = transform
            self.children = children
        }
        
        func createPaths(in size: CGSize) -> [CGPath] {
            return Array(
                children.map { child in
                    return child
                        .createPaths(in: size)
                        .map { path in
                            transform.apply(to: path, in: size)
                    }
                    }
                    .joined()
            )
        }
        
        func layerConfigurations() -> [(CAShapeLayer, Theme) -> ()] {
            return Array(children.map { path in
                return path.layerConfigurations()
            }
            .joined())
        }
        
    }
    
    /// Representation of a <path> element from a VectorDrawable document.
    public class Path: GroupChild {
        
        /// The name of the group.
        public let name: String?
        
        let fillColor: Color?
        let data: [PathSegment]
        let strokeColor: Color?
        let strokeWidth: CGFloat
        let strokeAlpha: CGFloat
        let fillAlpha: CGFloat
        let trimPathStart: CGFloat
        let trimPathEnd: CGFloat
        let trimPathOffset: CGFloat
        let strokeLineCap: LineCap
        let strokeLineJoin: LineJoin
        let fillType: CGPathFillRule
        
        init(name: String?,
             fillColor: Color?,
             fillAlpha: CGFloat,
             data: [PathSegment],
             strokeColor: Color?,
             strokeWidth: CGFloat,
             strokeAlpha: CGFloat,
             trimPathStart: CGFloat,
             trimPathEnd: CGFloat,
             trimPathOffset: CGFloat,
             strokeLineCap: LineCap,
             strokeLineJoin: LineJoin,
             fillType: CGPathFillRule) {
            self.name = name
            self.data = data
            self.strokeColor = strokeColor
            self.strokeAlpha = strokeAlpha
            self.fillColor = fillColor
            self.fillAlpha = fillAlpha
            self.trimPathStart = trimPathStart
            self.trimPathEnd = trimPathEnd
            self.trimPathOffset = trimPathOffset
            self.strokeLineCap = strokeLineCap
            self.strokeLineJoin = strokeLineJoin
            self.fillType = fillType
            self.strokeWidth = strokeWidth
        }
        
        func createPaths(in size: CGSize) -> [CGPath] {
            let path = CGMutablePath()
            var context: PriorContext = .zero
            for command in data {
                context = command(context, path, size)
            }
            return [path]
        }
        
        func layerConfigurations() -> [(CAShapeLayer, Theme) -> ()] {
            return [apply(to: using:)]
        }
        
        func apply(to layer: CAShapeLayer, using theme: Theme) {
            layer.strokeColor = strokeColor?
                .color(from: theme)
                .withAlphaComponent(strokeAlpha)
                .cgColor
            layer.strokeStart = trimPathStart + trimPathOffset
            layer.strokeEnd = trimPathEnd + trimPathOffset
            layer.fillColor = fillColor?
                .color(from: theme)
                .withAlphaComponent(fillAlpha)
                .cgColor
            layer.lineCap = strokeLineCap.intoCoreAnimation
            layer.lineJoin = strokeLineJoin.intoCoreAnimation
        }
    }
    
}

/// A rigid body transformation as specced by VectorDrawable.
public struct Transform: CustomDebugStringConvertible {
    
    /// The offset from the origin to apply the rotation from. Specified in relative coordinates.
    public let pivot: CGPoint
    
    /// The rotation, in absolute terms.
    public let rotation: CGFloat
    
    /// The scale, in absolute terms.
    public let scale: CGPoint
    
    /// The translation, in relative terms.
    public let translation: CGPoint
    
    public var debugDescription: String {
        return """
        <\(type(of: self))
          pivot: \(pivot)
          rotation: \(rotation)
          scale: \(scale)
          translation: \(translation)
        >
        """
    }
    
    /// Intializer.
    ///
    /// - Parameters:
    ///   - pivot: The offset from the origin to apply the rotation from. Specified in relative coordinates.
    ///   - rotation: The rotation, in absolute terms.
    ///   - scale: The scale, in absolute terms.
    ///   - translation: The translation, in relative terms.
    public init(pivot: CGPoint,
                rotation: CGFloat,
                scale: CGPoint,
                translation: CGPoint) {
        self.pivot = pivot
        self.rotation = rotation
        self.scale = scale
        self.translation = translation
    }
    
    /// The Identity Transform.
    public static let identity: Transform = .init(pivot: .zero,
                                                  rotation: 0,
                                                  scale: CGPoint(x: 1, y: 1),
                                                  translation: .zero)
    
    func apply(to path: CGPath, in size: CGSize) -> CGPath {
        let translation = self.translation.times(size.width, size.height)
        let pivot = self.pivot.times(size.width, size.height)
        let inversePivot = pivot.times(-1, -1)
        return path
            .apply(transform: CGAffineTransform(scaleX: scale.x, y: scale.y))
            .apply(transform: CGAffineTransform(translationX: inversePivot.x, y: inversePivot.y)
                .rotated(by: rotation * .pi / 180)
                .translatedBy(x: pivot.x, y: pivot.y)
            )
            .apply(transform: CGAffineTransform(translationX: translation.x, y: translation.y))
    }
    
}

extension CGPath {
    
    func apply(transform: CGAffineTransform) -> CGPath {
        var transform = transform
        return copy(using: &transform) ?? self
    }
    
}
