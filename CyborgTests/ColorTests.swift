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

class ColorTests: XCTestCase {

    func test_emptyString() {
        "".withXMLString { empty in
            XCTAssertEqual(Color(empty), nil)
        }
    }

    func test_theme_color() {
        let name = "abc"
        let themeColor = "?\(name)"
        themeColor.withXMLString { themeColor in
            if let color = Color(themeColor) {
                if case .theme(let color) = color {
                    XCTAssertEqual(color, name)
                }
            } else {
                XCTFail()
            }
        }
    }

    func test_theme_color_shouldFail() {
        let themeColor = "?"
        themeColor.withXMLString { themeColor in
            let none: Color? = nil
            let color: Color? = Color(themeColor)
            XCTAssertEqual(color, none)
        }
    }

    func test_resources_color() {
        let name = "abc"
        let themeColor = "@\(name)"
        themeColor.withXMLString { themeColor in
            if let color = Color(themeColor) {
                if case .theme(let color) = color {
                    XCTAssertEqual(color, name)
                }
            } else {
                XCTFail()
            }
        }
    }

    func test_resources_color_shouldFail() {
        let themeColor = "@"
        themeColor.withXMLString { themeColor in
            let none: Color? = nil
            let color: Color? = Color(themeColor)
            XCTAssertEqual(color, none)
        }
    }

    func test_hex_color_shouldFail() {
        let themeColor = "0x00"
        themeColor.withXMLString { themeColor in
            let none: Color? = nil
            let color: Color? = Color(themeColor)
            XCTAssertEqual(color, none)
        }
    }

    func test_hex_color() {
        let themeColor = "#FFFFFF"
        themeColor.withXMLString { themeColor in
            if let color = Color(themeColor) {
                if case .hex(let color) = color {
                    XCTAssertEqual(color, UIColor(red: 1, green: 1, blue: 1, alpha: 1))
                }
            } else {
                XCTFail()
            }
        }
    }

    func test_hex_color_shorthand() {
        let themeColor = "#FFF"
        themeColor.withXMLString { themeColor in
            if let color = Color(themeColor) {
                if case .hex(let color) = color {
                    XCTAssertEqual(color, UIColor(red: 1, green: 1, blue: 1, alpha: 1))
                }
            } else {
                XCTFail()
            }
        }
    }

}
