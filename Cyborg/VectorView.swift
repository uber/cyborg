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
        updateLayers()
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
    
    func layerRepresentation(in bounds: CGRect, using theme: Theme) -> [CALayer] {
        if bounds.width == 0.0 || bounds.height == 0.0 {
            // there is no point in showing anything for a view of size zero
            return []
        } else {
            let viewSpace = CGSize(width: bounds.width / viewPortWidth,
                                   height: bounds.height / viewPortHeight)
            return zip(layerConfigurations(),
                       createPaths(in: viewSpace))
                .map { (configuration, path) in
                    let layer = CAShapeLayer()
                    configuration(layer, theme)
                    layer.path = path
                    layer.frame = bounds
                    return layer
            }
        }
    }
    
    var intrinsicSize: CGSize {
        return .init(width: baseWidth, height: baseHeight)
    }
    
}

public protocol Theme {
    
    func color(named string: String) -> UIColor
    
}
