import UIKit

enum AndroidUnitOfMeasure: String {
    case px
    case inch = "in"
    case mm
    case pt
    case dp
    case sp
    
    func convertToPoints(from value: Int) -> CGFloat {
        let floatValue = CGFloat(value)
        // TODO
        return floatValue
    }
    
    static var all: [AndroidUnitOfMeasure] = [
        .dp,
        .px,
        .pt,
        .inch,
        .mm,
        .pt,
        .sp,
        ]
    
}

enum BlendMode: String {
    case add
    case clear
    case darken
    case dst
    case dstAtop
    case dstIn
    case dstOut
    case dstOver
    case lighten
    case multiply
    case overlay
    case screen
    case src
    case srcAtop
    case srcIn
    case srcOut
    case srcOver
    case xor
}

public final class VectorDrawable {
    
    public let baseWidth: CGFloat
    public let baseHeight: CGFloat
    public let viewPortWidth: CGFloat
    public let viewPortHeight: CGFloat
    public let baseAlpha: CGFloat
    let groups: [Group]
    
    public static func create(from data: Data,
                              whenComplete run: @escaping (Result) -> ()) {
        DrawableParser(data: data, onCompletion: run)
            .start()
    }
    
    init(baseWidth: CGFloat,
         baseHeight: CGFloat,
         viewPortWidth: CGFloat,
         viewPortHeight: CGFloat,
         baseAlpha: CGFloat,
         groups: [Group]) {
        self.baseWidth = baseWidth
        self.baseHeight = baseHeight
        self.viewPortWidth = viewPortWidth
        self.viewPortHeight = viewPortHeight
        self.baseAlpha = baseAlpha
        self.groups = groups
    }
    
    func createPaths(in size: CGSize) -> [CGPath] {
        return groups.map { (group) in
            group.createPath(in: size)
        }
    }
    
    public class Group {
        
        public let name: String
        public let transform: Transform
        let path: Path
        
        init(name: String,
             transform: Transform,
             path: Path) {
            self.name = name
            self.transform = transform
            self.path = path
        }
                
        func createPath(in size: CGSize) -> CGPath {
            return path.createPath(in: size)
        }
        
    }
    
    public class Path {
        
        public let name: String
        let fillColor: Color
        let data: [PathSegment]
        let strokeColor: Color
        let strokeWidth: CGFloat
        let strokeAlpha: CGFloat
        let fillAlpha: CGFloat
        let trimPathStart: CGFloat
        let trimPathEnd: CGFloat
        let trimPathOffset: CGFloat
        let strokeLineCap: LineCap
        let strokeLineJoin: LineJoin
        let fillType: CGPathFillRule
        
        init(name: String,
             fillColor: Color,
             fillAlpha: CGFloat,
             data: [PathSegment],
             strokeColor: Color,
             strokeWidth: CGFloat,
             strokeAlpha: CGFloat,
             trimPathStart: CGFloat,
             trimPathEnd: CGFloat,
             trimPathOffset: CGFloat,
             strokeLineCap: LineCap,
             strokeLineJoin: LineJoin,
             fillType: CGPathFillRule) {
            self.name = name
            self.data = data
            self.strokeColor = strokeColor
            self.strokeAlpha = strokeAlpha
            self.fillColor = fillColor
            self.fillAlpha = fillAlpha
            self.trimPathStart = trimPathStart
            self.trimPathEnd = trimPathEnd
            self.trimPathOffset = trimPathOffset
            self.strokeLineCap = strokeLineCap
            self.strokeLineJoin = strokeLineJoin
            self.fillType = fillType
            self.strokeWidth = strokeWidth
        }
        
        func createPath(in size: CGSize) -> CGPath {
            let path = CGMutablePath()
            var lastPoint: CGPoint = .zero
            for command in data {
                lastPoint = command(lastPoint, path, size)
            }
            return path // TODO: apply transform
        }
        
        func apply(to layer: CAShapeLayer) {
            layer.strokeColor = strokeColor.asUIColor.withAlphaComponent(strokeAlpha).cgColor
            layer.strokeStart = trimPathStart + trimPathOffset
            layer.strokeEnd = trimPathEnd + trimPathOffset
            layer.fillColor = fillColor.asUIColor.withAlphaComponent(fillAlpha).cgColor
            layer.lineCap = strokeLineCap.intoCoreAnimation
            layer.lineJoin = strokeLineJoin.intoCoreAnimation
        }
    }
    
}

public struct Transform {
    
    public let pivot: CGPoint
    public let rotation: CGFloat
    public let scale: CGPoint
    public let translation: CGPoint
    
    static let identity: Transform = .init(pivot: .zero,
                                           rotation: 0,
                                           scale: CGPoint(x: 1, y: 1),
                                           translation: .zero)
    
    func affineTransform(in size: CGSize) -> CGAffineTransform {
        let translation = self.translation.times(size.width, size.height)
        let pivot = self.translation.times(size.width, size.height)
        let inversePivot = pivot.times(-1, -1)
        return CGAffineTransform(scaleX: scale.x, y: scale.y)
            .translatedBy(x: inversePivot.x, y: inversePivot.y)
            .rotated(by: rotation)
            .translatedBy(x: pivot.x, y: pivot.y)
            .translatedBy(x: translation.x, y: translation.y)
    }
    
}
