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

@testable import Cyborg
import XCTest

class XMLSchemaTests: XCTestCase {
    
    func test_parse_empty_vector() {
        let drawable = VectorDrawable
            .create(from: """
            <?xml version="1.0" encoding="utf-8"?>
            <vector xmlns:android="http://schemas.android.com/apk/res/android"
            android:width="24dp"
            android:height="25dp"
            android:viewportWidth="56"
            android:viewportHeight="100">
            </vector>
            """)
            .expectSuccess()
        XCTAssertEqual(drawable.viewPortWidth, 56)
        XCTAssertEqual(drawable.viewPortHeight, 100)
        XCTAssertEqual(drawable.baseWidth, 24)
        XCTAssertEqual(drawable.baseHeight, 25)
    }
    
    func test_fail_to_parse_two_vector_elements() {
        let result = VectorDrawable
            .create(from: """
            <?xml version="1.0" encoding="utf-8"?>
            <vector xmlns:android="http://schemas.android.com/apk/res/android"
            android:width="24dp"
            android:height="25dp"
            android:viewportWidth="56"
            android:viewportHeight="100">
            </vector>
            <vector xmlns:android="http://schemas.android.com/apk/res/android"
            android:width="24dp"
            android:height="25dp"
            android:viewportWidth="56"
            android:viewportHeight="100">
            </vector>
            """)
        switch result {
        case .error: break // TODO: test that the error message is as we expect
        case .ok(let wrapped): XCTFail("\(wrapped)")
        }
    }
    
    func test_nested_groups() {
        let layerName = "PathLayer"
        let drawable = VectorDrawable
            .create(from: """
                <?xml version="1.0" encoding="utf-8"?>
                <vector xmlns:android="http://schemas.android.com/apk/res/android"
                android:width="24dp"
                android:height="24dp"
                android:viewportWidth="24"
                android:viewportHeight="24">
                
                <group
                android:translateX="10"
                android:translateY="10">
                
                <group
                android:translateX="-11"
                android:translateY="-11">
                <path
                android:name="\(layerName)"
                android:pathData="M 1,1 C 1,2 3,3, 4,5z" />
                </group>
                
                </group>
                </vector>
                """).expectSuccess()
        XCTAssert(drawable
            .hierarchyMatches([
                .group([
                    .group([
                        .path,
                        ]),
                    ]),
                ]))
        let externalValues = ExternalValues(resources: NoTheme(),
                                            theme: NoTheme())
        let layers = drawable.layerRepresentation(in: .boundsRect(24, 24),
                                                  using: externalValues,
                                                  tint: (.src, .clear))
        let pathLayer = layers[0].layerInHierarchy(named: layerName) as! ShapeLayer<VectorDrawable.Path>
        pathLayer.bounds = drawable.intrinsicSize.intoBounds()
        pathLayer.layoutIfNeeded()
        let expected = CGMutablePath()
        expected.move(to: .init(x: 0, y: 0))
        expected.addCurve(to: .init(x: 3, y: 4),
                          control1: .init(x: 0, y: 1),
                          control2: .init(x: 2, y: 2))
        expected.closeSubpath()
        XCTAssertEqual(expected.copy()!, pathLayer.path!)
    }
    
    func test_two_nested_groups() {
        let drawable = VectorDrawable
            .create(from: """
                <?xml version="1.0" encoding="utf-8"?>
                <vector xmlns:android="http://schemas.android.com/apk/res/android"
                        android:viewportWidth="24"
                        android:viewportHeight="24"
                        android:width="24dp"
                        android:height="24dp">
                  <group
                      android:translateX="-3589"
                      android:translateY="-2800">
                    <group
                        android:translateX="3596"
                        android:translateY="2801">
                      <path
                          android:pathData="M0 0l0 3 13 0 0 13 3 0L16 0 0 0Z"
                          android:fillColor="?iconPrimary" />
                    </group>
                    <group
                        android:translateX="3590"
                        android:translateY="2806">
                      <path
                          android:pathData="M0 17L17 17 17 0 0 0 0 17ZM3 3L14 3 14 10 11.5 7.5 9.7 9.3 6.5 6 3 9.5 3 3Z"
                          android:fillColor="?iconPrimary" />
                    </group>
                  </group>
                </vector>
                """).expectSuccess()
        XCTAssert(drawable
            .hierarchyMatches([
                .group([
                    .group([
                        .path,
                        ]),
                    .group([.path])
                    ]),
                ]))
    }
}
