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
    
    let groups: [Group]
    
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
         groups: [Group]) {
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
                    group.createPath(in: size)
                }
                .joined()
        )
    }
    
    /// Representation of a <group> element from a VectorDrawable document.
    public class Group {
        
        /// The name of the group.
        public let name: String
        
        /// The transform to apply to all children of the group.
        public let transform: Transform
        
        let paths: [Path]
        
        init(name: String,
             transform: Transform,
             paths: [Path]) {
            self.name = name
            self.transform = transform
            self.paths = paths
        }
        
        func createPath(in size: CGSize) -> [CGPath] {
            return paths.map { path in
                var transform = self.transform.affineTransform(in: size)
                return path.createPath(in: size).copy(using: &transform)! // TODO: idk how this could fail
            }
        }
        
    }
    
    /// Representation of a <path> element from a VectorDrawable document.
    public class Path {
        
        /// The name of the group.
        public let name: String
        
        let fillColor: Color
        let data: [PathSegment]
        let strokeColor: Color
        let strokeWidth: CGFloat
        let strokeAlpha: CGFloat
        let fillAlpha: CGFloat
        let trimPathStart: CGFloat
        let trimPathEnd: CGFloat
        let trimPathOffset: CGFloat
        let strokeLineCap: LineCap
        let strokeLineJoin: LineJoin
        let fillType: CGPathFillRule
        
        init(name: String,
             fillColor: Color,
             fillAlpha: CGFloat,
             data: [PathSegment],
             strokeColor: Color,
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
        
        func createPath(in size: CGSize) -> CGPath {
            let path = CGMutablePath()
            var context: PriorContext = .zero
            for command in data {
                context = command(context, path, size)
            }
            return path // TODO: apply transform
        }
        
        func apply(to layer: CAShapeLayer) {
            layer.strokeColor = strokeColor.asUIColor.withAlphaComponent(strokeAlpha).cgColor
            layer.strokeStart = trimPathStart + trimPathOffset
            layer.strokeEnd = trimPathEnd + trimPathOffset
            layer.fillColor = fillColor.asUIColor.withAlphaComponent(fillAlpha).cgColor
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
