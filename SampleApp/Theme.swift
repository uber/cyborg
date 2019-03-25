//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

import Foundation
import Cyborg

final class Theme: ColorProvider, Cyborg.ThemeProviding {
    
    func colorFromTheme(named name: String) -> UIColor {
        return colorForKey(name)
    }
    
}

final class Resources: ColorProvider, ResourceProviding {
    
    func colorFromResources(named name: String) -> UIColor {
        return colorForKey(name)
    }
    
}


class ColorProvider: Codable {
    
    private(set) var colors: [NamedColor] = []
    var mappedColors: [String: NamedColor] = [:] {
        didSet {
            colors = mappedColors.map { $0.value }
        }
    }
    
    func removeColor(at index: Int) {
        mappedColors[colors[index].name] = nil
    }
    
    func colorForKey(_ key: String) -> UIColor {
        if let color = mappedColors[key] {
            return UIColor(rgba: color.hex)
        } else {
            return .black
        }
    }
    
}

struct NamedColor: Codable {
    var name: String
    var hex: Int64
}

extension UIColor {
    
    convenience init(rgba value: Int64) {
        let alpha = CGFloat(value >> 24 & 0xff) / 255.0
        let red = CGFloat(value >> 16 & 0xff) / 255.0
        let green = CGFloat(value >> 8 & 0xff) / 255.0
        let blue = CGFloat(value & 0xff) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    
}

class Preferences {
    
    enum Key: String {
        case theme
        case resources
    }
    
    let backing = UserDefaults()
    
    var theme: Theme {
        didSet {
            backing.save(object: theme, key: .theme)
        }
    }
    
    var resources: Resources {
        didSet {
            backing.save(object: resources, key: .resources)
        }
    }
    
    init() {
        theme = backing.object(for: .theme) ?? Theme()
        resources = backing.object(for: .resources) ?? Resources()
    }
}


extension UserDefaults {
    
    // TODO: bubble up errors
    
    func object<T: Codable>(for key: Preferences.Key) -> T? {
        let decoder = JSONDecoder()
        if let data = object(forKey: key.rawValue) as? Data,
            let object = try? decoder.decode(T.self, from: data){
            return object
        } else {
            return nil
        }
    }
    
    func save<T: Codable>(object: T, key: Preferences.Key) {
        let encoder = JSONEncoder()
        if let object = try? encoder.encode(object) {
            set(object, forKey: key.rawValue)
        } else {
            assertionFailure()
        }
    }
    
}
