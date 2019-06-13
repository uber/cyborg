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

import UIKit
import SwiftUI
import Cyborg
import Combine

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow()
//        window.rootViewController = UINavigationController(rootViewController: RootViewController(preferences: Preferences()))
        if #available(iOS 13.0, *) {
//            let binder = ThemeBinder()
            let view = VectorDrawableView(VectorDrawable.create(from:
                """
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:autoMirrored="true"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
  <path
      android:pathData="M16,14V6H1V14V14.03L17,20.22V17L9.24,14H16Z"
      android:fillColor="?iconPrimary"/>
  <path
      android:pathData="M22,4C19.79,4 18,5.79 18,8V12C18,14.21 19.79,16 22,16H23V4H22Z"
      android:fillColor="?iconPrimary"/>
</vector>
""".data(using: .utf8)!).unwrap())
            let host = UIHostingController(rootView: view
            .environment(\.vectorDrawableTheme, DefaultTheme()))
//            .environmentObject(binder))
            window.rootViewController = host
            DispatchQueue.main.async {
                host.rootView = view.environment(\.vectorDrawableTheme, DefaultTheme.init(color: .orange))
                }
//                binder.theme = DefaultTheme.init(color: .orange)
        } else {
            // Fallback on earlier versions
        }
        window.makeKeyAndVisible()
        self.window = window
        return true
    }

}


extension Result {
    func unwrap() -> Wrapped {
        switch self {
        case .ok(let wrapped): return wrapped
        default: fatalError()
        }
    }
}

struct DefaultTheme: ThemeProviding {
    
    var color: UIColor
    
    init(color: UIColor = .red) {
        self.color = color
    }
    
    func colorFromTheme(named name: String) -> UIColor {
        return color
    }
}

struct DefaultResources: ResourceProviding {
    func colorFromResources(named name: String) -> UIColor {
        return .red
    }
}
