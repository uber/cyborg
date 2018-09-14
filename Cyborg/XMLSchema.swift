//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

import Foundation

/// Elements of a VectorDrawable document.
enum Element: String {
    case vector = "vector"
    case path = "path"
    case group = "group"
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

enum Color {
    case theme(name: String)
    case hex(value: UIColor)
    case resource(named: String)
    case hardCoded(UIColor)

    init?(_ string: XMLString) {
        let string = String(string) // TODO: see if we can do this without allocating a string
        if string.hasPrefix("?") {
            self = .theme(name: String(string[string.index(after: string.startIndex)..<string.endIndex]))
        } else {
            // munge the string into a form that Init.init(_:, radix:) can understand
            var withoutLeadingHashTag = string
            _ = withoutLeadingHashTag.remove(at: withoutLeadingHashTag.startIndex)
            if withoutLeadingHashTag.count == 3 {
                // convert from shorthand hexadecimal form, which doesn't work with the init
                withoutLeadingHashTag.append(withoutLeadingHashTag)
            }
            if let value = Int(withoutLeadingHashTag, radix: 16) {
                func component(_ mask: Int, _ shift: Int) -> CGFloat {
                    return CGFloat((value & mask) >> shift) / 255
                }
                self = .hex(value: UIColor(red: component(0xFF0000, 16),
                                           green: component(0xFF00, 8),
                                           blue: component(0xFF, 0),
                                           alpha: 1.0))
            } else {
                print("returning bogus hard coded color")
                self = .hardCoded(.random)
            }
        }
    }

    func color(from theme: Theme) -> UIColor {
        switch self {
        case .hardCoded(let color):
            return color
        case .hex(let value):
            return value
        case .theme(let name):
            return theme.color(named: name)
        default:
            fatalError()
        }
    }

    static let clear: Color = .hardCoded(.clear)
}

extension UIColor {
    static var random: UIColor {
        let rand = {
            CGFloat(arc4random_uniform(256)) / 256
        }
        let r = rand(),
            g = rand(),
            b = rand()
        return UIColor(red: r, green: g, blue: b, alpha: 1)
    }
}

enum LineCap: String, XMLStringRepresentable {
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

enum LineJoin: String, XMLStringRepresentable {
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
