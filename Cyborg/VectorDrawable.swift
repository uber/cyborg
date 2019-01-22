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
        // TODO: Implement
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

/// Android Blend Mode. See https://developer.android.com/reference/android/graphics/PorterDuff.Mode
/// for details on the various options.
public enum BlendMode: String, XMLStringRepresentable {
    
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

    func createLayers(using externalValues: ExternalValues,
                      drawableSize: CGSize,
                      transform: [Transform],
                      tint: AndroidTint) -> [CALayer]

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

    /// Representation of a <group> element from a VectorDrawable document.
    public class Group: GroupChild {

        /// The name of the group.
        public let name: String?

        /// The transform to apply to all children of the group.
        public let transform: Transform

        let children: [GroupChild]

        let clipPaths: [ClipPath]

        init(name: String?,
             transform: Transform,
             children: [GroupChild],
             clipPaths: [ClipPath]) {
            self.name = name
            self.transform = transform
            self.children = children
            self.clipPaths = clipPaths
        }

        func createLayers(using externalValues: ExternalValues,
                          drawableSize: CGSize,
                          transform: [Transform],
                          tint: AndroidTint) -> [CALayer] {
            var clipPathLayers = clipPaths.map { clipPath in
                clipPath.createLayer(drawableSize: drawableSize,
                                     transform: transform + [self.transform])
            }
            let pathLayers = Array(
                children.map { child in
                    child.createLayers(using: externalValues,
                                       drawableSize: drawableSize,
                                       transform: transform + [self.transform],
                                       tint: tint)
                }
                .joined()
            )
            if clipPathLayers.isEmpty {
                return pathLayers
            } else {
                let superLayer = ChildResizingLayer()
                let maskParent = clipPathLayers.remove(at: 0)
                for layer in clipPathLayers {
                    maskParent.addSublayer(layer)
                }
                superLayer.mask = maskParent
                for child in pathLayers {
                    superLayer.addSublayer(child)
                }
                return [superLayer]
            }
        }

    }

    public class ClipPath: GroupChild, PathCreating {

        public let name: String?
        let data: [DrawingCommand]

        init(name: String?,
             path: [DrawingCommand]) {
            self.name = name
            data = path
        }

        func createLayer(drawableSize size: CGSize,
                         transform: [Transform]) -> CALayer {
            let layer = ShapeLayer(pathData: self,
                                   drawableSize: size,
                                   transform: transform,
                                   name: name)
            layer.fillColor = UIColor.black.cgColor
            return layer
        }

        func createLayers(using _: ExternalValues,
                          drawableSize: CGSize,
                          transform: [Transform],
                          tint: AndroidTint) -> [CALayer] {
            return [createLayer(drawableSize: drawableSize,
                                transform: transform)]
        }

    }

    /// Representation of a <path> element from a VectorDrawable document.
    public class Path: GroupChild, PathCreating {

        /// The name of the group.
        public let name: String?

        let fillColor: Color?
        let data: [DrawingCommand]
        let strokeColor: Color?
        let strokeWidth: CGFloat
        let strokeAlpha: CGFloat
        let fillAlpha: CGFloat
        let trimPathStart: CGFloat
        let trimPathEnd: CGFloat
        let trimPathOffset: CGFloat
        let strokeLineCap: LineCap
        let strokeLineJoin: LineJoin
        let fillType: CAShapeLayerFillRule
        let gradient: Gradient?

        init(name: String?,
             fillColor: Color?,
             fillAlpha: CGFloat,
             data: [DrawingCommand],
             strokeColor: Color?,
             strokeWidth: CGFloat,
             strokeAlpha: CGFloat,
             trimPathStart: CGFloat,
             trimPathEnd: CGFloat,
             trimPathOffset: CGFloat,
             strokeLineCap: LineCap,
             strokeLineJoin: LineJoin,
             fillType: CAShapeLayerFillRule,
             gradient: Gradient?) {
            self.name = name
            self.data = data
            if gradient != nil && fillColor == nil {
                // The path will be used as a mask if there's a gradient, so it's necessary to
                // ensure that it has a fill color
                self.fillColor = .hex(value: .black)
            } else {
                // TODO: it's not clear if this is the correct behavior,
                // or if a vector drawable with a fillColor defined and
                // a gradient as the other fill color should be an error.
                self.fillColor = fillColor
            }
            self.strokeAlpha = strokeAlpha
            self.strokeColor = strokeColor
            self.fillAlpha = fillAlpha
            self.trimPathStart = trimPathStart
            self.trimPathEnd = trimPathEnd
            self.trimPathOffset = trimPathOffset
            self.strokeLineCap = strokeLineCap
            self.strokeLineJoin = strokeLineJoin
            self.fillType = fillType
            self.strokeWidth = strokeWidth
            self.gradient = gradient
        }

        func createLayers(using externalValues: ExternalValues,
                          drawableSize: CGSize,
                          transform: [Transform],
                          tint: AndroidTint) -> [CALayer] {
            let shapeLayer = ThemeableShapeLayer(pathData: self,
                                                 externalValues: externalValues,
                                                 drawableSize: drawableSize,
                                                 transform: transform,
                                                 tint: tint)
            if let gradient = gradient {
                let gradientLayer = ThemeableGradientLayer(gradient: gradient, externalValues: externalValues)
                gradientLayer.mask = shapeLayer
                return [gradientLayer]
            } else {
                return [shapeLayer]
            }
        }

        func apply(to layer: CAShapeLayer,
                   using externalValues: ExternalValues,
                   tint: AndroidTint) {
            layer.name = name
            layer.strokeColor = strokeColor?
                .color(from: externalValues)
                .multiplyAlpha(with: strokeAlpha)
                .tintedWith(tint)
                .cgColor
            layer.strokeStart = trimPathStart + trimPathOffset
            layer.strokeEnd = trimPathEnd + trimPathOffset
            layer.fillColor = fillColor?
                .color(from: externalValues)
                .multiplyAlpha(with: fillAlpha)
                .tintedWith(tint)
                .cgColor
            layer.lineCap = strokeLineCap.intoCoreAnimation
            layer.lineJoin = strokeLineJoin.intoCoreAnimation
            layer.lineWidth = strokeWidth
            layer.fillRule = fillType
        }
    }
    
    public class Gradient {
        
        let startColor: Color?
        let centerColor: Color?
        let endColor: Color?
        let tileMode: TileMode
        let offsets: [Offset]
        
        init(startColor: Color?,
             centerColor: Color?,
             endColor: Color?,
             tileMode: TileMode,
             offsets: [Offset]) {
            self.startColor = startColor
            self.centerColor = centerColor
            self.endColor = endColor
            self.tileMode = tileMode
            self.offsets = offsets
        }
        
        struct Offset {
            let amount: CGFloat
            let color: Color
        }
        
        func createLayer(using externalValues: ExternalValues,
                         drawableSize: CGSize,
                         transform: [Transform]) -> CALayer {
            return ThemeableGradientLayer(gradient: self,
                                          externalValues: externalValues)
        }
        
        func apply(to layer: ThemeableGradientLayer) {
            layer.colors = offsets.map { (offset) in
                let color = offset.color.color(from: layer.externalValues)
                return color.cgColor
            }
            layer.locations = offsets.map { offset in
                offset.amount as NSNumber
            }
        }
        
    }
    
    public class LinearGradient: Gradient {
        
        let start: CGPoint
        let end: CGPoint
        
        init(startColor: Color?,
             centerColor: Color?,
             endColor: Color?,
             tileMode: TileMode,
             startX: CGFloat,
             startY: CGFloat,
             endX: CGFloat,
             endY: CGFloat,
             offsets: [Offset]) {
            start = .init(x: startX, y: startY)
            end = .init(x: endX, y: endY)
            super.init(startColor: startColor,
                       centerColor: centerColor,
                       endColor: endColor,
                       tileMode: tileMode,
                       offsets: offsets)
        }
        
        override func apply(to layer: ThemeableGradientLayer) {
            layer.type = .axial
            layer.startPoint = start
            layer.endPoint = end
            super.apply(to: layer)
        }
    }
    
    public class RadialGradient: Gradient {
        
        let center: CGPoint
        let radius: CGFloat
        
        init(startColor: Color?,
             centerColor: Color?,
             endColor: Color?,
             tileMode: TileMode,
             centerX: CGFloat,
             centerY: CGFloat,
             radius: CGFloat,
             offsets: [Offset]) {
            self.radius = radius
            center = .init(x: centerX, y: centerY)
            super.init(startColor: startColor,
                       centerColor: centerColor,
                       endColor: endColor,
                       tileMode: tileMode,
                       offsets: offsets)
        }
        
        override func apply(to layer: ThemeableGradientLayer) {
            assertionFailure("Radial Gradients are not yet supported")
            super.apply(to: layer)
        }
    }
    
    public class SweepGradient: Gradient {
        
        let center: CGPoint
        
        init(startColor: Color?,
             centerColor: Color?,
             endColor: Color?,
             tileMode: TileMode,
             centerX: CGFloat,
             centerY: CGFloat,
             offsets: [Offset]) {
            center = .init(x: centerX, y: centerY)
            super.init(startColor: startColor,
                       centerColor: centerColor,
                       endColor: endColor,
                       tileMode: tileMode,
                       offsets: offsets)
        }
        
        override func apply(to layer: ThemeableGradientLayer) {
            assertionFailure("Sweep Gradients are not yet supported")
            super.apply(to: layer)
        }
    }

}

extension UIColor {
    
    func multiplyAlpha(with other: CGFloat) -> UIColor {
        return withAlphaComponent(alpha * other)
    }
    
    var alpha: CGFloat {
        var alpha: CGFloat = 0
        getRed(nil, green: nil, blue: nil, alpha: &alpha)
        return alpha
    }
    
    var rgba: (CGFloat, CGFloat, CGFloat, CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }
    
    func tintedWith(_ tint: AndroidTint) -> UIColor {
        let (mode, color) = tint
        return mode.blend(src: self, dst: color)
    }
    
}

extension Array where Element == Transform {

    func apply(to path: CGPath, relativeTo size: CGSize) -> CGPath {
        return reduce(path) { path, transform in
            transform.apply(to: path, relativeTo: size)
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

    func apply(to path: CGPath, relativeTo size: CGSize) -> CGPath {
        let translation = self.translation.times(size.width, size.height)
        let pivot = self.pivot.times(size.width, size.height)
        let inversePivot = pivot.times(-1, -1)
        return path
            .apply(transform: CGAffineTransform(scaleX: scale.x, y: scale.y))
            .apply(transform: CGAffineTransform(translationX: inversePivot.x, y: inversePivot.y)
                .rotated(by: rotation * .pi / 180)
                .translatedBy(x: pivot.x, y: pivot.y))
            .apply(transform: CGAffineTransform(translationX: translation.x, y: translation.y))
    }

}

extension CGPath {

    func apply(transform: CGAffineTransform) -> CGPath {
        var transform = transform
        return copy(using: &transform) ?? self
    }

}

protocol PathCreating: AnyObject {

    var data: [DrawingCommand] { get }

}

extension PathCreating {

    func createPaths(in size: CGSize) -> CGPath {
        let path = CGMutablePath()
        var context: PriorContext = .zero
        for command in data {
            context = command.apply(to: path, using: context, in: size)
        }
        return path
    }

}

extension BlendMode {
    
    func blend(src: UIColor, dst: UIColor) -> UIColor {
        let (sr, sg, sb, sa) = src.rgba
        let (dr, dg, db, da) = dst.rgba
        func clamp(_ float: CGFloat) -> CGFloat {
            return max(0, min(float, 1))
        }
        func createColor(_ color: (CGFloat, CGFloat) -> CGFloat,
                         _ alpha: (CGFloat, CGFloat) -> CGFloat) -> UIColor {
            return UIColor(red: clamp(color(sr, dr)),
                           green: clamp(color(sg, dg)),
                           blue: clamp(color(sb, db)),
                           alpha: clamp(alpha(sa, da)))
        }
        switch self {
        case .add:
            return createColor(+, +)
        case .clear:
            return createColor({ _, _ in 0 }, { _, _ in 0 })
        case .darken:
            return createColor({ (src: CGFloat, dst: CGFloat) -> CGFloat in (1 - da) * src + (1 - sa) * dst + min(src, dst) },
                               { src, dst in src + dst - (src * dst) })
        case .dst:
            return dst
        case .dstAtop:
            return createColor({ src, dst in sa * dst + (1 - da) * src }, { _, dst in dst })
        case .dstIn:
            return createColor({ src, dst in dst * sa }, { src, dst in src * dst })
        case .dstOut:
            return createColor({ src, dst in (1 - sa) * dst }, { src, dst in (1 - src) * dst })
        case .dstOver:
            return createColor({ src, dst in dst + (1 - da) * src }, { src, dst in da + ( 1 - da) * sa })
        case .lighten:
            return createColor({ (src: CGFloat, dst: CGFloat) in ( 1 - da) * src + (1 - sa) * dst + max(src, dst) }, { src, dst in src + dst - src * dst })
        case .multiply:
            return createColor(*, *)
        case .overlay:
            return createColor({src, dst in
                let first = 2 * src * dst
                if first < da {
                    return first
                } else {
                    return sa * dst - 2 * (da - src) * (sa - dst)
                }
            }, {src, dst in
                src + dst - src * dst
            })
        case .screen:
            return createColor({ src, dst in src + dst - src * dst }, { src, dst in src + dst - src * dst })
        case .src:
            return createColor({ src, _ in src }, { src, _ in src })
        case .srcAtop:
            return createColor({ src, dst in da * src + (1 - sa) * dst }, { _, dst in dst })
        case .srcIn:
            return createColor({ src, dst in src * dst }, { src, dst in src * dst })
        case .srcOut:
            return createColor({ src, dst in (1 - da ) * src }, { src, dst in (1 - dst) * src })
        case .srcOver:
            return createColor({ src, dst in src + (1 - sa ) * dst }, { src, dst in src + (1 - src) * dst })
        case .xor:
            return createColor({ src, dst in (1 - da) * src + (1 - sa) * dst}, { src, dst in (1 - dst) * src + (1 - src) * dst})
        }
    }

}
