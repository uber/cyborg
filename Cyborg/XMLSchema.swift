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
    case vectorShape = "vector"
    case shapePath = "path"
}

/// Elements of the <vector> element of a VectorDrawable document.
enum VectorProperty: String {
    
    case height = "android:height"
    case width = "android:width"
    case viewPortHeight = "android:viewportHeight"
    case viewPortWidth = "android:viewportWidth"
    
    var parserAttribute: ReferenceWritableKeyPath<DrawableParser, CGFloat?> {
        switch self {
        case .height: return \.baseHeight
        case .width: return \.baseWidth
        case .viewPortWidth: return \.viewPortWidth
        case .viewPortHeight: return \.viewPortHeight
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
