//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

import UIKit

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

enum BlendMode: String {
    
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
    
    func layerConfigurations() -> [(CAShapeLayer) -> ()]
    
}

/// A VectorDrawable. This can be displayed in a `VectorView`.
public final class VectorDrawable {
    
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
    
    public static func create(from data: Data,
                              whenComplete run: @escaping (Result) -> ()) {
        DrawableParser(data: data, onCompletion: run)
            .start()
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
    
    func layerConfigurations() -> [(CAShapeLayer) -> ()] {
        return Array(
            groups
                .map { group in
                    group.layerConfigurations()
                }
                .joined()
        )
    }
    
    /// Representation of a <group> element from a VectorDrawable document.
    public class Group: GroupChild {
        
        /// The name of the group.
        public let name: String?
        
        /// The transform to apply to all children of the group.
        public let transform: Transform
        
        let children: [GroupChild]
        
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
                            path.apply(transform: transform.affineTransform(in: size))
                    }
                    }
                    .joined()
            )
        }
        
        func layerConfigurations() -> [(CAShapeLayer) -> ()] {
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
            print(path)
            return [path]
        }
        
        func layerConfigurations() -> [(CAShapeLayer) -> ()] {
            return [apply(to: )]
        }
        
        func apply(to layer: CAShapeLayer) {
            layer.strokeColor = strokeColor?.asUIColor.withAlphaComponent(strokeAlpha).cgColor
            layer.strokeStart = trimPathStart + trimPathOffset
            layer.strokeEnd = trimPathEnd + trimPathOffset
            layer.fillColor = fillColor?.asUIColor.withAlphaComponent(fillAlpha).cgColor
            layer.lineCap = strokeLineCap.intoCoreAnimation
            layer.lineJoin = strokeLineJoin.intoCoreAnimation
        }
    }
    
}

/// A rigid body transformation as specced by VectorDrawable.
public struct Transform {
    
    /// The offset from the origin to apply the rotation from. Specified in relative coordinates.
    public let pivot: CGPoint
    
    /// The rotation, in absolute terms.
    public let rotation: CGFloat
    
    /// The scale, in absolute terms.
    public let scale: CGPoint
    
    /// The translation, in relative terms.
    public let translation: CGPoint
    
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
    
    func affineTransform(in size: CGSize) -> CGAffineTransform {
        let translation = self.translation.times(size.width, size.height)
        let pivot = self.translation.times(size.width, size.height)
        let inversePivot = pivot.times(-1, -1)
        return CGAffineTransform(scaleX: scale.x, y: scale.y)
            .translatedBy(x: inversePivot.x, y: inversePivot.y)
            .rotated(by: rotation * .pi / 180)
            .translatedBy(x: pivot.x, y: pivot.y)
            .translatedBy(x: translation.x, y: translation.y)
    }
    
}

extension CGPath {
    
    func apply(transform: CGAffineTransform) -> CGPath {
        var transform = transform
        return copy(using: &transform) ?? self
    }
    
}
