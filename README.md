# Cyborg

Cyborg is a [partial](https://github.com/uber/cyborg/issues?q=is%3Aissue+is%3Aopen+label%3A%22Spec+Compliance%22) port of Android's [VectorDrawable](https://medium.com/androiddevelopers/understanding-androids-vector-image-format-vectordrawable-ab09e41d5c68) to iOS.
It is intended as a replacement for UIImages, Icon Fonts, and Apple's PDF vector image option. There are many benefits to using this format that are not provided by Images, Icon Fonts, PDFs, or SVG, including:

- Full theming support of individual elements of an illustration, beyond simple image tinting or changing the text color in an Icon Font
- Ability to use one asset for both platforms, simplifying the design -> engineering pipeline
- Assets are resolution independent
- RTL support
- Easily convertible from SVG using Android Studio or third-party tools

Cyborg's parser is faster than the iOS SVG libraries we could find, though it tends to be about 1.3X slower than a `UIImage`, and an icon font with ~50 icons can be loaded in the time that it takes to load around 2-3 drawables of similar complexity.

If parsing performance becomes an issue, you may wish to implement either a caching mechanism appropriate for your application, or take advantage of Cyborg's thread safety to perform parsing off the main thread.

With that said, many performance improvement opportunities [currently](https://github.com/uber/cyborg/issues?q=is%3Aissue+is%3Aopen+label%3APerformance) exist, so performance should improve in the future.
As of this writing, Swift is a young language, and performance improvements to it, particularly in String creation, closures, and ownership should also have a positive impact on Cyborg's performance.

The full list of features is enumerated in the [Android Documentation](https://developer.android.com/reference/android/graphics/drawable/VectorDrawable).

## Using Cyborg

After following the integration steps below, using Cyborg requires only slightly more code than using a `UIImage`:

```
let vectorView = VectorView(theme: myTheme)
vectorView.drawable = VectorDrawable.named("MyDrawable")
```

## Integration

Cyborg is made to scale up to complex uses cases, and as such require a bit of configuration to get the clean code sample above.

Let's see how to write the minimal integration to get started:

### Implementing Themes and Resources

One of the best features of VectorDrawables is the ability to swap in arbitrary values at runtime. Well authored VectorDrawable assets can change their colors in response to changes in app state, such as a night mode.

However, gaining access to these powerful features requires us to write our own Theme and Resource providers:

```
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

```

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

```
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

## Quality of Life Suggestions

### Lint VectorDrawable Assets

As you may already have noticed, the Theme and Resource objects you wrote in an earlier section are stringly typed. To prevent issues with assets that reference nonexistent theme or resource colors,
you may want to lint the xml files to ensure that they are valid.

### Store Your VectorDrawables in a Single Repo

You may find it convenient to allow designers to commit new assets directly to a repo that can be pulled into your Android and iOS repos by designers.

### Automatically Replace Color Literals with Theme Colors
