//
//  CyborgTests.swift
//  CyborgTests
//
//  Created by Ben Pious on 7/25/18.
//  Copyright © 2018 Ben Pious. All rights reserved.
//

import XCTest
@testable import Cyborg

class CyborgTests: XCTestCase {
    
    let string = """
 <vector xmlns:android="http://schemas.android.com/apk/res/android"
     android:height="64dp"
     android:width="64dp"
     android:viewportHeight="600"
     android:viewportWidth="600" >
     <group
         android:name="rotationGroup"
         android:pivotX="300.0"
         android:pivotY="300.0"
         android:rotation="45.0" >
         <path
             android:name="v"
             android:fillColor="#000000"
             android:pathData="M300,70 l 0,-70 70,70 0,0 -70,70z" />
     </group>
 </vector>
"""
    
    override func setUp() {
        super.setUp()
        
    }
    
    override func tearDown() {
        
        super.tearDown()
    }
    
    func test_Deserialize() {
        let data = string.data(using: .utf8)!
        let callbackIsCalled = expectation(description: "Callback is called")
        VectorDrawable
            .create(from: data) { drawable in
                callbackIsCalled.fulfill()
                if let drawable = drawable {
                    XCTAssert(drawable.viewPortWidth == 600)
                    XCTAssert(drawable.viewPortHeight == 600)
                    XCTAssert(drawable.commands.count != 0)
                } else {
                    XCTFail()
                }
        }
        wait(for: [callbackIsCalled], timeout: 4.0)
    }
    
    func test_int_parser() {
        let str = "-432"
        if let result = Cyborg.int()(str, str.startIndex) {
            XCTAssertEqual(result.0, -432)
        } else {
            XCTFail()
        }
        let str2 = "40"
        if let result = Cyborg.int()(str2, str2.startIndex) {
            XCTAssertEqual(result.0, 40)
        } else {
            XCTFail()
        }
    }
    
}
