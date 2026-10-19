### Testing

Tests should be provided for all new contributions.  All tests are run upon creating of a pull request.  Tests can be run locally via Xcode or on the command line:

```
swift test
```

**NOTE**: Some 3rd party APIs are rate-limited, so some tests might fail if the rate-limit is exceeded.

### Changelog

Every pull request that changes what a consumer sees adds its entry to [CHANGELOG.md](CHANGELOG.md), in the section that fits (Added, Changed, Removed, Fixed), with **Breaking:** first on any change that needs a consumer to edit code or migrate stored values.

The entry goes under the version the pull request will be released as, with its date, so the release is tagged on that pull request's own merge commit and needs no second pull request. **Unreleased** holds only what is merged and not yet given a version. The GitHub release notes repeat the version's section.

### Coding Style

This project uses [SwiftFormat]() and [Swiftlint]() to enforce formatting and coding style.