//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

import UIKit

/// A Tint mode and color.
public typealias AndroidTint = (BlendMode, UIColor)

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
        if bounds.size != .zero {
            for layer in layer.sublayers ?? [] {
                layer.frame = bounds
            }
        }
    }

    private func updateLayers() {
        if let drawable = drawable {
            drawableLayers = drawable.layerRepresentation(in: bounds,
                                                          using: ExternalValues(resources: resources,
                                                                                theme: theme),
                                                          tint: tint)
            drawableSize = drawable.intrinsicSize
        } else {
            drawableLayers = []
            drawableSize = .zero
        }
    }

    open override var intrinsicContentSize: CGSize {
        return drawableSize
    }

}

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
        return theme.colorFromTheme(named: name)
    }
    
    func colorFromResources(named name: String) -> UIColor {
        return resources.colorFromResources(named: name)
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
        return .init(width: baseWidth, height: baseHeight)
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

    #if DEBUG
    
    required override init(layer: Any) {
        // required because the view hierarchy debugger calls this
        let typedLayer = layer as! ShapeLayer
        pathData = typedLayer.pathData
        drawableSize = typedLayer.drawableSize
        pathTransform = typedLayer.pathTransform
        super.init(layer: layer)
    }
    
    #endif
    
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
    
    #if DEBUG
    
    required init(layer: Any) {
        let typedLayer = layer as! ThemeableShapeLayer
        externalValues = typedLayer.externalValues
        tint = typedLayer.tint
        super.init(layer: layer)
    }
    
    #endif
    
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
    
    #if DEBUG
    
    required override init(layer: Any) {
        let typedLayer = layer as! ThemeableGradientLayer
        gradient = typedLayer.gradient
        externalValues = typedLayer.externalValues
        super.init(layer: layer)
        updateGradient()
    }
    
    #endif
    
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
