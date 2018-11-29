//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

@testable import Cyborg
import Foundation
import XCTest

class GradientTests: XCTestCase {
    
    func test_parsing_linear_gradient() {
        let data = """
        <vector android:height="24dp" android:viewportHeight="240"
        android:viewportWidth="120" android:width="24dp"
        xmlns:aapt="http://schemas.android.com/aapt" xmlns:android="http://schemas.android.com/apk/res/android">
        <path android:fillColor="#FF000000" android:pathData="M25,10L95,10A15,15 0,0 1,110 25L110,95A15,15 0,0 1,95 110L25,110A15,15 0,0 1,10 95L10,25A15,15 0,0 1,25 10z"/>
        <path android:pathData="M25,120L95,120A15,15 0,0 1,110 135L110,205A15,15 0,0 1,95 220L25,220A15,15 0,0 1,10 205L10,135A15,15 0,0 1,25 120z">
        <aapt:attr name="android:fillColor">
            <gradient android:endX="10" android:endY="220"
                android:startX="10" android:startY="120" android:type="linear">
                <item android:color="#FFFF0000" android:offset="0"/>
                <item android:color="#00000000" android:offset="0.5"/>
                <item android:color="#FF0000FF" android:offset="1"/>
            </gradient>
        </aapt:attr>
        </path>
        </vector>
        """
            .data(using: .utf8)!
        switch VectorDrawable.create(from: data) {
        case .ok(let drawable):
            assertHierarchiesEqual(drawable, [.group([.path]), .group([.pathWithGradient(.gradient)])])
            let gradient = (((drawable.hierarchy[1] as! VectorDrawable.Group).children[0] as! VectorDrawable.Path).gradient as! VectorDrawable.LinearGradient)
            XCTAssertEqual(gradient.end, CGPoint((10 / drawable.viewPortWidth, 220 / drawable.viewPortHeight)))
            XCTAssertEqual(gradient.start, CGPoint((10 / drawable.viewPortWidth, 120 / drawable.viewPortHeight)))
            XCTAssertEqual(gradient.offsets,
                           [
                            VectorDrawable.Gradient.Offset(amount: 0, color: Color(string: "#FFFF0000")!),
                            VectorDrawable.Gradient.Offset(amount: 0.5, color: Color(string: "#00000000")!),
                            VectorDrawable.Gradient.Offset(amount: 1, color: Color(string: "#FF0000FF")!)
                ])
        case .error(let error):
            XCTFail(error)
        }
        
    }
    
}

extension Color {
    
    init?(string: String) {
        if let color = (string
            .withXMLString { (string) in
                Color(string)
        }) {
            self = color
        } else {
            return nil
        }
    }
    
}

extension VectorDrawable.Gradient.Offset: Equatable {
    
    public static func ==(lhs: VectorDrawable.Gradient.Offset,
                          rhs: VectorDrawable.Gradient.Offset) -> Bool {
        return lhs.amount == rhs.amount && lhs.color == rhs.color
    }
    
}
