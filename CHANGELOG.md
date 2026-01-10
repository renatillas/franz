# Changelog

All notable changes to Franz will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.0.0] - Unreleased

### Changed

- **BREAKING: Single-Module Architecture** - All types and functions consolidated into the main `franz` module
  - Removed: `franz/consumer/config`, `franz/consumer/group_subscriber`, `franz/consumer/message_type`, `franz/consumer/topic_subscriber`
  - Removed: `franz/producer`, `franz/producer/config`
  - Removed: `franz/isolation_level`
  - All types and functions are now accessed directly from `franz`
  - Import simplification: `import franz` is now all you need

- **BREAKING: New Builder Pattern API** - Complete API redesign with fluent builders
  - Client: `franz.client()` → `franz.endpoints([...])` → `franz.name(name)` → `franz.start()`
  - Producer: `franz.producer(client, topic)` → `franz.producer_option(...)` → `franz.producer_start()`
  - Group subscriber: `franz.default_group_subscriber_config(...)` → `franz.start_group_subscriber()`
  - Topic subscriber: `franz.default_topic_subscriber(...)` → `franz.start_topic_subscriber()`

- **BREAKING: Error Type Reorganization** - Errors now organized by operation category
  - `FranzError` replaced with 5 specific error types:
  - `ClientError` - Connection and authentication failures
  - `TopicError` - Topic administration errors (create, delete)
  - `ProduceError` - Producer operation errors
  - `FetchError` - Consumer/fetch operation errors
  - `GroupError` - Consumer group errors

- **BREAKING: Type Renames**
  - `MessageSet` → `MessageBatch` (message type enum)
  - `Message` → `SingleMessage` (message type enum)
  - `Partition(n)` → `SinglePartition(n)` (partition selector)
  - `Hash` → `Partitioner(Hash)` (partition selector)
  - `Random` → `Partitioner(Random)` (partition selector)
  - Callback actions now prefixed: `GroupAck`, `GroupCommit`, `TopicAck`

- **BREAKING: Client Type Now Opaque** - `Client` is now an opaque type
  - Use `franz.named(name)` to get a client reference from a registered name

- **BREAKING: Consumer Option Renames**
  - `IsolationLevel` → `ConsumerIsolationLevel` (to avoid ambiguity)
  - Isolation values: `ReadCommitted`, `ReadUncommitted` (directly in franz module)

- **BREAKING: Configuration Option Changes**
  - Producer options now use `ProducerOption` type with variants like `RequiredAcks`, `AckTimeout`, `Compression`, etc.
  - Consumer options now use `ConsumerOption` type with variants like `BeginOffset`, `MinBytes`, `MaxBytes`, etc.
  - Group options now use `GroupOption` type with variants like `SessionTimeout`, `HeartbeatRate`, etc.

- **BREAKING: Type-Safe Time Values with gleam_time**
  - All duration/timeout parameters now use `gleam/time/duration.Duration` instead of raw integers
  - All timestamp parameters now use `gleam/time/timestamp.Timestamp` instead of raw integers
  - Client options renamed: `RestartDelaySeconds` → `RestartDelay`, `ReconnectCoolDownSeconds` → `ReconnectCoolDown`, `ConnectTimeout` and `RequestTimeout` now take `Duration`
  - Producer options renamed: `AckTimeout` now takes `Duration`, `RetryBackoffMs` → `RetryBackoff`, `MaxLingerMs` → `MaxLinger`
  - Consumer options: `MaxWaitTime` and `SleepTimeout` now take `Duration`
  - Group options renamed: `SessionTimeoutSeconds` → `SessionTimeout`, `HeartbeatRateSeconds` → `HeartbeatRate`, `RebalanceTimeoutSeconds` → `RebalanceTimeout`, `RejoinDelaySeconds` → `RejoinDelay`, `OffsetCommitIntervalSeconds` → `OffsetCommitInterval`, `OffsetRetentionSeconds` → `OffsetRetention`
  - Fetch options: `FetchMaxWaitTime` now takes `Duration`
  - `StartingOffset.AtTimestamp` now takes `Timestamp` instead of `Int`
  - `KafkaMessage.timestamp` is now `Timestamp` instead of `Int`
  - `ProduceValue.ValueWithTimestamp` timestamp is now `Timestamp` instead of `Int`
  - Function parameters: `create_topic` and `delete_topics` timeout is now `Duration`
  - Example: `franz.option(franz.ConnectTimeout(duration.seconds(5)))`

### Added

- **gleam_time Dependency** - Added `gleam_time` for type-safe time handling

- **Comprehensive Module Documentation** - Extensive module-level documentation with:
  - Kafka concept explanations with links to official Kafka documentation
  - Quick start examples for common use cases
  - Producer semantics table (at-most-once, at-least-once)
  - Partitioning strategies explanation
  - Consumer offset management guide
  - Transaction isolation levels
  - Authentication configuration examples
  - OTP supervision integration examples
  - Compression options guide
  - Error handling reference table

- **HexDocs Organization** - Custom JavaScript for better documentation navigation
  - Types and functions organized by category in sidebar
  - Logical groupings: Client, Authentication, Topic Administration, Producer, Group Subscriber, Topic Subscriber, Consumer Configuration, Messages, Errors

- **New Functions**
  - `franz.named(name)` - Get client reference from registered process name
  - `franz.stop(client)` - Stop a running client
  - `franz.produce_sync_offset(...)` - Produce synchronously and return the assigned offset
  - `franz.group_subscriber_stop(pid)` - Stop a group subscriber

- **SSL/TLS Configuration** - Enhanced SSL options
  - `SslEnabled` - Use system CA certificates
  - `SslWithOptions` - Custom certificate configuration for mTLS
  - `SslVerify` - Control certificate verification (VerifyPeer, VerifyNone)

- **Fetch Options** - Low-level fetch configuration
  - `FetchMaxWaitTime`, `FetchMinBytes`, `FetchMaxBytes`, `FetchIsolationLevel`

## [3.0.0] - 2025-09-15

### Changed

- **BREAKING: Module Reorganization** - Consumer and producer configurations moved to dedicated submodules
  - `franz/consumer_config` → `franz/consumer/config`
  - `franz/producer_config` → `franz/producer/config`
  - `franz/group_config` merged into `franz/consumer/group_subscriber`
  - `franz/message_type` → `franz/consumer/message_type`
- **Improved Consumer APIs** - Enhanced topic and group subscriber builders
  - Added `actor.StartResult` return types for better OTP integration
  - Added `named_client` functions for referencing existing subscribers
  - Improved builder patterns with better type safety
- **Enhanced Documentation** - Added comprehensive doc comments throughout the codebase
  - All public types and functions now have detailed documentation
  - Better explanation of configuration options and their defaults
- **Error Handling Improvements** - More specific error information in consumer APIs
  - `ConsumerNotFound` now includes topic and partition information
  - Better error propagation through actor start results

### Added

- **Test Coverage** - New comprehensive integration tests for Kafka error scenarios
  - Added `kafka_error_integration_test.gleam` with extensive error case testing
  - Improved test organization and coverage

## [2.0.0] - 2025-08-23

### Added

- **OTP Supervision Support** - Franz clients can now be supervised using OTP supervisors
  - New `supervised/1` function to create supervisor-compatible workers
  - Integration with `gleam/otp/actor` and `gleam/otp/supervision`
- **Named Clients** - Support for named clients via process names
  - `named_client/1` function to create clients with process names
  - Improved client lifecycle management
- **Comprehensive Kafka Error Types** - Added 30+ specific error variants for better error handling:
  - Message errors: `CorruptMessage`, `InvalidFetchSize`, `MessageTooLarge`, `RecordListTooLarge`
  - Leader/Replica errors: `LeaderNotAvailable`, `NotLeaderOrFollower`, `ReplicaNotAvailable`, `NotEnoughReplicas`
  - Coordinator errors: `CoordinatorLoadInProgress`, `CoordinatorNotAvailable`, `NotCoordinator`
  - Group management: `IllegalGeneration`, `InconsistentGroupProtocol`, `InvalidGroupId`, `UnknownMemberId`, `RebalanceInProgress`
  - Authorization: `TopicAuthorizationFailed`, `GroupAuthorizationFailed`, `ClusterAuthorizationFailed`
  - Configuration: `InvalidTopic`, `InvalidPartitions`, `InvalidReplicationFactor`, `InvalidConfig`
  - Protocol: `InvalidTimestamp`, `InvalidCommitOffsetSize`, `OffsetMetadataTooLarge`
  - SASL: `UnsupportedSaslMechanism`, `IllegalSaslState`
  - Other: `NetworkException`, `UnsupportedVersion`, `StaleControllerEpoch`, `NotController`
- **Improved Client Lifecycle**
  - New `start/1` function returns `actor.StartResult(Client)`
  - Better integration with OTP patterns
  - `stop_client/1` function for graceful shutdown

### Changed

- **Breaking: Type Renames**
  - `ClientBuilder` renamed to `Builder`
  - `FranzClient` renamed to `Client` and now wraps a process name
- **Breaking: API Changes**
  - `new/1` now requires a `process.Name(Message)` parameter
  - Client initialization returns OTP actor results
- **Documentation Overhaul**
  - Completely rewritten README with better examples
  - Improved API documentation
  - Added comprehensive feature list

### Fixed

- Various stability improvements in error handling
- Better FFI integration with underlying Erlang/brod client

## [1.1.0] - 2025-02-14

### Added

- GitHub Actions CI integration for automated testing
- Kafka service in CI pipeline for integration tests
- Support for Gleam 1.11 and updated dependencies

### Changed

- Updated project template to use Gleam 1.11
- Modernized dependency versions for better compatibility

### Fixed

- Topic name handling in tests
- CI configuration improvements
- Removed unused functions

## [1.0.1] - 2025-02-13

### Fixed

- Minor bug fixes and stability improvements

## [1.0.0] - 2025-02-13

### Added

- **Production-Ready Release** - First stable release of Franz
- **Complete Producer API**
  - Synchronous and asynchronous message production
  - Batch message support
  - Multiple partitioning strategies (random, hash, custom)
  - Configurable producer settings
- **Consumer Groups**
  - Group-based consumption with automatic rebalancing
  - Configurable group settings via `group_config` module
- **Topic Subscription**
  - Direct topic subscription for simpler use cases
  - Partition-specific consumption
- **Rich Configuration Options**
  - Comprehensive client configuration
  - Producer-specific settings
  - Consumer group configuration
  - SASL authentication support (PLAIN, SCRAM)
- **Type-Safe API**
  - Full Gleam type safety
  - Comprehensive error types
  - Well-defined message types

### Changed

- Major API stabilization from v0.x series
- Improved error handling and reporting
- Better FFI integration with brod client
- Enhanced documentation and examples

## [0.5.1] - 2025-01-15

### Fixed

- Message fetching issues
- Version configuration

## [0.5.0] - 2025-01-15

### Added

- Comprehensive documentation improvements
- Additional code examples

### Changed

- API refinements for better usability

## [0.4.0] - 2025-01-10

### Added

- Extended producer configuration options
- Better partition management

### Changed

- Documentation improvements
- Internal code organization

## [0.3.0] - 2025-01-08

### Changed

- Major code reorganization for better maintainability
- Improved module structure
- Documentation enhancements

## [0.2.0] - 2025-01-05

### Added

- Basic consumer functionality
- Initial producer implementation

### Changed

- Various improvements to core functionality

## [0.1.0] - 2025-01-01

### Added

- Initial release of Franz
- Basic Kafka client functionality
- Connection management
- Foundation for producer and consumer APIs

[4.0.0]: https://github.com/renatillas/franz/compare/v3.0.0...v4.0.0
[3.0.0]: https://github.com/renatillas/franz/compare/v2.0.0...v3.0.0
[2.0.0]: https://github.com/renatillas/franz/compare/v1.1.0...v2.0.0
[1.1.0]: https://github.com/renatillas/franz/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/renatillas/franz/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/renatillas/franz/compare/v0.5.1...v1.0.0
[0.5.1]: https://github.com/renatillas/franz/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/renatillas/franz/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/renatillas/franz/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/renatillas/franz/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/renatillas/franz/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/renatillas/franz/releases/tag/v0.1.0

