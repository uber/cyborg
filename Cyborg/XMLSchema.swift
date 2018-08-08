//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

import Foundation

/// Elements of a VectorDrawable document.
enum Element: String {
    case vector = "vector"
    case path = "path"
    case group = "group"
}

/// Elements of the <vector> element of a VectorDrawable document.
enum VectorProperty: String {
    
    case height = "android:height"
    case width = "android:width"
    case viewPortHeight = "android:viewportHeight"
    case viewPortWidth = "android:viewportWidth"
    case tint = "android:tint"
    case tintMode = "android:tintMode"
    case autoMirrored = "android:autoMirrored"
    case alpha = "android:alpha"
       
}

/// Elements of the <path> element of a VectorDrawable document
enum PathProperty: String {
    
    case name = "android:name"
    case pathData = "android:pathData"
    case fillColor = "android:fillColor"
    case strokeColor = "android:strokeColor"
    case strokeWidth = "android:strokeWidth"
    case strokeAlpha = "android:strokeAlpha"
    case fillAlpha = "android:fillAlpha"
    case trimPathStart = "android:trimPathStart"
    case trimPathEnd = "android:trimPathEnd"
    case trimPathOffset = "android:trimPathOffset"
    case strokeLineCap = "android:strokeLineCap"
    case strokeLineJoin = "android:strokeLineJoin"
    case strokeMiterLimit = "android:strokeMiterLimit"
    case fillType = "android:fillType"
    
}

/// Elements of the <group> element of a VectorDrawable document
enum GroupProperty: String {
    
    case name = "android:name"
    case rotation = "android:rotation"
    case pivotX = "android:pivotX"
    case pivotY = "android:pivotY"
    case scaleX = "android:scaleX"
    case scaleY = "android:scaleY"
    case translateX = "android:translateX"
    case translateY = "android:translateY"
    
}

enum Color {
    
    case theme(name: String)
    case hex(value: String)
    case resource(named: String)
    case hardCoded(UIColor)
    
    init?(_ string: String) {
        // TODO
        print("returning bogus hard coded color")
        self = .hardCoded(.black)
    }
    
    var asUIColor: UIColor {
        switch self {
        case .hardCoded(let color):
            return color
        default:
            fatalError()
        }
    }
    
    static let clear: Color = .hardCoded(.clear)
}

enum LineCap: String {
    
    case butt
    case round
    case square
    
    var intoCoreAnimation: String {
        switch self {
        case .butt: return kCALineCapButt
        case .round: return kCALineCapRound
        case .square: return kCALineCapSquare
        }
    }
    
}

enum LineJoin: String {
    
    case miter
    case round
    case bevel
    
    var intoCoreAnimation: String {
        switch self {
        case .bevel: return kCALineJoinBevel
        case .round: return kCALineJoinRound
        case .miter: return kCALineJoinMiter
        }
    }
}
