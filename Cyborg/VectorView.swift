//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

import UIKit

/// Displays a VectorDrawable.
open class VectorView: UIView {

    /// A source for external values to use to theme the VectorDrawable.
    public var externalValues: ValueProviding {
        didSet {
            updateLayers()
        }
    }

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
    public init(externalValues: ValueProviding) {
        self.externalValues = externalValues
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
            drawableLayers = drawable.layerRepresentation(in: bounds, using: externalValues)
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

/// Provides values from various sources: a "theme," and "resources", which
/// correspond to the objects of the same name on Android. You can reimplement the
/// Android behavior, or write your own system.
public protocol ValueProviding {

    /// Gets the color that corresponds to `name` from the Theme. Colors prefixed "?"
    /// in the VectorDrawable XML file are fetched using this function.
    ///
    /// - parameter name: the name of the external value
    /// -note: You are responsible for providing an appropriate value or crashing
    /// in the event that you cannot create a color for the name.
    func colorFromTheme(named name: String) -> UIColor

    /// Gets the color that corresponds to `name` from the Resources bundle. Colors prefixed "@"
    /// in the VectorDrawable XML file are fetched using this function.
    ///
    /// - parameter name: the name of the external value
    /// -note: You are responsible for providing an appropriate value or crashing
    /// in the event that you cannot create a color for the name.
    func colorFromResources(named name: String) -> UIColor

}

extension VectorDrawable {

    func layerRepresentation(in _: CGRect,
                             using externalValues: ValueProviding) -> [CALayer] {
        let viewSpace = CGSize(width: viewPortWidth,
                               height: viewPortHeight)
        return Array(
            groups
                .map { group in
                    group.createLayers(using: externalValues,
                                       drawableSize: viewSpace,
                                       transform: [])
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

    init(pathData: T,
         drawableSize: CGSize,
         transform: [Transform]) {
        self.pathData = pathData
        self.drawableSize = drawableSize
        pathTransform = transform
        super.init()
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

    fileprivate var externalValues: ValueProviding {
        didSet {
            updateTheme()
        }
    }

    private func updateTheme() {
        pathData.apply(to: self,
                       using: externalValues)
    }

    init(pathData: VectorDrawable.Path,
         externalValues: ValueProviding,
         drawableSize: CGSize,
         transform: [Transform]) {
        self.externalValues = externalValues
        super.init(pathData: pathData,
                   drawableSize: drawableSize,
                   transform: transform)
        updateTheme()
    }

}
