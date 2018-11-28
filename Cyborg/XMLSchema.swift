//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

import Foundation

/// Elements of a VectorDrawable document.
enum Element: String {
    case vector
    case path
    case group
    case clipPath = "clip-path"
}

/// Elements of the <vector> element of a VectorDrawable document.
enum VectorProperty: String {
    case schema = "xmlns:android"
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
            let hasAlpha = string.count == 9
            let startingShift = hasAlpha ? 8 : 0
            // munge the string into a form that Init.init(_:, radix:) can understand
            var withoutLeadingHashTag = String(withoutCopying: string)
            _ = withoutLeadingHashTag.remove(at: withoutLeadingHashTag.startIndex)
            if withoutLeadingHashTag.count == 3 {
                // convert from shorthand hexadecimal form, which doesn't work with the init
                withoutLeadingHashTag.append(withoutLeadingHashTag)
            }
            if let value = Int(withoutLeadingHashTag, radix: 16) {
                func component(_ mask: Int, _ shift: Int) -> CGFloat {
                    return CGFloat((value & mask) >> shift) / 255
                }
                let alpha = hasAlpha ? component(0xFF000000, 16) : 1.0
                self = .hex(value: UIColor(red: component(0xFF0000, 16 + startingShift),
                                           green: component(0xFF00, 8 + startingShift),
                                           blue: component(0xFF, 0 + startingShift),
                                           alpha: alpha))
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
