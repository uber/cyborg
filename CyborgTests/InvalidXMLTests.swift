//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

import Foundation
import XCTest
import Cyborg
import libxml2

class InvalidXMLTests: XCTestCase {
 
    func test_no_close() {
        let data = """
<vector android:height="300dp" android:viewportHeight="300"
android:viewportWidth="300" android:width="300dp" xmlns:android="http://schemas.android.com/apk/res/android">
<path android:strokeColor="#fcd116" android:pathData="M10,250 l 50,-25
a25,25 -30 0,1 50,-25 l 50,-25
a25,50 -30 0,1 50,-25 l 50,-25
a25,75 -30 0,1 50,-25 l 50,-25
a25,100 -30 0,1 50,-25 l 50,-25 z"
</vector>
"""
        assertXMLError(data, "")
    }
    
    func test_empty_xml() {
        assertXMLError("", "Empty data passed.")
    }
    
}

func assertXMLError(_ xml: String,
                    _ error: String,
                    file: StaticString = #file,
                    line: UInt = #line) {
    switch VectorDrawable.create(from: xml.data(using: .utf8)!) {
    case .ok(let drawable): XCTFail("Successfully created vector drawable when a failure was expected: \(drawable)", file: file, line: line)
    case .error(let output): XCTAssertEqual(error, output, file: file, line: line)
    }
}

