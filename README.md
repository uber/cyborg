# Cyborg

Cyborg is intended to be a port of Android's [VectorDrawable](https://developer.android.com/reference/android/graphics/drawable/VectorDrawable#canApplyTheme()) to iOS. Goals for Cyborg include:

- competitive performance with icon font implementations
- performant enough to be used as a drop-in replacement for `UIImage` where possible
- be more performant than existing SVG parser/display libraries
- support the full set of features supported by Android Vector Drawable so designers can be confident that their assets will be supported on both platforms
- support semi arbitrary theming systems and loading resources from a bundle