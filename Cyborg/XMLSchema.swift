//
//  XMLSchema.swift
//  Cyborg
//
//  Created by Ben Pious on 7/26/18.
//  Copyright © 2018 Ben Pious. All rights reserved.
//

import Foundation

/// Elements of a VectorDrawable document.
enum ParentNode: String {
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
//    case tint = "android:tint"
//    case tintMode = "android:tintMode"
//    case autoMirrored = "android:autoMirrored"
//    case alpha = "android:alpha"
    
    var parserAttribute: ReferenceWritableKeyPath<DrawableParser, CGFloat?> {
        switch self {
        case .height: return \.baseHeight
        case .width: return \.baseWidth
        case .viewPortWidth: return \.viewPortWidth
        case .viewPortHeight: return \.viewPortHeight
//        case .alpha: return \.alpha
//        case .tintMode: return \.tintMode
        }
    }
    
    var parser: (String) -> ParseResult<Int> {
        switch self {
        case .height, .width: return parseAndroidMeasurement(from: )
        case .viewPortWidth, .viewPortHeight: return parseInt(from: )
        }
    }
}

enum DrawableProperty: String {
    case pathShiftX = "shift-x"
    case pathShiftY = "shift-y"
    case shapeGroup = "group"
    case pathID = "android:name"
    case pathDescription = "android:pathData" // TODO
}

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
    
    var asUIColor: UIColor {
        fatalError()
    }
}

enum LineCap {
    
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

enum LineJoin {
    
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
