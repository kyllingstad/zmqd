# Changelog

This file documents all notable changes to zmqd.  This includes major
new features, important bug fixes and breaking changes.  For a more
detailed list of all changes, click the header links for each version.
This will take you to the relevant sections of the project's
[Git commit history](https://github.com/kyllingstad/zmqd).

Version numbers adhere to the [Semantic Versioning](https://semver.org/) scheme.

## [1.3.0] - 2022-08-06
### Added
  - More examples ([PR #29])
### Changed
  - `EINTR` signal now handled in the same way as `EAGAIN` ([PR #30])
### Fixed
  - Modern contracts syntax ([PR #28], [PR #31])
  - Warning about missing `return` annotation ([PR #32])

## [1.2.0] – 2020-02-20
### Added
  - Support for new event types from ZeroMQ 4.3, in the form of additions to
    `Event` and `EventType` as well as the new `ProtocolError` type.
### Changed
  - Dropped support for ZeroMQ versions older than 4.3.
### Fixed
  - Compatibility with DIP25 and DIP1000 ([issue #24]).

## [1.1.2] – 2019-09-30
### Fixed
  - Use `zmq_errno()` rather than plain `errno` to obtain error codes
    ([issue #22]).

## [1.1.1] – 2017-11-13
### Fixed
  - Got rid of some deprecation warnings ([issue #21]).

## [1.1.0] – 2016-05-17
### Added
  - Full support for ZeroMQ 4.1,
    including new functions (`Frame.metadata()`, `Context.terminate()`),
    context options (`socketLimit`, `ipv6`),
    frame options (`sharedStorage`, `sourceFD`) and
    a whole bunch of socket options ([issue #13]).
  - `steerableProxy()`, a wrapper for `zmq_proxy_steerable()`,
    introduced in ZeroMQ 4.0.5 ([issue #15]).
  - `infiniteDuration`, used to disable timeouts in some functions.
### Changed
  - `Frame.opCall()` now accepts a custom deleter ([issue #16]).
  - `Frame.opCall(ubyte[])` and `Frame.rebuild(ubyte[])` are now `@system`.
### Fixed
  - Got rid of deprecation warning about `std.c.windows.winsock`
    ([issue #19]).

## 1.0.0 – 2015-08-16
First stable release, with full support for ZeroMQ 4.0.


[1.1.0]: https://github.com/kyllingstad/zmqd/compare/v1.0.0...v1.1.0
[1.1.1]: https://github.com/kyllingstad/zmqd/compare/v1.1.0...v1.1.1
[1.1.2]: https://github.com/kyllingstad/zmqd/compare/v1.1.1...v1.1.2
[1.2.0]: https://github.com/kyllingstad/zmqd/compare/v1.1.2...v1.2.0
[1.3.0]: https://github.com/kyllingstad/zmqd/compare/v1.2.0...v1.3.0
[Unreleased]: https://github.com/kyllingstad/zmqd/compare/v1.1.2...master
[issue #13]: https://github.com/kyllingstad/zmqd/issues/13
[issue #15]: https://github.com/kyllingstad/zmqd/issues/15
[issue #16]: https://github.com/kyllingstad/zmqd/issues/16
[issue #19]: https://github.com/kyllingstad/zmqd/issues/19
[issue #21]: https://github.com/kyllingstad/zmqd/issues/21
[issue #22]: https://github.com/kyllingstad/zmqd/issues/22
[issue #24]: https://github.com/kyllingstad/zmqd/issues/24
[PR #28]: https://github.com/kyllingstad/zmqd/pull/28
[PR #29]: https://github.com/kyllingstad/zmqd/pull/29
[PR #30]: https://github.com/kyllingstad/zmqd/pull/30
[PR #31]: https://github.com/kyllingstad/zmqd/pull/31
[PR #32]: https://github.com/kyllingstad/zmqd/pull/32
