//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

@testable import Cyborg
import XCTest

class NoTheme: ValueProviding {

    func colorFromResources(named _: String) -> UIColor {
        return .black
    }

    func colorFromTheme(named _: String) -> UIColor {
        return .black
    }
}

extension CGPoint {

    init(_ xy: (CGFloat, CGFloat)) {
        self.init(x: xy.0, y: xy.1)
    }

}

extension CGSize {

    static let identity = CGSize(width: 1, height: 1)

}

func createPath(from pathSegment: PathSegment,
                start: PriorContext = .zero,
                path: CGMutablePath = CGMutablePath()) -> CGMutablePath {
    var priorContext: PriorContext = start
    for segment in pathSegment {
        priorContext = segment.apply(to: path, using: priorContext, in: .identity)
    }
    return path
}

extension String {

    func withXMLString(_ function: (XMLString) -> ()) {
        let (string, buffer) = XMLString.create(from: self)
        defer {
            buffer.deallocate()
        }
        function(string)
    }

}

extension XMLString {

    static func create(from string: String) -> (XMLString, UnsafeMutablePointer<UInt8>) {
        return string.withCString { pointer in
            pointer.withMemoryRebound(to: UInt8.self,
                                      capacity: string.utf8.count + 1, { pointer in
                                          let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: string.count + 1)
                                          for i in 0..<string.utf8.count + 1 {
                                              buffer.advanced(by: i).pointee = pointer.advanced(by: i).pointee
                                          }
                                          return (XMLString(buffer, count: Int32(string.utf8.count)), buffer)
            })
        }
    }

}

extension ParseResult {

    var asOptional: (Wrapped, Int32)? {
        switch self {
        case .ok(let wrapped): return wrapped
        case .error: return nil
        }
    }

}

extension Result {

    func expectSuccess() -> Wrapped {
        switch self {
        case .ok(let wrapped): return wrapped
        case .error(let error): fatalError(error)
        }
    }

    func expectFailure() -> ParseError {
        switch self {
        case .ok(let wrapped): fatalError("\(wrapped)")
        case .error(let error): return error
        }
    }

}

extension VectorDrawable {

    static func create(from string: String) -> Result<VectorDrawable> {
        return create(from: string.data(using: .utf8)!)
    }

}

extension CALayer {

    func layerInHierarchy(named name: String) -> CALayer? {
        if self.name == name {
            return self
        }
        for layer in sublayers ?? [] {
            if layer.name == name {
                return layer
            } else if let sublayer = layer.layerInHierarchy(named: name) {
                return sublayer
            }
        }
        return nil
    }

}

extension CGSize {

    func intoBounds() -> CGRect {
        return CGRect(origin: .zero, size: self)
    }

}

extension CGRect {

    static func boundsRect(_ width: CGFloat, _ height: CGFloat) -> CGRect {
        return .init(origin: .zero, size: .init(width: width, height: height))
    }

}

enum ElementType {

    case clipPath
    case path
    case group([ElementType])

    var asType: AnyClass {
        switch self {
        case .clipPath: return VectorDrawable.ClipPath.self
        case .path: return VectorDrawable.Path.self
        case .group: return VectorDrawable.Group.self
        }
    }

    var children: [ElementType] {
        if case .group(let children) = self {
            return children
        } else {
            return []
        }
    }

}

protocol DrawableHierarchyProviding: AnyObject {

    var hierarchy: [GroupChild] { get }

}

extension DrawableHierarchyProviding {

    func hierarchyMatches(_ expectedHierarchy: [ElementType]) -> Bool {
        if hierarchy.count != expectedHierarchy.count {
            return false
        }
        for (child, elementType) in zip(hierarchy, expectedHierarchy) {
            if type(of: child) == elementType.asType {
                if let child = child as? DrawableHierarchyProviding,
                    !child.hierarchyMatches(elementType.children) {
                    return false
                }
            } else {
                return false
            }
        }
        return true
    }

}

extension VectorDrawable: DrawableHierarchyProviding {

    var hierarchy: [GroupChild] {
        return groups
    }

}

extension VectorDrawable.Group: DrawableHierarchyProviding {

    var hierarchy: [GroupChild] {
        return children
    }

}
