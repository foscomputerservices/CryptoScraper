### Testing

Tests should be provided for all new contributions.  All tests are run upon creating of a pull request.  Tests can be run locally via Xcode or on the command line:

```
swift test
```

**NOTE**: Some 3rd party APIs are rate-limited, so some tests might fail if the rate-limit is exceeded.

### Changelog

Every pull request that changes what a consumer sees adds its entry to [CHANGELOG.md](CHANGELOG.md) under **Unreleased**, in the section that fits (Added, Changed, Removed, Fixed), with **Breaking:** first on any change that needs a consumer to edit code.

At release, **Unreleased** becomes the version and its date, and the GitHub release notes repeat that section.

### Coding Style

This project uses [SwiftFormat]() and [Swiftlint]() to enforce formatting and coding style.