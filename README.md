# Cyborg

[![Build Status](https://travis-ci.com/uber/cyborg.svg?branch=master)](https://travis-ci.com/uber/cyborg)
[![CII Best Practices](https://bestpractices.coreinfrastructure.org/projects/2961/badge)](https://bestpractices.coreinfrastructure.org/projects/2961)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)


Cyborg is a [partial](https://github.com/uber/cyborg/issues?q=is%3Aissue+is%3Aopen+label%3A%22Spec+Compliance%22) port of Android's [VectorDrawable](https://medium.com/androiddevelopers/understanding-androids-vector-image-format-vectordrawable-ab09e41d5c68) to iOS.
It is intended as a replacement for UIImages, Icon Fonts, and Apple's PDF vector image option. The VectorDrawable format provides a number of advantages:

- Full theming support of individual elements of an illustration, beyond simple image tinting or changing the text color in an Icon Font
- Ability to use one asset for both platforms, simplifying the design -> engineering pipeline
- Assets are resolution independent
- RTL support
- Easily convertible from SVG using Android Studio or third-party tools

## Performance Comparisons

We benchmarked Cyborg against a number of alternatives, loading the 50+ icons contained in our Driver app's icon set.

- Cyborg's parser is faster than the iOS SVG libraries we could find
- It tends to be a tiny bit slower than `UIImage`. The differences should be in the fractions of milliseconds in practice
- An icon font with ~50 icons can be loaded in the time that it takes to load around 2-3 drawables of similar complexity.

If parsing performance becomes an issue, you may wish to implement either a caching mechanism appropriate for your application, or take advantage of Cyborg's thread safety to perform parsing off the main thread.

With that said, many performance improvement opportunities [currently](https://github.com/uber/cyborg/issues?q=is%3Aissue+is%3Aopen+label%3APerformance) exist, so performance should improve in the future.
As of this writing, Swift is a young language, and performance improvements to it, particularly in String creation, closures, and ownership should also have a positive impact on Cyborg's performance.

The full list of features is enumerated in the [Android Documentation](https://developer.android.com/reference/android/graphics/drawable/VectorDrawable).

## Installing Cyborg

1. Get [Carthage](https://github.com/Carthage/Carthage#quick-start).
2. Add the following to your CartFile: `github git@github.com:uber/cyborg.git ~> [desired version]`

## Using Cyborg

After following the integration steps below, using Cyborg requires only slightly more code than using a `UIImage`:

```swift
let vectorView = VectorView(theme: myTheme)
vectorView.drawable = VectorDrawable.named("MyDrawable")
```

## Integration

Cyborg is made to scale up to complex uses cases, and as such require a bit of configuration to get the clean code sample above.

Let's see how to write the minimal integration to get started:

### Implementing Themes and Resources

One of the best features of VectorDrawables is the ability to swap in arbitrary values at runtime. Well authored VectorDrawable assets can change their colors in response to changes in app state, such as a night mode.

However, gaining access to these powerful features requires us to write our own Theme and Resource providers:

```swift
class Theme: Cyborg.ThemeProviding {

    func colorFromTheme(named _: String) -> UIColor {
        return .black
    }

}

class Resources: ResourceProviding {

    func colorFromResources(named _: String) -> UIColor {
        return .black
    }

}

```

Assuming that resources never change, we can now write the convenience initializer depicted in the first code sample:

```swift
fileprivate let resources = Resources()

extension VectorDrawable {
    public convenience init(theme: Theme) {
        self.init(theme: theme, resources: resources()
    }
}

```

### Reporting Drawable Parse Errors:

If, for some reason, you provide an invalid VectorDrawable to Cyborg, the standard creation function in Cyborg will give you a detailed error message that you can report
as a nonfatal to the crash reporting service of your choice and use to debug locally. This can be handled at your app's "platform" level, allowing you to write code that assumes that
the parsing always succeeds, just like with UIImage:

```swift
extension VectorDrawable {
    public static func named(_ name: String) -> VectorDrawable? {
        return Bundle.main.url(forResource: name, withExtension: "xml").flatMap { url in
        switch VectorDrawable.create(from: url) {
            case .ok(let drawable):
                return drawable
            case .error(let error):
               myAssertionFailureThatAlsoReportsToBackend("Could not create a vectordrawable named \(name); the error was \(error)")
               return nil
        }
    }
}
```

## Best Practices

### Lint VectorDrawable Assets

As you may already have noticed, the Theme and Resource objects you wrote in an earlier section are [stringly typed](http://wiki.c2.com/?StringlyTyped). To prevent issues with assets that reference nonexistent theme or resource colors,
you may want to lint the xml files to ensure that they are valid.

### Store Your VectorDrawables in a Single Repo

You may find it convenient to allow designers to commit new assets directly to a repo that can be pulled into your Android and iOS repos by designers.

### Snapshot Test Your VectorDrawables

The easiest way to ensure correctness of your UIs that use static vector drawables is to snapshot test the UIs that use them using a tool like [iOSSnapshotTestCase](https://github.com/uber/ios-snapshot-test-case).
This will ensure that any code that isn't compiler-verified matches your expectations.
