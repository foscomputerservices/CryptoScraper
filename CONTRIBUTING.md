### Testing

Tests should be provided for all new contributions.  All tests are run upon creating of a pull request.  Tests can be run locally via Xcode or on the command line:

```
swift test
```

**NOTE**: Some 3rd party APIs are rate-limited, so some tests might fail if the rate-limit is exceeded.

### Coding Style

This project uses [SwiftFormat]() and [Swiftlint]() to enforce formatting and coding style.