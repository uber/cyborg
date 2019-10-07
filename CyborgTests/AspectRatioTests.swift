//
//  Copyright (c) 2019. Uber Technologies
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
import CoreGraphics
import XCTest
@testable import Cyborg

class AspectRatioTests: XCTestCase {

    func test_scale_aspect_fit() {
        func assertTransformed(from: CGSize,
                               in container: CGSize,
                               to result: CGSize,
                               file: StaticString = #file,
                               line: UInt = #line) {
            XCTAssertEqual(from.scaleAspectFit(in: container),
                           result,
                           file: file,
                           line: line)
        }
        assertTransformed(from: .init(width: 10,
                                      height: 10),
                          in: .init(width: 100,
                                    height: 200),
                          to: .init(width: 100,
                                    height: 100))
        assertTransformed(from: .init(width: 1000,
                                      height: 1000),
                          in: .init(width: 100,
                                    height: 200),
                          to: .init(width: 100,
                                    height: 100))
        assertTransformed(from: .init(width: 1000,
                                      height: 10),
                          in: .init(width: 100,
                                    height: 200),
                          to: .init(width: 100,
                                    height: 1))
    }
    
    func test_scale_aspect_fill() {
        func assertTransformed(from: CGSize,
                               in container: CGSize,
                               to result: CGSize,
                               file: StaticString = #file,
                               line: UInt = #line) {
            XCTAssertEqual(from.scaleAspectFill(in: container),
                           result,
                           file: file,
                           line: line)
        }
        assertTransformed(from: .init(width: 10,
                                      height: 10),
                          in: .init(width: 100,
                                    height: 200),
                          to: .init(width: 200,
                                    height: 200))
        assertTransformed(from: .init(width: 1000,
                                      height: 1000),
                          in: .init(width: 100,
                                    height: 200),
                          to: .init(width: 200,
                                    height: 200))
        assertTransformed(from: .init(width: 1000,
                                      height: 10),
                          in: .init(width: 100,
                                    height: 200),
                          to: .init(width: 20000,
                                    height: 200))
    }

    
}
