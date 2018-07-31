//
//  VectorView.swift
//  Cyborg
//
//  Created by Ben Pious on 7/30/18.
//  Copyright © 2018 Ben Pious. All rights reserved.
//

import Foundation
import UIKit

open class VectorView: UIView {
    
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
    
    open var drawable: VectorDrawable? {
        didSet {
            updateLayers()
            invalidateIntrinsicContentSize()
        }
    }
    
    var drawableSize: CGSize = .zero
    
    private func updateLayers() {
        if let drawable = drawable {
            drawableLayers = drawable.layerRepresentation(in: bounds)
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
    
    func layerRepresentation(in bounds: CGRect) -> [CALayer] {
        if bounds.width == 0.0 || bounds.height == 0.0 {
            // there is no point in showing anything for a view of size zero
            return []
        } else {
            let viewSpace = CGSize(width: bounds.width / viewPortWidth,
                                   height: bounds.height / viewPortHeight)
            return createPaths(in: viewSpace).map { (path) in
                let layer = CAShapeLayer()
                layer.path = path
                layer.strokeColor = UIColor.black.cgColor
                layer.frame = bounds
                return layer
            }
        }
    }
    
    var intrinsicSize: CGSize {
        return .init(width: baseWidth, height: baseHeight)
    }
    
}
