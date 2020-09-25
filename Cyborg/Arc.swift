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

import CoreGraphics

struct EllipticArc {

    let center: CGPoint
    let radius: CGPoint
    let xAngle: CGFloat

    // These two equations come from http://www.spaceroots.org/documents/ellipse/elliptical-arc.pdf

    func point(for pseudoAngle: CGFloat) -> CGPoint {
        // 2.2.1 (3)
        .init(
            x: center.x + radius.x * cos(xAngle) * cos(pseudoAngle) - radius.y * sin(xAngle) * sin(pseudoAngle),
            y: center.y + radius.x * sin(xAngle) * cos(pseudoAngle) + radius.y * cos(xAngle) * sin(pseudoAngle)
        )
    }
    
    func derivative(for pseudoAngle: CGFloat) -> CGPoint {
        // 2.2.1 (4)
        .init(
            x: -radius.x * cos(xAngle) * sin(pseudoAngle) - radius.y * sin(xAngle) * cos(pseudoAngle),
            y: -radius.x * sin(xAngle) * sin(pseudoAngle) + radius.y * cos(xAngle) * cos(pseudoAngle)
        )
    }
}

func applyArc(to path: CGMutablePath,
              in size: CGSize,
              radius: CGPoint,
              rotation: CGFloat,
              largeArcFlag: CGFloat,
              sweepFlag: CGFloat,
              endPoint: CGPoint,
              prior: PriorContext,
              isRelative: Bool) -> PriorContext {
    // see https://www.w3.org/TR/SVG/implnote.html#ArcImplementationNotes for explanation of how this works,
    // and https://mortoray.com/2017/02/16/rendering-an-svg-elliptical-arc-as-bezier-curves/ for the adaptations
    // that make it work properly.
    let rotation = rotation * .pi / 180
    let prior = prior.point
    let endPoint = endPoint.times(size).add(isRelative ? prior : .zero)
    var r = radius.times(size)
    // eq 5.1
    let transform = Matrix2x2(m00: cos(rotation),
                              m01: -sin(rotation),
                              m10: sin(rotation),
                              m11: cos(rotation))
    let xy1 = transform.times(.init(x: (prior.x - endPoint.x) / 2,
                                    y: (prior.y - endPoint.y) / 2))
    // eq 5.2
    // correction
    let rxs = pow(r.x, 2)
    let rys = pow(r.y, 2)
    let x1ps = pow(xy1.x, 2)
    let y1ps = pow(xy1.y, 2)
    let cr = x1ps / rxs + y1ps / rys
    if cr > 1 {
        let s = sqrt(cr)
        r.x *= s
        r.y *= s
    }
    func paired(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        return pow(a, 2) * pow(b, 2)
    }
    let dq = paired(r.x, xy1.y) + paired(r.y, xy1.x)
    let c1 = CGPoint(x: (r.x * xy1.y) / r.y,
                     y: -(r.y * xy1.x) / r.x)
        .times(
            sqrt(
                max(0, (paired(r.x, r.y) - dq) / dq)
            )
        )
        .times(largeArcFlag != sweepFlag ? 1 : -1)
    // eq 5.3
    let transform2 = Matrix2x2(m00: cos(rotation),
                               m01: sin(rotation),
                               m10: -sin(rotation),
                               m11: cos(rotation))
    let center = transform2
        .times(c1)
        .add(.init(x: (prior.x + endPoint.x) / 2,
                   y: (prior.y + endPoint.y) / 2))
    // eq 5.4
    let intermediateAngle = CGPoint(x: (xy1.x - c1.x) / r.x,
                                    y: (xy1.y - c1.y) / r.y)
    let startAngle = CGPoint(x: 1, y: 0).angle(with: intermediateAngle)
    var delta = intermediateAngle.angle(with: .init(x: (-xy1.x - c1.x) / r.x,
                                                    y: (-xy1.y - c1.y) / r.y))
    if delta > 0,
        sweepFlag == 0 {
        delta -= .pi * 2
    } else if delta < 0,
        sweepFlag == 1 {
        delta += .pi * 2
    }
    let segments = Segments(start: startAngle,
                            delta: delta,
                            division: 6)
    let arc = EllipticArc(center: center, radius: r, xAngle: rotation)
    for (start, end) in segments {
        let startPoint = arc.point(for: start)
        // If our calculations disagree with the current point of the path, move to the point
        // we computed, unless the difference is too small to matter. Entering this branch
        //  will likely lead to artifactsin when the VectorDrawable is displayed.
        if !path.currentPoint.isWithinAPointOf(startPoint) {
            path.move(to: startPoint)
        }
        let alpha: CGFloat = {
            let denom = sqrt(
                (4 + 3 * tan(pow((end - start) / 2, 2)) - 1)
            ) - 1
            return sin(end - start) * denom / 3
        }()
        let endPoint = arc.point(for: end)
        let c1 = arc.derivative(for: start).times(alpha).add(startPoint)
        let c2 = endPoint.subtract(arc.derivative(for: end).times(alpha))
        path
            .addCurve(to: endPoint,
                      control1: c1,
                      control2: c2)
    }
    return endPoint.asPriorContext
}

fileprivate struct Segments: Sequence {

    typealias Element = (CGFloat, CGFloat)
    let start: CGFloat
    let delta: CGFloat
    let division: Int

    init(start: CGFloat, delta: CGFloat, division: Int) {
        self.start = start
        self.delta = delta
        self.division = division
    }

    func makeIterator() -> Segments.Iterator {
        Iterator(current: start,
                 currentIndex: 0,
                 delta: delta,
                 division: division)
    }

    struct Iterator: IteratorProtocol {

        typealias Element = (CGFloat, CGFloat)

        var current: CGFloat
        var currentIndex: Int = 0
        let delta: CGFloat
        let division: Int

        mutating func next() -> (CGFloat, CGFloat)? {
            let last = current
            if currentIndex < division {
                currentIndex += 1
                current += delta / CGFloat(division)
                return (last, current)
            } else {
                return nil
            }
        }

    }
}

struct Matrix2x2 {

    let m00: CGFloat
    let m01: CGFloat
    let m10: CGFloat
    let m11: CGFloat

    func times(_ vector: CGPoint) -> CGPoint {
        let x = m00 * vector.x + m10 * vector.y
        let y = m01 * vector.x + m11 * vector.y
        return CGPoint(x: x, y: y)
    }
}
