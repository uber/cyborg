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

import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Elements of a VectorDrawable document.
enum Element: String {
    case vector
    case path
    case group
    case clipPath = "clip-path"
    case item
}

/// Elements of the <vector> element of a VectorDrawable document.
enum VectorProperty: String {
    case schema = "xmlns:android"
    case resourceSchema = "xmlns:aapt"
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

/// Elements of the <clip-path> element of a VectorDrawable document.
enum ClipPathProperty: String {

    case name = "android:name"
    case pathData = "android:pathData"
    case fillType = "android:fillType"
    case fillColor = "android:fillColor"
    case strokeColor = "android:strokeColor"

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

enum Color: Equatable {

    case theme(name: String)
    case hex(value: UIColor)
    case resource(named: String)

    init?(_ string: XMLString) {
        if string.count == 0 {
            return nil
        } else if string[safeIndex: 0] == .questionMark {
            if string.count > 1 {
                self = .theme(name: String(copying: string[1..<string.count]))
            } else {
                return nil
            }
        } else if string[safeIndex: 0] == .at {
            if string.count > 1 {
                self = .resource(named: String(copying: string[1..<string.count]))
            } else {
                return nil
            }
        } else {
            let hasAlpha = (string.count == 9)
            // munge the string into a form that Init.init(_:, radix:) can understand
            var withoutLeadingHashTag = String(withoutCopying: string)
            _ = withoutLeadingHashTag.remove(at: withoutLeadingHashTag.startIndex)
            if withoutLeadingHashTag.count == 3 {
                // convert from shorthand hexadecimal form, which doesn't work with the init
                withoutLeadingHashTag.append(withoutLeadingHashTag)
            }
            if let value = Int64(withoutLeadingHashTag, radix: 16) {
                func component(_ mask: Int64, _ shift: Int64) -> CGFloat {
                    return CGFloat((value & mask) >> shift) / 255
                }
                let alpha = hasAlpha ? component(0xFF000000, 24) : 1.0
                let color = UIColor(red: component(0xFF0000, 16),
                                    green: component(0xFF00, 8),
                                    blue: component(0xFF, 0),
                                    alpha: alpha)
                self = .hex(value: color)
            } else {
                return nil
            }
        }
    }

    func color(from externalValues: ExternalValues) -> UIColor {
        switch self {
        case .hex(let value):
            return value
        case .theme(let name):
            return externalValues.colorFromTheme(named: name)
        case .resource(named: let name):
            return externalValues.colorFromResources(named: name)
        }
    }

}

enum LineCap: String, XMLStringRepresentable {

    case butt
    case round
    case square

    var intoCoreAnimation: CAShapeLayerLineCap {
        switch self {
        case .butt: return .butt
        case .round: return .round
        case .square: return .square
        }
    }
}

enum LineJoin: String, XMLStringRepresentable {

    case miter
    case round
    case bevel

    var intoCoreAnimation: CAShapeLayerLineJoin {
        switch self {
        case .bevel: return .bevel
        case .round: return .round
        case .miter: return .miter
        }
    }
}

enum GradientProperty: String, XMLStringRepresentable {
    
    case startY = "android:startY"
    case startX = "android:startX"
    case endY = "android:endY"
    case endX = "android:endX"
    case type = "android:type"
    case startcolor = "android:startColor"
    case endColor = "android:endColor"
    case centerColor = "android:centerColor"
    case tileMode = "android:tileMode"
    case centerX = "android:centerX"
    case centerY = "android:centerY"
    case gradientRadius = "android:gradientRadius"
}

enum GradientType: String, XMLStringRepresentable {
    
    case linear
    case radial
    case sweep
    
}

enum ItemProperty: String, XMLStringRepresentable {
    case offset = "android:offset"
    case color = "android:color"
}

enum TileMode: String, XMLStringRepresentable {
    
    case clamp
    case `repeat`
    case mirror
    
}
