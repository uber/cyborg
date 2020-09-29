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

#if canImport(SwiftUI)

import SwiftUI

/// A `VectorDrawableView` for SwiftUI.
///
/// # Experimental
/// This feature is experimental and may change.
/// Current areas where this API may be deficient are:
///
/// 1. The drawable must be fully parsed before the view's init is called, which isn't in the spirit of SwiftUI's views being
/// cheap to construct.
///
/// 2. Handling of resources is a bit hacky. See below for details.
///
/// 3. Further testing of how the view handles sizing is required.
///
/// # Usage
///
/// You initialize a `VectorDrawableView` with
/// `init(_ drawable:)`.
///
/// You can provide the `theme` and `resources` through
/// `environment()`. It seems as though `theme` is better suited to be an `EnvironmentObject` than
/// merely part of the `Environment`, but there doesn't seem to be any way to access an `EnvironmentObject` inside of
/// `updateUIView` without crashing. If you want dynamic theme changes, the easiest way currently is to bind an `EnvironmentObject`
/// higher in your view hierarchy, then use its output to mutate the `Environment` by calling `View.environment` on the child
/// tree that contains the drawables you want to theme.
///
/// - Note: `resources` does not update after the view is first created,
/// it's passed as an `Environment` var solely for convenience.
@available(iOS 13.0, OSX 10.15, tvOS 13.0, *)
public struct VectorDrawableView {
    
    public let drawable: VectorDrawable
    
    /// Initializer.
    public init(_ drawable: VectorDrawable) {
        self.drawable = drawable
    }
}

#if os(macOS)
@available(OSX 10.15, *)
extension VectorDrawableView: NSViewRepresentable {
    public typealias NSViewType = VectorView
    
    public func makeNSView(context: NSViewRepresentableContext<VectorDrawableView>) -> VectorView {
        let view = VectorView(theme: context.environment.vectorDrawableTheme,
                              resources: context.environment.vectorDrawableResources)
        view.setContentHuggingPriority(.defaultHigh,
                                       for: .horizontal)
        view.setContentHuggingPriority(.defaultHigh,
                                       for: .vertical)
        view.drawable = drawable
        return view
    }
    
    public func updateNSView(_ uiView: VectorView,
                             context: NSViewRepresentableContext<VectorDrawableView>) {
        uiView.drawable = drawable
        uiView.theme = context.environment.vectorDrawableTheme
    }
}
#else
@available(iOS 13.0, tvOS 13.0, *)
extension VectorDrawableView: UIViewRepresentable {
    public func makeUIView(context: UIViewRepresentableContext<VectorDrawableView>) -> VectorView {
        let view = VectorView(theme: context.environment.vectorDrawableTheme,
                              resources: context.environment.vectorDrawableResources)
        view.setContentHuggingPriority(.defaultHigh,
                                       for: .horizontal)
        view.setContentHuggingPriority(.defaultHigh,
                                       for: .vertical)
        view.drawable = drawable
        return view
    }
    
    public func updateUIView(_ uiView: VectorView,
                             context: UIViewRepresentableContext<VectorDrawableView>) {
        uiView.drawable = drawable
        uiView.theme = context.environment.vectorDrawableTheme
    }
}
#endif

/// The key for Vector Drawable themes.
public struct ThemeKey: EnvironmentKey {
    
    public static let defaultValue: ThemeProviding = {
        struct DefaultTheme: ThemeProviding {
            func colorFromTheme(named name: String) -> UIColor {
                return .black
            }
        }
        return DefaultTheme()
    }()
    
    public typealias Value = ThemeProviding
    
}

/// The key for Vector Drawable resources.
public struct ResourceKey: EnvironmentKey {
    
    public static let defaultValue: ResourceProviding = {
        struct DefaultResources: ResourceProviding {
            func colorFromResources(named name: String) -> UIColor {
                return .black
            }
        }
        return DefaultResources()
    }()
    
    
    public typealias Value = ResourceProviding
    
}

@available(iOS 13.0, OSX 10.15, tvOS 13.0, *)
public extension EnvironmentValues {
    
    /// The theme to use for `VectorDrawables`.
    var vectorDrawableTheme: ThemeProviding {
        get {
            return self[ThemeKey.self]
        }
        set {
            self[ThemeKey.self] = newValue
        }
    }
    
    /// The Resources to use for `VectorDrawables`.
    ///
    /// Use `ResourceKey.defaultValue` to set the value for this
    /// before using it in `environment()`, as this will probably be accessed
    /// before `makeUIView` is called.
    var vectorDrawableResources: ResourceProviding {
        get {
            return self[ResourceKey.self]
        }
        set {
            self[ResourceKey.self] = newValue
        }
    }
    
    
}

#endif

