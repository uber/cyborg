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

public final class VectorDrawable {
    
    public let baseWidth: CGFloat
    public let baseHeight: CGFloat
    public let viewPortWidth: CGFloat
    public let viewPortHeight: CGFloat
    public let baseAlpha: CGFloat
    let commands: [PathSegment]
    
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
         commands: [PathSegment]) {
        self.baseWidth = baseWidth
        self.baseHeight = baseHeight
        self.viewPortWidth = viewPortWidth
        self.viewPortHeight = viewPortHeight
        self.baseAlpha = baseAlpha
        self.commands = commands
    }
    
    func createPath() -> CGPath {
        let path = CGMutablePath()
        var lastPoint: CGPoint = .zero
        for command in commands {
            lastPoint = command(lastPoint, path)
        }
        return path
    }
    
}
