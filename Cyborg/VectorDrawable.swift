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

    func createLayers(using externalValues: ValueProviding,
                      drawableSize: CGSize,
                      transform: [Transform]) -> [CALayer]

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

        func createLayers(using externalValues: ValueProviding,
                          drawableSize: CGSize,
                          transform: [Transform]) -> [CALayer] {
            var clipPathLayers = clipPaths.map { clipPath in
                clipPath.createLayer(drawableSize: drawableSize,
                                     transform: transform + [self.transform])
            }
            let pathLayers = Array(
                children.map { child in
                    child.createLayers(using: externalValues,
                                       drawableSize: drawableSize,
                                       transform: transform + [self.transform])
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

        func createLayers(using _: ValueProviding,
                          drawableSize: CGSize,
                          transform: [Transform]) -> [CALayer] {
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
             fillType: CAShapeLayerFillRule) {
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

        func createLayers(using externalValues: ValueProviding,
                          drawableSize: CGSize,
                          transform: [Transform]) -> [CALayer] {
            return [ThemeableShapeLayer(pathData: self,
                                        externalValues: externalValues,
                                        drawableSize: drawableSize,
                                        transform: transform)]
        }

        func apply(to layer: CAShapeLayer,
                   using externalValues: ValueProviding) {
            layer.name = name
            layer.strokeColor = strokeColor?
                .color(from: externalValues)
                .withAlphaComponent(strokeAlpha)
                .cgColor
            layer.strokeStart = trimPathStart + trimPathOffset
            layer.strokeEnd = trimPathEnd + trimPathOffset
            layer.fillColor = fillColor?
                .color(from: externalValues)
                .withAlphaComponent(fillAlpha)
                .cgColor
            layer.lineCap = strokeLineCap.intoCoreAnimation
            layer.lineJoin = strokeLineJoin.intoCoreAnimation
            layer.lineWidth = strokeWidth
            layer.fillRule = fillType
        }
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
