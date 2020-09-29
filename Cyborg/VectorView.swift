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

#if os(macOS)
import AppKit


/// Displays a VectorDrawable.
open class VectorView: NSView {

    /// The tint to use for this drawable.
    ///
    /// This property is useful primarily for cases where
    /// the drawable is intended to be reused in many contexts,
    /// such as icons. In the icon case, you may find it useful to
    /// set the tint to `(.dst, myColor)`, which will choose
    /// `myColor` instead of the color specified in the xml.
    ///
    /// This property is overridden by the `VectorDrawable`'s `tint` property
    /// if it has been set.
    ///
    /// - note: `tint` is considered external to the VectorDrawable
    /// and won't be updated when `theme` is set, though it will apply to
    /// new values provided by the theme.
    /// It is your responsibility to ensure that changes
    /// to `theme` also change `tint` if appropriate.
    public var tint: AndroidTint = (.src, .clear) {
        didSet {
            updateLayers()
        }
    }

    /// A source for external values to use to theme the VectorDrawable.
    public var theme: ThemeProviding {
        didSet {
            updateLayers()
        }
    }

    private let resources: ResourceProviding

    /// The drawable to display.
    open var drawable: VectorDrawable? {
        didSet {
            updateLayers()
            needsLayout = true
            invalidateIntrinsicContentSize()
        }
    }

    private var drawableLayers: [CALayer] = [] {
        didSet {
            for layer in oldValue {
                layer.removeFromSuperlayer()
            }
            for drawableLayer in drawableLayers {
                layer?.addSublayer(drawableLayer)
            }
        }
    }

    private var drawableSize: CGSize = .zero

    /// Initializer.
    ///
    /// - parameter externalValues: A source for external values to use to theme the VectorDrawable.
    public init(theme: ThemeProviding, resources: ResourceProviding) {
        self.theme = theme
        self.resources = resources
        super.init(frame: .zero)
    }

    @available(*, unavailable, message: "NSCoder and Interface Builder is not supported. Use Programmatic layout.")
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func layout() {
        super.layout()
        func makeActualSize(_ drawable: VectorDrawable,
                            at point: CGPoint) {
            for layer in layer?.sublayers ?? [] {
                layer.frame = .init(origin: point,
                                    size: drawable.intrinsicSize)
            }
        }
        if bounds.size != .zero,
            let drawable = drawable {
            func scaleToFill() {
                for layer in layer?.sublayers ?? [] {
                    layer.frame = bounds
                }
            }
            
            func scaleToFit() {
                let size = drawable.intrinsicSize.scaleAspectFit(in: bounds.size)
                for layer in layer?.sublayers ?? [] {
                    layer.frame = .init(origin: bounds.origin,
                                        size: size)
                }
            }
            
            func center() {
                makeActualSize(drawable,
                               at: .init(x: bounds.origin.x + bounds.size.width / 2 - drawable.baseWidth / 2,
                                         y: bounds.origin.y + bounds.size.height / 2 - drawable.baseHeight / 2))
            }
            
            switch contentMode {
            case .scaleAxesIndependently:
                scaleToFill()
            case .scaleProportionallyUpOrDown:
                scaleToFit()
            case .scaleProportionallyDown:
                if drawable.intrinsicSize.width > bounds.size.width &&
                    drawable.intrinsicSize.height > bounds.size.height {
                    scaleToFit()
                } else {
                    center()
                }
            case .scaleNone:
                center()
            @unknown default:
                // assume it's scaleToFill.
                scaleToFill()
            }
        }
    }

    private func updateLayers() {
        if let drawable = drawable {
            drawableLayers = drawable.layerRepresentation(in: bounds,
                                                          using: ExternalValues(resources: resources,
                                                                                theme: theme),
                                                          tint: drawable.tint ?? tint)
            updateAutoMirror(to: drawable.autoMirrored)
            drawableSize = drawable.intrinsicSize
        } else {
            drawableLayers = []
            drawableSize = .zero
        }
    }
    
    private func updateAutoMirror(to isMirrored: Bool) {
        let transform: CATransform3D
        if isMirrored,
            case .rightToLeft = userInterfaceLayoutDirection {
            transform = CATransform3DMakeScale(-1, 1, 1)
        } else {
            transform = CATransform3DIdentity
        }
        for layer in drawableLayers {
            layer.transform = transform
        }
    }

    open override var intrinsicContentSize: NSSize {
        drawableSize
    }
    
    open var contentMode: NSImageScaling = .scaleNone {
        didSet {
            updateLayers()
        }
    }

}

#else

import UIKit

/// Displays a VectorDrawable.
open class VectorView: UIView {

    /// The tint to use for this drawable.
    ///
    /// This property is useful primarily for cases where
    /// the drawable is intended to be reused in many contexts,
    /// such as icons. In the icon case, you may find it useful to
    /// set the tint to `(.dst, myColor)`, which will choose
    /// `myColor` instead of the color specified in the xml.
    ///
    /// This property is overridden by the `VectorDrawable`'s `tint` property
    /// if it has been set.
    ///
    /// - note: `tint` is considered external to the VectorDrawable
    /// and won't be updated when `theme` is set, though it will apply to
    /// new values provided by the theme.
    /// It is your responsibility to ensure that changes
    /// to `theme` also change `tint` if appropriate.
    public var tint: AndroidTint = (.src, .clear) {
        didSet {
            updateLayers()
        }
    }

    /// A source for external values to use to theme the VectorDrawable.
    public var theme: ThemeProviding {
        didSet {
            updateLayers()
        }
    }

    private let resources: ResourceProviding

    /// The drawable to display.
    open var drawable: VectorDrawable? {
        didSet {
            updateLayers()
            invalidateIntrinsicContentSize()
        }
    }

    private var drawableLayers: [CALayer] = [] {
        didSet {
            for layer in oldValue {
                layer.removeFromSuperlayer()
            }
            for drawableLayer in drawableLayers {
                layer.addSublayer(drawableLayer)
            }
        }
    }

    private var drawableSize: CGSize = .zero

    /// Initializer.
    ///
    /// - parameter externalValues: A source for external values to use to theme the VectorDrawable.
    public init(theme: ThemeProviding, resources: ResourceProviding) {
        self.theme = theme
        self.resources = resources
        super.init(frame: .zero)
    }

    @available(*, unavailable, message: "NSCoder and Interface Builder is not supported. Use Programmatic layout.")
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        func makeActualSize(_ drawable: VectorDrawable,
                            at point: CGPoint) {
            for layer in layer.sublayers ?? [] {
                layer.frame = .init(origin: point,
                                    size: drawable.intrinsicSize)
            }
        }
        if bounds.size != .zero,
            let drawable = drawable {
            func scaleToFill() {
                for layer in layer.sublayers ?? [] {
                    layer.frame = bounds
                }
            }
            switch contentMode {
            case .scaleToFill,
                 .redraw: // redraw behaves the same as scaleToFil in `UIImageView`
                scaleToFill()
            case .scaleAspectFit:
                let size = drawable.intrinsicSize.scaleAspectFit(in: bounds.size)
                for layer in layer.sublayers ?? [] {
                    layer.frame = .init(origin: bounds.origin,
                                        size: size)
                }
            case .scaleAspectFill:
                let size = drawable.intrinsicSize.scaleAspectFill(in: bounds.size)
                for layer in layer.sublayers ?? [] {
                    layer.frame = .init(origin: .init(x: bounds.origin.x + bounds.size.width / 2 - size.width / 2,
                                                      y: bounds.origin.y + bounds.size.height / 2 - size.height / 2),
                                        size: size)
                }
            case .center:
                makeActualSize(drawable,
                               at: .init(x: bounds.origin.x + bounds.size.width / 2 - drawable.baseWidth / 2,
                                         y: bounds.origin.y + bounds.size.height / 2 - drawable.baseHeight / 2))
            case .top:
                makeActualSize(drawable,
                               at: .init(x: bounds.origin.x + bounds.size.width / 2 - drawable.baseWidth / 2,
                                         y: 0))
            case .bottom:
                makeActualSize(drawable,
                               at: .init(x: bounds.origin.x + bounds.size.width / 2 - drawable.baseWidth / 2,
                                         y: bounds.origin.y + bounds.size.height - drawable.baseHeight))
            case .left:
                makeActualSize(drawable,
                               at: .init(x: 0,
                                         y: bounds.origin.y + bounds.size.height / 2 - drawable.baseHeight / 2))
            case .right:
                makeActualSize(drawable,
                               at: .init(x: bounds.origin.x + bounds.size.width - drawable.baseWidth,
                                         y: bounds.origin.y + bounds.size.height / 2 - drawable.baseHeight / 2))
            case .topLeft:
                makeActualSize(drawable,
                               at: .init(x: 0,
                                         y: 0))
            case .topRight:
                makeActualSize(drawable,
                               at: .init(x: bounds.origin.x + bounds.size.width - drawable.baseWidth,
                                         y: 0))
            case .bottomLeft:
                makeActualSize(drawable,
                               at: .init(x: 0,
                                         y: bounds.origin.y + bounds.size.height - drawable.baseHeight))
            case .bottomRight:
                makeActualSize(drawable,
                               at: .init(x: bounds.origin.x + bounds.size.width - drawable.baseWidth,
                                         y: bounds.origin.y + bounds.size.height - drawable.baseHeight))
            @unknown default:
                // assume it's scaleToFill.
                scaleToFill()
            }
        }
    }

    private func updateLayers() {
        if let drawable = drawable {
            drawableLayers = drawable.layerRepresentation(in: bounds,
                                                          using: ExternalValues(resources: resources,
                                                                                theme: theme),
                                                          tint: drawable.tint ?? tint)
            updateAutoMirror(to: drawable.autoMirrored)
            drawableSize = drawable.intrinsicSize
        } else {
            drawableLayers = []
            drawableSize = .zero
        }
    }
    
    private func updateAutoMirror(to isMirrored: Bool) {
        let transform: CATransform3D
        if isMirrored,
            case .rightToLeft = effectiveUserInterfaceLayoutDirection {
            transform = CATransform3DMakeScale(-1, 1, 1)
        } else {
            transform = CATransform3DIdentity
        }
        for layer in drawableLayers {
            layer.transform = transform
        }
    }

    open override var semanticContentAttribute: UISemanticContentAttribute {
        didSet {
            updateAutoMirror(to: drawable?.autoMirrored ?? false)
        }
    }

    open override var intrinsicContentSize: CGSize {
        drawableSize
    }
    
    open override var contentMode: UIView.ContentMode {
        didSet {
            updateLayers()
        }
    }

}
#endif

/// Provides values from a "theme" which
/// corresponds to the objects of the same name on Android. You can reimplement the
/// Android behavior, or write your own system.
public protocol ThemeProviding {

    /// Gets the color that corresponds to `name` from the Theme. Colors prefixed "?"
    /// in the VectorDrawable XML file are fetched using this function.
    ///
    /// - parameter name: the name of the external value
    /// - note: You are responsible for providing an appropriate value or crashing
    /// in the event that you cannot create a color for the name.
    func colorFromTheme(named name: String) -> UIColor

}

/// Provides values from "resources" which
/// corresponds to the objects of the same name on Android. You can reimplement the
/// Android behavior, or write your own system.
public protocol ResourceProviding {

    /// Gets the color that corresponds to `name` from the Resources bundle. Colors prefixed "@"
    /// in the VectorDrawable XML file are fetched using this function.
    ///
    /// - parameter name: the name of the external value
    /// - note: You are responsible for providing an appropriate value or crashing
    /// in the event that you cannot create a color for the name.
    func colorFromResources(named name: String) -> UIColor

}

struct ExternalValues {

    let resources: ResourceProviding
    let theme: ThemeProviding

    func colorFromTheme(named name: String) -> UIColor {
        theme.colorFromTheme(named: name)
    }

    func colorFromResources(named name: String) -> UIColor {
        resources.colorFromResources(named: name)
    }

}

extension VectorDrawable {

    func layerRepresentation(in _: CGRect,
                             using externalValues: ExternalValues,
                             tint: AndroidTint) -> [CALayer] {
        let viewSpace = CGSize(width: viewPortWidth,
                               height: viewPortHeight)
        return Array(
            groups
                .map { group in
                    group.createLayers(using: externalValues,
                                       drawableSize: viewSpace,
                                       transform: [],
                                       tint: tint)
                }
                .joined()
        )
    }

    var intrinsicSize: CGSize {
        .init(width: baseWidth, height: baseHeight)
    }

}

final class ChildResizingLayer: CALayer {

    override func layoutSublayers() {
        super.layoutSublayers()
        mask?.frame = bounds
        if let sublayers = sublayers {
            for layer in sublayers {
                layer.frame = bounds
            }
        }
    }

}

class ShapeLayer<T>: CAShapeLayer where T: PathCreating {

    fileprivate let pathData: T

    fileprivate let pathTransform: [Transform]

    fileprivate var drawableSize: CGSize {
        didSet {
            updateRatio()
        }
    }

    fileprivate var ratio: CGSize = .init(width: 1, height: 1) {
        didSet {
            path = pathTransform
                .apply(to: pathData.createPaths(in: ratio),
                       relativeTo: ratio)
        }
    }

    private func updateRatio() {
        ratio = CGSize(width: bounds.width / drawableSize.width,
                       height: bounds.height / drawableSize.height)
    }

    required override init(layer: Any) {
        if let typedLayer = layer as? ShapeLayer {
            pathData = typedLayer.pathData
            drawableSize = typedLayer.drawableSize
            pathTransform = typedLayer.pathTransform
            super.init(layer: layer)
        } else {
            fatalError("Core Animation passed a layer of type \(Swift.type(of: layer)), which cannot be used to construct a layer of type \(ShapeLayer.self)")
        }
    }

    init(pathData: T,
         drawableSize: CGSize,
         transform: [Transform],
         name: String?) {
        self.pathData = pathData
        self.drawableSize = drawableSize
        pathTransform = transform
        super.init()
        self.name = name
    }

    @available(*, unavailable, message: "NSCoder and Interface Builder is not supported. Use Programmatic layout.")
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSublayers() {
        super.layoutSublayers()
        if let sublayers = sublayers {
            for layer in sublayers {
                layer.frame = bounds
            }
        }
        updateRatio()
    }

}

final class ThemeableShapeLayer: ShapeLayer<VectorDrawable.Path> {

    fileprivate var externalValues: ExternalValues {
        didSet {
            updateTheme()
        }
    }

    fileprivate var tint: AndroidTint {
        didSet {
            updateTheme()
        }
    }

    private func updateTheme() {
        pathData.apply(to: self,
                       using: externalValues,
                       tint: tint)
    }

    init(pathData: VectorDrawable.Path,
         externalValues: ExternalValues,
         drawableSize: CGSize,
         transform: [Transform],
         tint: AndroidTint) {
        self.externalValues = externalValues
        self.tint = tint
        super.init(pathData: pathData,
                   drawableSize: drawableSize,
                   transform: transform,
                   name: pathData.name)
        updateTheme()
    }

    required init(layer: Any) {
        if let typedLayer = layer as? ThemeableShapeLayer {
            externalValues = typedLayer.externalValues
            tint = typedLayer.tint
            super.init(layer: layer)
        } else {
            fatalError("Core Animation passed a layer of type \(Swift.type(of: layer)), which cannot be used to construct a layer of type \(ThemeableShapeLayer.self)")
        }
    }

}

final class ThemeableGradientLayer: CAGradientLayer {

    var gradient: VectorDrawable.Gradient {
        didSet {
            updateGradient()
        }
    }

    var externalValues: ExternalValues {
        didSet {
            updateGradient()
        }
    }


    init(gradient: VectorDrawable.Gradient,
         externalValues: ExternalValues) {
        self.gradient = gradient
        self.externalValues = externalValues
        super.init()
        updateGradient()
    }

    required override init(layer: Any) {
        if let typedLayer = layer as? ThemeableGradientLayer {
            gradient = typedLayer.gradient
            externalValues = typedLayer.externalValues
            super.init(layer: layer)
            updateGradient()
        } else {
            fatalError("Core Animation passed a layer of type \(Swift.type(of: layer)), which cannot be used to construct a layer of type \(ThemeableGradientLayer.self)")
        }
    }

    @available(*, unavailable, message: "NSCoder and Interface Builder is not supported. Use Programmatic layout.")
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSublayers() {
        super.layoutSublayers()
        mask?.frame = bounds
    }

    private func updateGradient() {
        gradient.apply(to: self)
    }

}

extension CGSize {
        
    func scaleAspectFit(in dimensions: CGSize) -> CGSize {
        scaledToAspect(in: dimensions,
                       with: min)
    }
    
    func scaleAspectFill(in dimensions: CGSize) -> CGSize {
        scaledToAspect(in: dimensions,
                       with: max)
    }
    
    private func scaledToAspect(in dimensions: CGSize,
                                with function: (CGFloat, CGFloat) -> (CGFloat)) -> CGSize {
        let heightRatio = dimensions.height / height
        let widthRatio = dimensions.width / width
        let ratio = function(heightRatio, widthRatio)
        return .init(width: width * ratio,
                     height: height * ratio)
    }
    
}
