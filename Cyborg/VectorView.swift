//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

import Foundation
import UIKit

/// Displays a VectorDrawable.
open class VectorView: UIView {
    
    public var theme: Theme {
        didSet {
            updateLayers()
        }
    }
    
    public init(theme: Theme) {
        self.theme = theme
        super.init(frame: .zero)
    }
    
    @available(*, unavailable, message: "NSCoder and Interface Builder is not supported. Use Programmatic layout.")
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != .zero {
            for layer in (layer.sublayers ?? []) {
                layer.frame = bounds
            }
        }
    }
    
    /// The drawable to display.
    open var drawable: VectorDrawable? {
        didSet {
            updateLayers()
            invalidateIntrinsicContentSize()
        }
    }
    
    private var drawableSize: CGSize = .zero
    
    private func updateLayers() {
        if let drawable = drawable {
            drawableLayers = drawable.layerRepresentation(in: bounds, using: theme)
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


extension VectorDrawable {
    
    func layerRepresentation(in bounds: CGRect,
                             using theme: Theme) -> [CALayer] {
        let viewSpace = CGSize(width: viewPortWidth,
                               height: viewPortHeight)
        return Array(
            groups
                .map{ (group) in
                    group.createLayers(using: theme,
                                       drawableSize: viewSpace,
                                       transform: [.identity])
                }
                .joined()
        )
    }
    
    var intrinsicSize: CGSize {
        return .init(width: baseWidth, height: baseHeight)
    }
    
}

public protocol Theme {
    
    func color(named string: String) -> UIColor
    
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
                       in: ratio)
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
        self.pathTransform = transform
        super.init()
    }
    
    @available(*, unavailable, message: "NSCoder and Interface Builder is not supported. Use Programmatic layout.")
    required init?(coder aDecoder: NSCoder) {
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
        path = pathData.createPaths(in: ratio)
    }

}

final class ThemeableShapeLayer: ShapeLayer<VectorDrawable.Path> {
    
    fileprivate var theme: Theme {
        didSet {
            updateTheme()
        }
    }
    
    private func updateTheme() {
        pathData.apply(to: self,
                       using: theme)
    }
    
    init(pathData: VectorDrawable.Path,
         theme: Theme,
         drawableSize: CGSize,
         transform: [Transform]) {
        self.theme = theme
        super.init(pathData: pathData,
                   drawableSize: drawableSize,
                   transform: transform)
        updateTheme()
    }
    
}
