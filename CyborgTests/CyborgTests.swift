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
            .create(from: data) { result in
                callbackIsCalled.fulfill()
                switch result {
                case .ok(let drawable):
                    XCTAssert(drawable.viewPortWidth == 600)
                    XCTAssert(drawable.viewPortHeight == 600)
                    XCTAssert(drawable.commands.count != 0)
                case .error(let error):
                    XCTFail(error)
                }
        }
        wait(for: [callbackIsCalled], timeout: 0.001) // note: this is actually synchronous, but just in case it 
    }
    
    func test_move() {
        let move = "M300,70"
        let result = parseMoveAbsolute()(move, move.startIndex)
        let path = CGMutablePath()
        let expected = CGMutablePath()
        let movement = CGPoint(x: 300, y: 70)
        expected.move(to: movement)
        switch result {
        case .ok(let pathSegment, _):
            let next = pathSegment(.zero, path)
            XCTAssertEqual(path, expected)
            XCTAssertEqual(next, movement)
        case .error(let error):
            XCTFail(error)
        }
    }
    
    func test_closePath() {
        let close = "   z"
        let result = parseClosePath()(close, close.startIndex)
        let expected = CGMutablePath()
        expected.closeSubpath()
        switch result {
        case .ok(let wrapped, let index):
            let path = CGMutablePath()
            _ = wrapped(.zero, path)
            XCTAssertEqual(index, close.endIndex)
            XCTAssertEqual(path, expected)
        case .error(let error):
            XCTFail(error)
        }
    }
    
    func test_oneorMoreOf() {
        let str = "a"
        let contents = "aaa"
        XCTAssertEqual(oneOrMore(of: literal(str))(contents, contents.startIndex).asOptional?.0,
                       Array(repeating: str, count: 3))
        let contents2 = "   a a   a"
        XCTAssertEqual(oneOrMore(of: consumeTrivia(before: literal(str)))(contents2, contents2.startIndex).asOptional?.0,
                       Array(repeating: str, count: 3))
    }
    
    func test_int_parser() {
        let str = "-432"
        switch Cyborg.int()(str, str.startIndex) {
        case .ok(let result, _):  XCTAssertEqual(result, -432)
        case .error(let error): XCTFail(error)
        }
        let str2 = "40"
        switch Cyborg.int()(str2, str2.startIndex) {
        case .ok(let result, _):  XCTAssertEqual(result, 40)
        case .error(let error): XCTFail(error)
        }
    }
    
}
