//// <script>
//// const docs = [
////   {
////     header: "Client",
////     types: ["Client", "ClientBuilder", "ClientOption", "Endpoint", "Message"],
////     functions: ["client", "endpoint", "endpoints", "name", "option", "sasl", "ssl", "start", "supervised", "named", "stop"]
////   },
////   {
////     header: "Authentication",
////     types: ["SaslMechanism", "SaslCredentials", "SslOption", "SslVerify"],
////     functions: []
////   },
////   {
////     header: "Topic Administration",
////     types: ["ConsumerGroup"],
////     functions: ["create_topic", "delete_topics", "list_groups", "fetch"]
////   },
////   {
////     header: "Producer",
////     types: ["ProducerBuilder", "ProducerOption", "PartitionSelector", "Partitioner", "ProduceValue", "Compression", "Partition", "Offset"],
////     functions: ["producer", "producer_option", "producer_start", "produce", "produce_sync", "produce_sync_offset", "produce_async"]
////   },
////   {
////     header: "Group Subscriber",
////     types: ["GroupSubscriber", "GroupSubscriberBuilder", "GroupSubscriberMessage", "GroupCallbackAction", "GroupOption"],
////     functions: ["default_group_subscriber_config", "start_group_subscriber", "group_subscriber_supervised", "group_subscriber_stop"]
////   },
////   {
////     header: "Topic Subscriber",
////     types: ["TopicSubscriber", "TopicSubscriberConfig", "TopicSubscriberMessage", "TopicCallbackAction", "SubscribePartitions"],
////     functions: ["default_topic_subscriber", "start_topic_subscriber", "topic_subscriber_supervised"]
////   },
////   {
////     header: "Consumer Configuration",
////     types: ["ConsumerOption", "StartingOffset", "OffsetResetPolicy", "IsolationLevel", "FetchOption", "MessageType"],
////     functions: []
////   },
////   {
////     header: "Messages",
////     types: ["KafkaMessage", "TimestampType"],
////     functions: []
////   },
////   {
////     header: "Errors",
////     types: ["ClientError", "TopicError", "ProduceError", "FetchError", "GroupError"],
////     functions: []
////   }
//// ]
////
//// const callback = () => {
////   const sidebar = document.querySelector(".sidebar")
////   const moduleMembers = document.querySelector(".module-members")
////
////   const sidebarH2s = sidebar.querySelectorAll("h2")
////   let typesH2, valuesH2
////   sidebarH2s.forEach(h2 => {
////     if (h2.textContent === "Types") typesH2 = h2
////     if (h2.textContent === "Values") valuesH2 = h2
////   })
////
////   const typesUl = typesH2?.nextElementSibling
////   const valuesUl = valuesH2?.nextElementSibling
////   if (!typesUl || !valuesUl) return
////
////   const newSidebarContent = document.createDocumentFragment()
////   const newMainContent = document.createDocumentFragment()
////
////   for (const section of docs) {
////     const sidebarHeader = document.createElement("h2")
////     sidebarHeader.textContent = section.header
////     newSidebarContent.append(sidebarHeader)
////
////     const sidebarList = document.createElement("ul")
////     newSidebarContent.append(sidebarList)
////
////     const mainHeader = document.createElement("h1")
////     mainHeader.className = "module-member-kind"
////     mainHeader.textContent = section.header
////     newMainContent.append(mainHeader)
////
////     for (const name of (section.types || [])) {
////       const sidebarItem = typesUl.querySelector(`li:has(a[href="#${name}"])`)
////       const member = moduleMembers.querySelector(`.member:has(h2#${name})`)
////       if (sidebarItem) sidebarList.append(sidebarItem)
////       if (member) newMainContent.append(member)
////     }
////
////     for (const name of (section.functions || [])) {
////       const sidebarItem = valuesUl.querySelector(`li:has(a[href="#${name}"])`)
////       const member = moduleMembers.querySelector(`.member:has(h2#${name})`)
////       if (sidebarItem) sidebarList.append(sidebarItem)
////       if (member) newMainContent.append(member)
////     }
////   }
////
////   typesH2.replaceWith(newSidebarContent)
////   typesUl.remove()
////   valuesH2.remove()
////   valuesUl.remove()
////
////   const moduleTypes = document.querySelector("#module-types")
////   const moduleValues = document.querySelector("#module-values")
////   if (moduleTypes) {
////     moduleTypes.replaceWith(newMainContent)
////   }
////   if (moduleValues) {
////     moduleValues.remove()
////   }
//// }
////
//// document.readyState !== "loading"
////   ? callback()
////   : document.addEventListener("DOMContentLoaded", callback, { once: true })
//// </script>
////
//// # Franz
////
//// A type-safe [Apache Kafka](https://kafka.apache.org/) client for Gleam, built
//// on top of the battle-tested [brod](https://github.com/kafka4beam/brod) Erlang library.
////
//// ## Kafka Overview
////
//// [Apache Kafka](https://kafka.apache.org/documentation/) is a distributed
//// event streaming platform. Key concepts:
////
//// - **Brokers**: Kafka runs as a cluster of servers called
////   [brokers](https://kafka.apache.org/documentation/#brokerconfigs) that store
////   and serve data. Franz connects to brokers via `Endpoint(host, port)`.
////
//// - **Topics**: Messages are organized into
////   [topics](https://kafka.apache.org/documentation/#intro_concepts_and_terms)
////   - named feeds of records. Topics are created with `create_topic()`.
////
//// - **Partitions**: Topics are split into
////   [partitions](https://kafka.apache.org/documentation/#intro_concepts_and_terms)
////   for parallelism. Each partition is an ordered, immutable sequence of records.
////   Messages within a partition have a sequential `Offset`.
////
//// - **Producers**: Applications that publish messages to topics. See the
////   [Producer section](https://kafka.apache.org/documentation/#producerapi).
////
//// - **Consumers**: Applications that read messages from topics. Kafka supports
////   two consumption patterns:
////   - **Consumer Groups**: High-level API with automatic partition assignment
////     and offset management. See [Consumer Groups](https://kafka.apache.org/documentation/#intro_consumers).
////   - **Topic Subscribers**: Low-level API for direct partition access.
////
//// ## Quick Start
////
//// ```gleam
//// import franz
//// import gleam/erlang/process
////
//// pub fn main() {
////   // 1. Start a client connection to the Kafka cluster
////   let name = process.new_name("my_kafka_client")
////   let assert Ok(_) =
////     franz.client()
////     |> franz.endpoints([franz.Endpoint("localhost", 9092)])
////     |> franz.name(name)
////     |> franz.start()
////
////   let client = franz.named(name)
////
////   // 2. Create a topic with 3 partitions
////   let assert Ok(_) =
////     franz.create_topic(
////       endpoints: [franz.Endpoint("localhost", 9092)],
////       name: "my_topic",
////       partitions: 3,
////       replication_factor: 1,
////       configs: [],
////       timeout_ms: 5000,
////     )
////
////   // 3. Start a producer and send a message
////   let assert Ok(_) =
////     franz.producer(client, "my_topic")
////     |> franz.producer_start()
////
////   let assert Ok(_) =
////     franz.produce_sync(
////       client: client,
////       topic: "my_topic",
////       partition: franz.SinglePartition(0),
////       key: <<"user_123">>,
////       value: franz.Value(<<"Hello, Kafka!">>, []),
////     )
//// }
//// ```
////
//// ## Consuming Messages
////
//// Franz provides two ways to consume messages:
////
//// ### Consumer Groups (Recommended)
////
//// [Consumer groups](https://kafka.apache.org/documentation/#intro_consumers)
//// provide automatic partition assignment, offset tracking, and rebalancing
//// when consumers join or leave the group.
////
//// ```gleam
//// let name = process.new_name("my_consumer")
//// let assert Ok(_) =
////   franz.default_group_subscriber_config(
////     name,
////     client: client,
////     group_id: "my_consumer_group",
////     topics: ["my_topic"],
////     callback: fn(message, state) {
////       io.println("Received: " <> bit_array.to_string(message.value))
////       franz.GroupCommit(state)  // Commit offset after processing
////     },
////     init_state: Nil,
////   )
////   |> franz.start_group_subscriber()
//// ```
////
//// ### Topic Subscribers (Low-level)
////
//// For fine-grained control over partition assignment and offset management:
////
//// ```gleam
//// let name = process.new_name("my_subscriber")
//// let assert Ok(_) =
////   franz.default_topic_subscriber(
////     name,
////     client: client,
////     topic: "my_topic",
////     callback: fn(partition, message, state) {
////       io.println("Partition " <> int.to_string(partition))
////       franz.TopicAck(state)
////     },
////     initial_state: Nil,
////   )
////   |> franz.start_topic_subscriber()
//// ```
////
//// ## Producer Semantics
////
//// Kafka producers support different
//// [delivery guarantees](https://kafka.apache.org/documentation/#semantics):
////
//// | Function | Guarantee | Use Case |
//// |----------|-----------|----------|
//// | `produce` | At-most-once | Fire and forget, highest throughput |
//// | `produce_sync` | At-least-once | Wait for broker acknowledgment |
//// | `produce_async` | At-least-once | Async with callback notification |
////
//// Configure acknowledgments with `RequiredAcks`:
//// - `0`: No acknowledgment (fastest, may lose messages)
//// - `1`: Leader acknowledgment (balanced)
//// - `-1`: All in-sync replicas (strongest durability)
////
//// See [Producer Configs](https://kafka.apache.org/documentation/#producerconfigs)
//// for details on `acks`, `compression.type`, `batch.size`, and more.
////
//// ## Partitioning
////
//// Messages are assigned to [partitions](https://kafka.apache.org/documentation/#intro_concepts_and_terms)
//// using a `PartitionSelector`:
////
//// - `SinglePartition(n)`: Send to a specific partition
//// - `Partitioner(Hash)`: Hash the key for consistent routing
//// - `Partitioner(Random)`: Random distribution
//// - `Partitioner(PartitionFun(...))`: Custom partitioning logic
////
//// Keys ensure messages with the same key go to the same partition,
//// preserving order for related events.
////
//// ## Consumer Offsets
////
//// [Offsets](https://kafka.apache.org/documentation/#intro_concepts_and_terms)
//// track consumption progress. Configure starting position with `BeginOffset`:
////
//// - `Latest`: Start from newest messages (default)
//// - `Earliest`: Read from the beginning
//// - `AtOffset(n)`: Start at a specific offset
//// - `AtTimestamp(ts)`: Start from a point in time
////
//// For consumer groups, Kafka stores committed offsets. Use `GroupCommit` in
//// your callback to persist progress.
////
//// ## Transactions and Isolation
////
//// Kafka supports [transactions](https://kafka.apache.org/documentation/#semantics)
//// for exactly-once semantics. Control visibility with `IsolationLevel`:
////
//// - `ReadCommitted`: Only see committed transaction messages (default)
//// - `ReadUncommitted`: See all messages including uncommitted
////
//// ## Authentication
////
//// Franz supports [SASL authentication](https://kafka.apache.org/documentation/#security_sasl):
////
//// - `Plain`: Username/password in clear text (use with SSL)
//// - `ScramSha256`: Challenge-response authentication
//// - `ScramSha512`: Stronger SCRAM variant
////
//// And [SSL/TLS encryption](https://kafka.apache.org/documentation/#security_ssl)
//// for secure connections.
////
//// ```gleam
//// franz.client()
//// |> franz.endpoints([franz.Endpoint("kafka.example.com", 9093)])
//// |> franz.sasl(franz.SaslCredentials(franz.ScramSha256, "user", "pass"))
//// |> franz.ssl(franz.SslEnabled)
//// |> franz.name(name)
//// |> franz.start()
//// ```
////
//// ## OTP Supervision
////
//// All Franz components integrate with
//// [gleam_otp](https://hexdocs.pm/gleam_otp/) supervision trees:
////
//// ```gleam
//// import gleam/otp/supervision
////
//// let children = [
////   franz.supervised(client_builder),
////   franz.group_subscriber_supervised(subscriber_builder),
//// ]
//// supervision.start(children)
//// ```
////
//// For dynamic consumer management, use
//// [factory_supervisor](https://hexdocs.pm/gleam_otp/gleam/otp/factory_supervisor.html):
////
//// ```gleam
//// import gleam/otp/factory_supervisor
////
//// // Create a factory that spawns topic subscribers on demand
//// let factory =
////   factory_supervisor.worker_child(fn(topic: String) {
////     let name = process.new_name(topic)
////     franz.default_topic_subscriber(name, client:, topic:, callback:, initial_state:)
////     |> franz.start_topic_subscriber()
////   })
////   |> factory_supervisor.start()
////
//// // Dynamically add consumers at runtime
//// factory_supervisor.start_child(factory, "orders-topic")
//// factory_supervisor.start_child(factory, "payments-topic")
//// ```
////
//// ## Compression
////
//// Reduce network bandwidth with
//// [message compression](https://kafka.apache.org/documentation/#producerconfigs_compression.type):
////
//// - `NoCompression`: No compression (default)
//// - `Gzip`: Good compression ratio, higher CPU
//// - `Snappy`: Fast compression, moderate ratio
//// - `Lz4`: Balanced speed and compression
////
//// ## Error Handling
////
//// Each operation category has its own error type for precise handling:
////
//// | Error Type | Operations | Reference |
//// |------------|------------|-----------|
//// | `ClientError` | `start` | Connection and auth failures |
//// | `TopicError` | `create_topic`, `delete_topics` | [Topic errors](https://kafka.apache.org/protocol#protocol_error_codes) |
//// | `ProduceError` | `produce`, `produce_sync`, `produce_async` | [Producer errors](https://kafka.apache.org/protocol#protocol_error_codes) |
//// | `FetchError` | `fetch` | [Fetch errors](https://kafka.apache.org/protocol#protocol_error_codes) |
//// | `GroupError` | `list_groups`, `group_subscriber_stop` | [Group errors](https://kafka.apache.org/protocol#protocol_error_codes) |
////
//// ## Further Reading
////
//// - [Kafka Documentation](https://kafka.apache.org/documentation/)
//// - [Kafka Design](https://kafka.apache.org/documentation/#design)
//// - [Kafka Protocol](https://kafka.apache.org/protocol)
//// - [brod (Erlang client)](https://github.com/kafka4beam/brod)
////

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/erlang/atom
import gleam/erlang/process
import gleam/list
import gleam/option.{type Option}
import gleam/otp/actor
import gleam/otp/supervision
import gleam/time/duration.{type Duration}
import gleam/time/timestamp.{type Timestamp}

// =============================================================================
// CORE TYPES
// =============================================================================

/// A Franz client that manages connections to Kafka brokers.
///
/// The client maintains persistent connections to the Kafka cluster and handles
/// metadata discovery, connection pooling, and reconnection logic. All operations
/// (producing, consuming, topic administration) require a client.
///
/// Clients are identified by a registered process name, allowing them to be
/// referenced from anywhere in your application.
///
/// See [Kafka Broker Configuration](https://kafka.apache.org/documentation/#brokerconfigs)
/// for details on broker settings.
pub opaque type Client {
  Client(name: process.Name(Message))
}

/// Internal message type used by the Franz client process.
pub type Message

/// A Kafka broker endpoint consisting of a host and port.
///
/// Kafka clusters consist of multiple brokers. You should provide at least one
/// endpoint for initial connection - the client will discover other brokers
/// automatically through cluster metadata.
///
/// ```gleam
/// let endpoints = [
///   franz.Endpoint("broker1.example.com", 9092),
///   franz.Endpoint("broker2.example.com", 9092),
/// ]
/// ```
pub type Endpoint {
  Endpoint(host: String, port: Int)
}

// =============================================================================
// AUTHENTICATION TYPES
// =============================================================================

/// SASL authentication mechanisms supported by Kafka.
///
/// SASL (Simple Authentication and Security Layer) provides authentication
/// between clients and brokers. Choose a mechanism based on your security
/// requirements and infrastructure.
///
/// See [Kafka SASL Authentication](https://kafka.apache.org/documentation/#security_sasl).
pub type SaslMechanism {
  /// PLAIN mechanism - sends credentials in clear text.
  /// **Always use with SSL/TLS** to encrypt the connection, otherwise
  /// credentials are transmitted in plain text over the network.
  Plain
  /// SCRAM-SHA-256 - Salted Challenge Response Authentication Mechanism.
  /// More secure than PLAIN as passwords are never sent over the wire.
  /// See [RFC 5802](https://tools.ietf.org/html/rfc5802).
  ScramSha256
  /// SCRAM-SHA-512 - SCRAM with SHA-512 hashing.
  /// Provides stronger security than SCRAM-SHA-256.
  ScramSha512
}

/// SASL credentials for authenticating with Kafka brokers.
///
/// ```gleam
/// franz.SaslCredentials(franz.ScramSha256, "username", "password")
/// ```
pub type SaslCredentials {
  /// Username and password credentials with the specified SASL mechanism.
  SaslCredentials(mechanism: SaslMechanism, username: String, password: String)
}

/// SSL/TLS configuration options for encrypted connections.
///
/// SSL/TLS encrypts all traffic between the client and Kafka brokers,
/// protecting data in transit. Can be combined with SASL authentication.
///
/// See [Kafka SSL Encryption](https://kafka.apache.org/documentation/#security_ssl).
pub type SslOption {
  /// Enable SSL with system default CA certificates.
  /// Uses the operating system's trusted CA store.
  SslEnabled
  /// Enable SSL with custom certificate configuration.
  /// Use this for self-signed certificates or mutual TLS (mTLS).
  SslWithOptions(
    /// Path to CA certificate file for verifying the broker's certificate.
    cacertfile: Option(String),
    /// Path to client certificate file (for mutual TLS).
    certfile: Option(String),
    /// Path to client private key file (for mutual TLS).
    keyfile: Option(String),
    /// Whether to verify the broker's certificate.
    verify: SslVerify,
  )
}

/// SSL peer certificate verification mode.
pub type SslVerify {
  /// Verify the broker's certificate against trusted CAs.
  /// **Recommended for production** to prevent man-in-the-middle attacks.
  VerifyPeer
  /// Skip certificate verification.
  /// **Not recommended for production** - only use for development/testing.
  VerifyNone
}

// =============================================================================
// ERROR TYPES
// =============================================================================

/// Errors that can occur when starting or connecting the Franz client.
///
/// These errors typically indicate infrastructure issues (network, broker availability)
/// or authentication/authorization problems.
///
/// See [Kafka Error Codes](https://kafka.apache.org/protocol#protocol_error_codes).
pub type ClientError {
  /// No broker is available to handle the request. Check broker health.
  ClientBrokerNotAvailable
  /// Network-level error occurred (DNS resolution, connection refused, etc.).
  ClientNetworkException
  /// The request timed out waiting for a response from the broker.
  ClientRequestTimedOut
  /// SASL authentication failed. Check username/password and mechanism.
  ClientAuthenticationFailed(reason: String)
  /// SSL/TLS handshake failed. Check certificate configuration.
  ClientSslHandshakeFailed(reason: String)
  /// The requested SASL mechanism is not supported by the broker.
  ClientUnsupportedSaslMechanism
  /// SASL authentication is in an invalid state.
  ClientIllegalSaslState
  /// An unexpected error occurred. Contains the original error for debugging.
  ClientUnknownError(reason: Dynamic)
}

/// Errors that can occur during topic administration (create, delete).
///
/// See [Kafka Topic Configuration](https://kafka.apache.org/documentation/#topicconfigs).
pub type TopicError {
  /// Attempted to create a topic that already exists.
  TopicAlreadyExists
  /// The requested topic does not exist.
  TopicNotFound
  /// The topic name is invalid (empty, too long, or contains invalid characters).
  TopicInvalidName
  /// Invalid number of partitions (must be > 0).
  TopicInvalidPartitions
  /// Invalid replication factor (must be > 0 and <= number of brokers).
  TopicInvalidReplicationFactor
  /// Invalid manual partition-to-broker assignment.
  TopicInvalidReplicaAssignment
  /// Invalid topic configuration parameter.
  TopicInvalidConfig
  /// Not authorized to perform this topic operation.
  TopicAuthorizationFailed
  /// The operation timed out.
  TopicRequestTimedOut
  /// No broker available to handle the request.
  TopicBrokerNotAvailable
  /// An unexpected error occurred. Contains the original error for debugging.
  TopicUnknownError(reason: Dynamic)
}

/// Errors that can occur when producing messages.
///
/// See [Producer Semantics](https://kafka.apache.org/documentation/#semantics).
pub type ProduceError {
  /// No producer exists for the specified topic/partition. Call `producer_start` first.
  ProducerNotFound(topic: String, partition: Int)
  /// The producer process has crashed.
  ProducerDown
  /// The client connection to Kafka has been lost.
  ProducerClientDown
  /// The partition leader is not available. May occur during leader election.
  ProducerLeaderNotAvailable
  /// This broker is not the leader for the partition. Metadata may be stale.
  ProducerNotLeaderOrFollower
  /// The message exceeds `message.max.bytes` configured on the broker.
  ProducerMessageTooLarge
  /// The batch of messages exceeds the maximum allowed size.
  ProducerRecordListTooLarge
  /// Not enough in-sync replicas to satisfy `min.insync.replicas`.
  ProducerNotEnoughReplicas
  /// Message was written to leader but failed to replicate to enough replicas.
  ProducerNotEnoughReplicasAfterAppend
  /// Invalid `RequiredAcks` configuration value.
  ProducerInvalidRequiredAcks
  /// Not authorized to produce to this topic.
  ProducerAuthorizationFailed
  /// The produce request timed out.
  ProducerRequestTimedOut
  /// No broker available to handle the request.
  ProducerBrokerNotAvailable
  /// An unexpected error occurred. Contains the original error for debugging.
  ProducerUnknownError(reason: Dynamic)
}

/// Errors that can occur when fetching/consuming messages.
///
/// See [Consumer Configuration](https://kafka.apache.org/documentation/#consumerconfigs).
pub type FetchError {
  /// The requested offset is outside the valid range for this partition.
  /// Occurs when offset is before the earliest or after the latest message.
  FetchOffsetOutOfRange
  /// The fetch size is invalid (too small to hold a message).
  FetchInvalidSize
  /// The message failed CRC validation - data corruption detected.
  FetchCorruptMessage
  /// Invalid timestamp in the fetch request.
  FetchInvalidTimestamp
  /// The partition leader is not available.
  FetchLeaderNotAvailable
  /// This broker is not the leader for the partition.
  FetchNotLeaderOrFollower
  /// The requested topic does not exist.
  FetchTopicNotFound
  /// No consumer exists for the specified topic/partition.
  FetchConsumerNotFound(topic: String, partition: Int)
  /// The client connection to Kafka has been lost.
  FetchClientDown
  /// Not authorized to consume from this topic.
  FetchAuthorizationFailed
  /// The fetch request timed out.
  FetchRequestTimedOut
  /// No broker available to handle the request.
  FetchBrokerNotAvailable
  /// An unexpected error occurred. Contains the original error for debugging.
  FetchUnknownError(reason: Dynamic)
}

/// Errors that can occur with consumer group operations.
///
/// Consumer groups coordinate partition assignment across multiple consumers.
/// These errors often relate to group membership and rebalancing.
///
/// See [Consumer Group Protocol](https://kafka.apache.org/documentation/#intro_consumers).
pub type GroupError {
  /// The group coordinator is loading and cannot accept requests.
  GroupCoordinatorLoading
  /// No group coordinator is available.
  GroupCoordinatorNotAvailable
  /// This broker is not the coordinator for this group.
  GroupNotCoordinator
  /// The generation ID in the request is stale (rebalance occurred).
  GroupIllegalGeneration
  /// Group members are using incompatible protocols.
  GroupInconsistentProtocol
  /// The group ID is invalid.
  GroupInvalidId
  /// The member ID is not recognized (may have been removed).
  GroupUnknownMember
  /// The session timeout is outside the allowed range.
  GroupInvalidSessionTimeout
  /// A rebalance is in progress; retry after it completes.
  GroupRebalanceInProgress
  /// The offset commit size is invalid.
  GroupInvalidCommitOffsetSize
  /// Not authorized to access this consumer group.
  GroupAuthorizationFailed
  /// The client connection to Kafka has been lost.
  GroupClientDown
  /// The group operation timed out.
  GroupRequestTimedOut
  /// No broker available to handle the request.
  GroupBrokerNotAvailable
  /// An unexpected error occurred. Contains the original error for debugging.
  GroupUnknownError(reason: Dynamic)
}

// =============================================================================
// MESSAGE TYPES
// =============================================================================

/// Represents a message or batch of messages received from Kafka.
///
/// Each Kafka message has an offset (its position in the partition), a key
/// (for partitioning and compaction), a value (the actual payload), optional
/// headers, and a timestamp.
///
/// See [Kafka Message Format](https://kafka.apache.org/documentation/#messageformat).
pub type KafkaMessage {
  /// A single Kafka message/record.
  KafkaMessage(
    /// The message's position in the partition log. Offsets are sequential
    /// and unique within a partition.
    offset: Int,
    /// The message key, used for partitioning and log compaction.
    /// Messages with the same key go to the same partition.
    key: BitArray,
    /// The message payload/body.
    value: BitArray,
    /// Whether the timestamp was set by the producer or broker.
    timestamp_type: TimestampType,
    /// When this message was created or appended (depending on timestamp_type).
    timestamp: Timestamp,
    /// Optional key-value headers for metadata.
    headers: List(#(String, BitArray)),
  )
  /// A batch of messages from a single topic-partition.
  /// Returned when using `MessageBatch` message type.
  KafkaMessageSet(
    /// The topic this batch came from.
    topic: String,
    /// The partition this batch came from.
    partition: Int,
    /// The high watermark offset - the offset of the next message
    /// that will be written to this partition.
    high_wm_offset: Int,
    /// The list of messages in this batch.
    messages: List(KafkaMessage),
  )
}

/// The type of timestamp associated with a Kafka message.
///
/// Kafka supports two timestamp types controlled by the topic's
/// `message.timestamp.type` configuration.
///
/// See [Topic Configuration](https://kafka.apache.org/documentation/#topicconfigs).
pub type TimestampType {
  /// Timestamp type is not defined (legacy messages).
  Undefined
  /// `CreateTime` - timestamp set by the producer when the message was created.
  /// This is the default and allows producers to set meaningful timestamps.
  Create
  /// `LogAppendTime` - timestamp set by the broker when the message was appended.
  /// Useful when you need broker-controlled timestamps.
  Append
}

/// Specifies how messages should be delivered to subscriber callbacks.
pub type MessageType {
  /// Deliver messages one at a time to the callback.
  /// The callback receives individual `KafkaMessage` values.
  /// This is the default and simplest mode.
  SingleMessage
  /// Deliver messages in batches for higher throughput.
  /// The callback receives `KafkaMessageSet` values containing multiple messages.
  /// Use this when processing is more efficient in batches.
  MessageBatch
}

// =============================================================================
// CLIENT CONFIGURATION
// =============================================================================

/// Configuration options for the Franz client.
///
/// These options control connection behavior, authentication, and default
/// settings for producers and consumers.
///
/// See [Kafka Client Configuration](https://kafka.apache.org/documentation/#consumerconfigs)
/// for the underlying configuration options.
pub type ClientOption {
  /// How long to wait between attempts to restart the client process when it crashes.
  /// Default: 10 seconds.
  RestartDelay(Duration)
  /// Delay before retrying to establish a new connection to a partition leader
  /// after a connection failure.
  /// Default: 1 second.
  ReconnectCoolDown(Duration)
  /// Whether to allow automatic topic creation when producing to or consuming
  /// from a non-existent topic. Respects the broker's `auto.create.topics.enable` setting.
  /// Default: true.
  AllowTopicAutoCreation(Bool)
  /// If true, the client will spawn a producer automatically when you call
  /// `produce` without first calling `producer_start`.
  /// Default: false.
  AutoStartProducers(Bool)
  /// Producer configuration to use when `AutoStartProducers` is enabled.
  /// Default: empty list (use producer defaults).
  DefaultProducerConfig(List(ProducerOption))
  /// How long to cache "unknown topic" errors before retrying metadata fetch.
  /// Useful for reducing load when a topic doesn't exist.
  /// Default: 2 minutes.
  UnknownTopicCacheTtl(Duration)
  /// SASL authentication credentials for connecting to secured brokers.
  Sasl(SaslCredentials)
  /// SSL/TLS configuration for encrypted connections.
  Ssl(SslOption)
  /// Timeout for establishing TCP connections to brokers.
  /// Default: 5 seconds.
  ConnectTimeout(Duration)
  /// Timeout for individual Kafka protocol requests.
  /// Default: 30 seconds.
  RequestTimeout(Duration)
}

// =============================================================================
// PRODUCER TYPES
// =============================================================================

/// Specifies how to select the partition for produced messages.
///
/// Kafka topics are divided into partitions for parallelism and scalability.
/// The partition selector determines which partition receives each message.
///
/// See [Kafka Partitioning](https://kafka.apache.org/documentation/#intro_concepts_and_terms).
pub type PartitionSelector {
  /// Send all messages to a specific partition number.
  /// Use when you need precise control over message placement.
  SinglePartition(Int)
  /// Use a partitioning strategy to automatically select partitions.
  Partitioner(Partitioner)
}

/// Strategies for distributing messages across Kafka partitions.
///
/// The partitioner determines which partition receives each message based on
/// the message key. Consistent partitioning ensures related messages
/// (same key) go to the same partition, preserving order.
pub type Partitioner {
  /// Custom partitioner function.
  /// Receives (topic, partition_count, key, value) and returns the partition number.
  /// Return `Error(Nil)` to fall back to default partitioning.
  PartitionFun(fn(String, Int, BitArray, BitArray) -> Result(Int, Nil))
  /// Randomly distribute messages across partitions.
  /// Provides good load balancing but no ordering guarantees.
  Random
  /// Hash the message key to determine the partition.
  /// Messages with the same key always go to the same partition,
  /// preserving order for related events.
  Hash
}

/// The value to be produced to Kafka, with optional headers and timestamp.
///
/// Kafka messages consist of a key, value, optional headers, and timestamp.
/// Headers are useful for metadata without modifying the message body.
pub type ProduceValue {
  /// Message value with optional headers. Timestamp will be set by the broker
  /// or producer automatically.
  Value(value: BitArray, headers: List(#(String, BitArray)))
  /// Message value with explicit timestamp and optional headers.
  /// Use this when you need to control the message timestamp (e.g., event sourcing).
  ValueWithTimestamp(
    value: BitArray,
    /// When this message was created.
    timestamp: Timestamp,
    headers: List(#(String, BitArray)),
  )
}

/// Configuration options for Kafka producers.
///
/// These options control durability guarantees, batching behavior, and performance.
///
/// See [Producer Configs](https://kafka.apache.org/documentation/#producerconfigs).
pub type ProducerOption {
  /// Number of acknowledgments required before considering a produce request complete.
  /// - `0`: No acknowledgment (fire-and-forget, fastest but may lose messages)
  /// - `1`: Leader acknowledgment (leader wrote to its log)
  /// - `-1`: All in-sync replicas acknowledged (strongest durability guarantee)
  ///
  /// Maps to Kafka's `acks` configuration.
  /// Default: -1.
  RequiredAcks(Int)
  /// Maximum time the broker will wait for acknowledgments from replicas.
  /// If the timeout expires, the produce request fails.
  /// Default: 10 seconds.
  AckTimeout(Duration)
  /// Maximum number of produce requests (per partition) that can be buffered
  /// before blocking the caller.
  /// Default: 256.
  PartitionBufferLimit(Int)
  /// Maximum number of in-flight produce requests (per partition) waiting for ACKs.
  /// Higher values increase throughput but may affect ordering on retry.
  /// Default: 1.
  PartitionOnWireLimit(Int)
  /// Maximum size in bytes for batching messages together.
  /// Larger batches improve throughput but increase latency.
  /// Default: 1048576 (1 MB).
  MaxBatchSize(Int)
  /// Maximum number of retries for failed produce requests.
  /// Use -1 for unlimited retries.
  /// Default: 3.
  MaxRetries(Int)
  /// Time to wait before retrying a failed produce request.
  /// Default: 500 milliseconds.
  RetryBackoff(Duration)
  /// Compression algorithm for message batches.
  /// Compression reduces network bandwidth at the cost of CPU.
  /// Default: NoCompression.
  Compression(Compression)
  /// Maximum time messages can wait in the buffer before being sent.
  /// Higher values allow more batching. Use duration.milliseconds(0) for immediate sends.
  /// Default: 0.
  MaxLinger(Duration)
  /// Maximum number of messages allowed to accumulate in the buffer.
  /// Use 0 for no limit (controlled by MaxLinger instead).
  /// Default: 0.
  MaxLingerCount(Int)
}

/// Compression algorithms for message batches.
///
/// Compression reduces network bandwidth and storage at the cost of CPU.
/// The broker will decompress when needed for consumers.
///
/// See [compression.type](https://kafka.apache.org/documentation/#producerconfigs_compression.type).
pub type Compression {
  /// No compression. Best for low-latency when bandwidth isn't a concern.
  NoCompression
  /// Gzip compression. Good compression ratio but higher CPU usage.
  /// Best for high-latency networks where bandwidth is expensive.
  Gzip
  /// Snappy compression. Fast with moderate compression ratio.
  /// Good balance between CPU and bandwidth.
  Snappy
  /// LZ4 compression. Very fast with good compression ratio.
  /// Often the best choice for high-throughput scenarios.
  Lz4
}

// =============================================================================
// CONSUMER TYPES
// =============================================================================

/// Configuration options for Kafka consumers.
///
/// These options control fetch behavior, prefetching, and offset management
/// for both topic subscribers and group subscribers.
///
/// See [Consumer Configs](https://kafka.apache.org/documentation/#consumerconfigs).
pub type ConsumerOption {
  /// The offset position from which to start consuming.
  /// Default: Latest.
  BeginOffset(StartingOffset)
  /// Minimum bytes the broker should return in a fetch response.
  /// The broker will wait until this threshold is met or `MaxWaitTime` expires.
  /// Default: 0 (return immediately).
  MinBytes(Int)
  /// Maximum bytes to fetch in a single request.
  /// Default: 1048576 (1 MB).
  MaxBytes(Int)
  /// Maximum time the broker will wait to collect `MinBytes` of data.
  /// Default: 10 seconds.
  MaxWaitTime(Duration)
  /// Time to sleep when the broker returns an empty message set.
  /// Reduces CPU usage during low-traffic periods.
  /// Default: 1 second.
  SleepTimeout(Duration)
  /// Number of messages to prefetch (fetch ahead of consumption).
  /// Higher values improve throughput but increase memory usage.
  /// Default: 10.
  PrefetchCount(Int)
  /// Maximum bytes to prefetch ahead of consumption.
  /// Default: 102400 (100 KB).
  PrefetchBytes(Int)
  /// What to do when the requested offset is out of range
  /// (before earliest or after latest).
  /// Default: ResetBySubscriber.
  OffsetResetPolicy(OffsetResetPolicy)
  /// Window size for calculating average message size statistics.
  /// Used for adaptive prefetching.
  /// Default: 5.
  SizeStatWindow(Int)
  /// Transaction isolation level for reading messages.
  /// Default: ReadCommitted.
  ConsumerIsolationLevel(IsolationLevel)
  /// Whether to share the connection to the partition leader with other
  /// producers or consumers. Reduces connection count but may impact isolation.
  ShareLeaderConn(Bool)
}

/// Specifies where to start consuming messages in a partition.
///
/// When a consumer starts (or restarts without a committed offset), this
/// determines which messages it will receive.
///
/// See [auto.offset.reset](https://kafka.apache.org/documentation/#consumerconfigs_auto.offset.reset).
pub type StartingOffset {
  /// Start from the newest messages (produced after consumer starts).
  /// Use when you only care about new events, not historical data.
  Latest
  /// Start from the oldest available messages.
  /// Use when you need to process all historical data.
  Earliest
  /// Start from messages produced at or after the specified timestamp.
  /// Useful for replaying events from a specific point in time.
  AtTimestamp(Timestamp)
  /// Start from a specific offset number.
  /// Use when you know exactly where to resume (e.g., from a checkpoint).
  AtOffset(Int)
}

/// Policy for handling "offset out of range" errors.
///
/// This occurs when the requested offset no longer exists (e.g., messages
/// were deleted due to retention policy, or offset is beyond the latest message).
pub type OffsetResetPolicy {
  /// Let the subscriber callback handle the error.
  /// Use when you need custom reset logic.
  ResetBySubscriber
  /// Automatically reset to the earliest available offset.
  /// Use when you want to process all available messages.
  ResetToEarliest
  /// Automatically reset to the latest offset.
  /// Use when you only care about new messages.
  ResetToLatest
}

/// Controls visibility of transactional messages.
///
/// Kafka supports transactions for exactly-once semantics. This setting
/// determines whether consumers see uncommitted transactional messages.
///
/// See [isolation.level](https://kafka.apache.org/documentation/#consumerconfigs_isolation.level).
pub type IsolationLevel {
  /// Only return messages from committed transactions.
  /// This is the safe default that provides exactly-once semantics.
  ReadCommitted
  /// Return all messages, including those from uncommitted transactions.
  /// Messages may later be rolled back and should not have been processed.
  ReadUncommitted
}

/// Options for the low-level `fetch` function.
///
/// These control individual fetch requests for direct partition consumption.
pub type FetchOption {
  /// Maximum time to wait for data if `FetchMinBytes` isn't satisfied.
  /// Default: 1 second.
  FetchMaxWaitTime(Duration)
  /// Minimum bytes to return. The broker waits until this threshold is met
  /// or `FetchMaxWaitTime` expires.
  /// Default: 0.
  FetchMinBytes(Int)
  /// Maximum bytes to return in the response.
  /// Default: 1048576 (1 MB).
  FetchMaxBytes(Int)
  /// Transaction isolation level for this fetch.
  /// Default: ReadCommitted.
  FetchIsolationLevel(IsolationLevel)
}

// =============================================================================
// GROUP SUBSCRIBER TYPES
// =============================================================================

/// Configuration options for Kafka consumer groups.
///
/// Consumer groups enable parallel consumption across multiple consumers.
/// Kafka automatically assigns partitions to group members and handles
/// rebalancing when members join or leave.
///
/// See [Consumer Group Configs](https://kafka.apache.org/documentation/#consumerconfigs).
pub type GroupOption {
  /// Maximum time between heartbeats before the coordinator considers
  /// this member dead and triggers a rebalance.
  /// Should be higher than `HeartbeatRate`.
  /// Maps to `session.timeout.ms`.
  SessionTimeout(Duration)
  /// Maximum time for all members to join after a rebalance is triggered.
  /// Should be high enough for slow consumers to complete processing.
  /// Maps to `rebalance.timeout.ms`.
  RebalanceTimeout(Duration)
  /// How often to send heartbeats to the group coordinator.
  /// Should be lower than `SessionTimeout / 3`.
  /// Maps to `heartbeat.interval.ms`.
  HeartbeatRate(Duration)
  /// Maximum number of rejoin attempts after being removed from the group.
  /// After this limit, the subscriber will crash.
  MaxRejoinAttempts(Int)
  /// Delay before attempting to rejoin after a failed attempt.
  RejoinDelay(Duration)
  /// How often to auto-commit offsets (if using auto-commit).
  /// Maps to `auto.commit.interval.ms`.
  OffsetCommitInterval(Duration)
  /// How long committed offsets are retained by the broker.
  /// After this time, offsets may be deleted if the group is inactive.
  /// Maps to `offsets.retention.minutes`.
  OffsetRetention(Duration)
}

/// A handle to a running consumer group subscriber.
///
/// Consumer groups provide automatic partition assignment, offset tracking,
/// and rebalancing when consumers join or leave. This is the recommended
/// way to consume messages for most use cases.
///
/// See [Consumer Groups](https://kafka.apache.org/documentation/#intro_consumers).
pub type GroupSubscriber {
  GroupSubscriber(pid: process.Pid, name: process.Name(GroupSubscriberMessage))
}

/// Internal message type for group subscriber.
pub type GroupSubscriberMessage

/// Action to return from a group subscriber callback after processing a message.
///
/// The callback controls whether to just acknowledge the message locally
/// or also commit the offset to Kafka for durability.
pub type GroupCallbackAction(state) {
  /// Acknowledge the message and continue with the new state.
  /// The offset is NOT committed to Kafka - use this for batching commits.
  /// If the consumer crashes, messages since the last commit will be redelivered.
  GroupAck(state)
  /// Acknowledge the message AND commit the offset to Kafka.
  /// Use this to ensure at-least-once delivery - the offset is persisted
  /// so messages won't be redelivered after a restart.
  GroupCommit(state)
}

// =============================================================================
// TOPIC SUBSCRIBER TYPES
// =============================================================================

/// Specifies which partitions to consume from for a topic subscriber.
///
/// Unlike group subscribers which have partitions assigned automatically,
/// topic subscribers give you direct control over partition selection.
pub type SubscribePartitions {
  /// Consume from specific partition numbers only.
  /// Use when you need fine-grained control (e.g., consuming partition 0 only).
  Partitions(List(Int))
  /// Consume from all partitions of the topic.
  /// The subscriber will automatically discover and consume from all partitions.
  AllPartitions
}

/// A handle to a running topic subscriber.
///
/// Topic subscribers provide low-level access to Kafka partitions without
/// consumer group coordination. Use this when you need:
/// - Direct partition assignment (not automatic rebalancing)
/// - Manual offset management
/// - Consuming the same partition from multiple processes
///
/// For most use cases, prefer `GroupSubscriber` which provides automatic
/// partition assignment and offset management.
pub type TopicSubscriber {
  TopicSubscriber(pid: process.Pid, name: process.Name(TopicSubscriberMessage))
}

/// Internal message type for topic subscriber.
/// This type is opaque and not intended for direct use.
pub type TopicSubscriberMessage

/// Action to return from a topic subscriber callback after processing a message.
///
/// Topic subscribers don't have built-in offset committing like group subscribers.
/// You're responsible for tracking offsets if you need to resume from failures.
pub type TopicCallbackAction(state) {
  /// Acknowledge the message and continue with the new state.
  /// The subscriber will proceed to the next message.
  TopicAck(state)
}

// =============================================================================
// CLIENT BUILDER
// =============================================================================

/// Builder for creating and configuring a Franz client.
///
/// Use the builder pattern to configure the client before starting it:
///
/// ```gleam
/// franz.client()
/// |> franz.endpoints([franz.Endpoint("localhost", 9092)])
/// |> franz.name(process.new_name("my_client"))
/// |> franz.start()
/// ```
pub type ClientConfig {
  ClientBuilder(
    name: process.Name(Message),
    endpoints: List(Endpoint),
    options: List(ClientOption),
  )
}

/// Creates a new client builder with default settings.
///
/// You must set at least one endpoint and a name before calling `start`.
pub fn default_client(name: process.Name(Message)) -> ClientConfig {
  ClientBuilder(endpoints: [], name:, options: [])
}

/// Adds a single broker endpoint to the client configuration.
///
/// The client uses bootstrap endpoints to discover the full cluster topology.
/// You only need to provide one or a few endpoints - the client will discover
/// all brokers automatically.
pub fn endpoint(builder: ClientConfig, endpoint: Endpoint) -> ClientConfig {
  ClientBuilder(..builder, endpoints: [endpoint, ..builder.endpoints])
}

/// Sets all broker endpoints for the client.
///
/// Replaces any previously configured endpoints.
pub fn endpoints(
  builder: ClientConfig,
  endpoints: List(Endpoint),
) -> ClientConfig {
  ClientBuilder(..builder, endpoints: endpoints)
}

/// Adds a configuration option to the client.
///
/// Options can be chained: `config |> option(Opt1) |> option(Opt2)`.
pub fn option(config: ClientConfig, opt: ClientOption) -> ClientConfig {
  ClientBuilder(..config, options: [opt, ..config.options])
}

/// Configures SASL authentication for the client.
///
/// Shorthand for `option(config, Sasl(credentials))`.
///
/// ```gleam
/// franz.client()
/// |> franz.sasl(franz.SaslCredentials(franz.ScramSha256, "user", "pass"))
/// ```
pub fn sasl(config: ClientConfig, credentials: SaslCredentials) -> ClientConfig {
  option(config, Sasl(credentials))
}

/// Configures SSL/TLS encryption for the client.
///
/// Shorthand for `option(config, Ssl(ssl_option))`.
///
/// ```gleam
/// franz.client()
/// |> franz.ssl(franz.SslEnabled)
/// ```
pub fn ssl(config: ClientConfig, ssl: SslOption) -> ClientConfig {
  option(config, Ssl(ssl))
}

/// Starts a new Franz client with the configured settings.
///
/// The client will connect to the Kafka cluster, discover broker metadata,
/// and be ready to produce or consume messages.
///
/// Returns `Error` if the client name is not set or connection fails.
///
/// ```gleam
/// let assert Ok(actor.Started(_, client)) =
///   franz.client()
///   |> franz.endpoints([franz.Endpoint("localhost", 9092)])
///   |> franz.name(process.new_name("my_client"))
///   |> franz.start()
/// ```
pub fn start(config: ClientConfig) -> actor.StartResult(Client) {
  let brod_options = list.map(config.options, client_option_to_brod)
  case do_start_client(config.endpoints, brod_options, config.name) {
    Ok(pid) -> Ok(actor.Started(pid, Client(config.name)))
    Error(error) -> Error(actor.InitExited(process.Abnormal(error)))
  }
}

@external(erlang, "franz_ffi", "start_client")
fn do_start_client(
  endpoints: List(Endpoint),
  options: List(BrodOption),
  name: process.Name(Message),
) -> Result(process.Pid, Dynamic)

/// Creates a child specification for supervising the Franz client.
///
/// Use with `gleam_otp` supervision trees:
///
/// ```gleam
/// let children = [franz.supervised(client_config)]
/// supervision.start(children)
/// ```
pub fn supervised(
  config: ClientConfig,
) -> supervision.ChildSpecification(Client) {
  supervision.worker(fn() { start(config) })
}

/// Gets a client reference from a registered process name.
///
/// Use this to access a client that was started with a specific name:
///
/// ```gleam
/// let name = process.new_name("my_client")
/// // ... start client with this name ...
/// let client = franz.named(name)
/// ```
pub fn named(name: process.Name(Message)) -> Client {
  Client(name)
}

/// Stops a running client and closes all connections.
///
/// This will also stop any producers associated with this client.
/// Consumers should be stopped separately before stopping the client.
@external(erlang, "franz_ffi", "stop_client")
pub fn stop(client: Client) -> Nil

// =============================================================================
// TOPIC ADMINISTRATION
// =============================================================================

/// Creates a new Kafka topic with the specified configuration.
///
/// Topics must be created before producing or consuming messages (unless
/// auto-creation is enabled on the broker).
///
/// See [Topic Configuration](https://kafka.apache.org/documentation/#topicconfigs).
///
/// ## Parameters
///
/// - `endpoints`: Bootstrap broker endpoints (only needs a few, not all brokers)
/// - `name`: Topic name (alphanumeric, dots, underscores, hyphens; max 249 chars)
/// - `partitions`: Number of partitions (determines parallelism)
/// - `replication_factor`: Number of replicas (must be <= number of brokers)
/// - `configs`: Topic-level configuration overrides (e.g., `[#("retention.ms", "86400000")]`)
/// - `timeout`: Request timeout
///
/// ```gleam
/// import gleam/time/duration
///
/// franz.create_topic(
///   endpoints: [franz.Endpoint("localhost", 9092)],
///   name: "user-events",
///   partitions: 12,
///   replication_factor: 3,
///   configs: [#("retention.ms", "604800000")],  // 7 days
///   timeout: duration.seconds(30),
/// )
/// ```
pub fn create_topic(
  endpoints endpoints: List(Endpoint),
  name name: String,
  partitions partitions: Int,
  replication_factor replication_factor: Int,
  configs configs: List(#(String, String)),
  timeout timeout: Duration,
) -> Result(Nil, TopicError) {
  do_create_topic(
    endpoints,
    name,
    partitions,
    replication_factor,
    configs,
    duration_to_ms(timeout),
  )
}

@external(erlang, "franz_ffi", "create_topic")
fn do_create_topic(
  endpoints: List(Endpoint),
  name: String,
  partitions: Int,
  replication_factor: Int,
  configs: List(#(String, String)),
  timeout_ms: Int,
) -> Result(Nil, TopicError)

/// Deletes one or more Kafka topics.
///
/// **Warning**: This permanently deletes all messages in the topics.
/// The operation cannot be undone.
///
/// Requires `delete.topic.enable=true` on the broker (default in recent versions).
pub fn delete_topics(
  endpoints endpoints: List(Endpoint),
  names names: List(String),
  timeout timeout: Duration,
) -> Result(Nil, TopicError) {
  do_delete_topics(endpoints, names, duration_to_ms(timeout))
}

@external(erlang, "franz_ffi", "delete_topics")
fn do_delete_topics(
  endpoints: List(Endpoint),
  names: List(String),
  timeout_ms: Int,
) -> Result(Nil, TopicError)

/// Lists all consumer groups on a broker.
///
/// Returns information about active consumer groups including their IDs
/// and protocol types.
///
/// Note: This queries a single broker. In a cluster, you may need to query
/// multiple brokers to get all groups.
@external(erlang, "franz_ffi", "list_groups")
pub fn list_groups(
  endpoint endpoint: Endpoint,
) -> Result(List(#(String, String)), GroupError)

// =============================================================================
// FETCH (Low-level)
// =============================================================================

/// Fetches messages directly from a topic-partition at a specific offset.
///
/// This is a low-level API for advanced use cases. For most consumption
/// needs, use `GroupSubscriber` or `TopicSubscriber` instead.
///
/// Returns a tuple of (next_offset, message_set) where next_offset is
/// the offset to use for the next fetch.
///
/// ```gleam
/// let assert Ok(#(next_offset, messages)) =
///   franz.fetch(
///     client: client,
///     topic: "my_topic",
///     partition: 0,
///     offset: 0,
///     options: [],
///   )
/// ```
pub fn fetch(
  client client: Client,
  topic topic: String,
  partition partition: Int,
  offset offset: Int,
  options options: List(FetchOption),
) -> Result(#(Int, KafkaMessage), FetchError) {
  let brod_options = list.map(options, fetch_option_to_brod)
  case do_fetch(client, topic, partition, offset, brod_options) {
    Ok(#(request_offset, raw_message_set)) -> {
      let #(message_set, next_offset) =
        convert_raw_message_set(raw_message_set, request_offset)
      Ok(#(next_offset, message_set))
    }
    Error(err) -> Error(err)
  }
}

/// Internal type for raw FFI result - #(topic, partition, high_wm_offset, raw_messages)
type RawMessageSet =
  #(String, Int, Int, List(Dynamic))

@external(erlang, "franz_ffi", "fetch")
fn do_fetch(
  client: Client,
  topic: String,
  partition: Int,
  offset: Int,
  options: List(BrodOption),
) -> Result(#(Int, RawMessageSet), FetchError)

/// Convert raw FFI message set to Gleam KafkaMessageSet and compute next offset in single pass
fn convert_raw_message_set(
  raw: RawMessageSet,
  fallback_offset: Int,
) -> #(KafkaMessage, Int) {
  let #(topic, partition, high_wm_offset, raw_messages) = raw
  // Single pass: decode messages and track last offset
  let #(messages_reversed, last_offset) =
    list.fold(raw_messages, #([], fallback_offset), fn(acc, raw_msg) {
      let #(msgs, current_offset) = acc
      case decode.run(raw_msg, decode_single_message()) {
        Ok(KafkaMessage(offset: msg_offset, ..) as msg) ->
          #([msg, ..msgs], msg_offset + 1)
        Ok(KafkaMessageSet(..) as msg) -> #([msg, ..msgs], current_offset)
        Error(_) -> acc
      }
    })
  let message_set =
    KafkaMessageSet(
      topic: topic,
      partition: partition,
      high_wm_offset: high_wm_offset,
      messages: list.reverse(messages_reversed),
    )
  #(message_set, last_offset)
}

/// Convert raw timestamp type atom to Gleam TimestampType
fn convert_timestamp_type(atom: atom.Atom) -> TimestampType {
  let name = atom.to_string(atom)
  case name {
    "create" -> Create
    "append" -> Append
    _ -> Undefined
  }
}

/// Convert milliseconds to Gleam Timestamp
fn timestamp_from_ms(ms: Int) -> Timestamp {
  let seconds = ms / 1000
  let nanos = { ms % 1000 } * 1_000_000
  timestamp.from_unix_seconds_and_nanoseconds(seconds, nanos)
}

/// Convert raw headers to list of key-value tuples
fn headers_decoder() -> decode.Decoder(List(#(String, BitArray))) {
  decode.list({
    use key <- decode.then(decode.at([0], decode.string))
    use value <- decode.then(decode.at([1], decode.bit_array))
    decode.success(#(key, value))
  })
}

// =============================================================================
// PRODUCER BUILDER
// =============================================================================

/// Builder for creating and configuring a Kafka producer.
///
/// Producers send messages to Kafka topics. Each producer is associated
/// with a specific topic and must be started before sending messages.
///
/// ```gleam
/// franz.producer(client, "my_topic")
/// |> franz.producer_option(franz.RequiredAcks(-1))
/// |> franz.producer_option(franz.Compression(franz.Snappy))
/// |> franz.producer_start()
/// ```
pub type Producer {
  Producer(client: Client, topic: String, options: List(ProducerOption))
}

/// Creates a new producer config for the specified topic.
///
/// The producer is not started until you call `producer_start`.
pub fn default_producer(client: Client, topic: String) -> Producer {
  Producer(client:, topic:, options: [])
}

@external(erlang, "franz_ffi", "start_producer")
fn do_start_producer(
  client: Client,
  topic: String,
  options: List(BrodOption),
) -> Result(Nil, ProduceError)

/// Starts the producer with the configured settings.
///
/// After starting, you can use `produce`, `produce_sync`, or `produce_async`
/// to send messages to the topic.
///
/// The producer will maintain connections to the partition leaders and
/// handle leader changes automatically.
pub fn start_producer(config: Producer) -> Result(Nil, ProduceError) {
  let brod_options = list.map(config.options, producer_option_to_brod)
  do_start_producer(config.client, config.topic, brod_options)
}

// =============================================================================
// PRODUCE FUNCTIONS
// =============================================================================

/// Produces a message without waiting for acknowledgement (fire and forget).
///
/// This provides the highest throughput but offers **at-most-once** delivery
/// semantics - messages may be lost if the broker fails.
///
/// Use when:
/// - Message loss is acceptable (e.g., metrics, logs)
/// - Maximum throughput is required
/// - You don't need delivery confirmation
///
/// The producer must be started with `start_producer` first.
pub fn produce(
  client client: Client,
  topic topic: String,
  partition partition: PartitionSelector,
  key key: BitArray,
  value value: ProduceValue,
) -> Result(Nil, ProduceError) {
  do_produce_no_ack(client, topic, partition, key, produce_value_to_brod(value))
}

@external(erlang, "franz_ffi", "produce_no_ack")
fn do_produce_no_ack(
  client: Client,
  topic: String,
  partition: PartitionSelector,
  key: BitArray,
  value: BrodValue,
) -> Result(Nil, ProduceError)

/// Produces a message and waits for broker acknowledgement.
///
/// This provides **at-least-once** delivery semantics - the message is
/// guaranteed to be written (according to `RequiredAcks` setting) before
/// returning, but duplicates are possible on retry.
///
/// Use when:
/// - You need confirmation that the message was written
/// - Message loss is not acceptable
/// - You can handle potential duplicates
///
/// ```gleam
/// franz.produce_sync(
///   client: client,
///   topic: "orders",
///   partition: franz.Partitioner(franz.Hash),
///   key: <<"order_123">>,
///   value: franz.Value(order_json, [#("type", "OrderCreated")]),
/// )
/// ```
pub fn produce_sync(
  client client: Client,
  topic topic: String,
  partition partition: PartitionSelector,
  key key: BitArray,
  value value: ProduceValue,
) -> Result(Nil, ProduceError) {
  do_produce_sync(client, topic, partition, key, produce_value_to_brod(value))
}

@external(erlang, "franz_ffi", "produce_sync")
fn do_produce_sync(
  client: Client,
  topic: String,
  partition: PartitionSelector,
  key: BitArray,
  value: BrodValue,
) -> Result(Nil, ProduceError)

/// Produces a message synchronously and returns the assigned offset.
///
/// Like `produce_sync` but also returns the offset where the message
/// was written. Useful when you need to track message positions.
///
/// ```gleam
/// let assert Ok(offset) =
///   franz.produce_sync_offset(client:, topic:, partition:, key:, value:)
/// io.println("Message written at offset: " <> int.to_string(offset))
/// ```
pub fn produce_sync_offset(
  client client: Client,
  topic topic: String,
  partition partition: PartitionSelector,
  key key: BitArray,
  value value: ProduceValue,
) -> Result(Int, ProduceError) {
  do_produce_sync_offset(
    client,
    topic,
    partition,
    key,
    produce_value_to_brod(value),
  )
}

@external(erlang, "franz_ffi", "produce_sync_offset")
fn do_produce_sync_offset(
  client: Client,
  topic: String,
  partition: PartitionSelector,
  key: BitArray,
  value: BrodValue,
) -> Result(Int, ProduceError)

/// Wrapper type for partition numbers in async produce callbacks.
pub type Partition {
  Partition(Int)
}

/// Wrapper type for message offsets in async produce callbacks.
pub type Offset {
  Offset(Int)
}

/// Produces a message asynchronously with a callback for acknowledgement.
///
/// The message is sent to the broker and the callback is invoked when
/// the broker acknowledges receipt. This provides **at-least-once** semantics
/// with better throughput than `produce_sync`.
///
/// Use when:
/// - You need delivery confirmation but want higher throughput
/// - You can process acknowledgements asynchronously
///
/// ```gleam
/// franz.produce_async(
///   client: client,
///   topic: "events",
///   partition: franz.SinglePartition(0),
///   key: <<"event_1">>,
///   value: franz.Value(payload, []),
///   callback: fn(partition, offset) {
///     io.println("Delivered to partition " <> int.to_string(partition.0))
///   },
/// )
/// ```
pub fn produce_async(
  client client: Client,
  topic topic: String,
  partition partition: PartitionSelector,
  key key: BitArray,
  value value: ProduceValue,
  callback callback: fn(Partition, Offset) -> any,
) -> Result(PartitionSelector, ProduceError) {
  do_produce_cb(
    client,
    topic,
    partition,
    key,
    produce_value_to_brod(value),
    callback,
  )
}

@external(erlang, "franz_ffi", "produce_cb")
fn do_produce_cb(
  client: Client,
  topic: String,
  partition: PartitionSelector,
  key: BitArray,
  value: BrodValue,
  callback: fn(Partition, Offset) -> any,
) -> Result(PartitionSelector, ProduceError)

// =============================================================================
// GROUP SUBSCRIBER CONFIG
// =============================================================================

/// Callback return type for group subscribers (internal).
type GroupCallbackReturn

/// Configuration for a Kafka consumer group subscriber.
///
/// Consumer groups provide automatic partition assignment across multiple
/// consumers, offset tracking, and rebalancing. This is the recommended
/// way to consume messages for most applications.
///
/// See [Consumer Groups](https://kafka.apache.org/documentation/#intro_consumers).
pub type GroupSubscriberConfig(state) {
  GroupSubscriberConfig(
    /// Registered process name for the subscriber.
    name: process.Name(GroupSubscriberMessage),
    /// Franz client for Kafka connections.
    client: Client,
    /// Consumer group ID. Consumers with the same group ID share partitions.
    group_id: String,
    /// Topics to subscribe to.
    topics: List(String),
    /// Whether to deliver single messages or batches.
    message_type: MessageType,
    /// Callback invoked for each message. Return `GroupAck` or `GroupCommit`.
    callback: fn(KafkaMessage, state) -> GroupCallbackAction(state),
    /// Initial state passed to the callback.
    init_state: state,
    /// Consumer group configuration options.
    group_options: List(GroupOption),
    /// Consumer fetch configuration options.
    consumer_options: List(ConsumerOption),
  )
}

/// Creates a new group subscriber configuration with default settings.
///
/// The subscriber will consume from all specified topics, with Kafka
/// automatically assigning partitions based on group membership.
///
/// ```gleam
/// let config =
///   franz.default_group_subscriber_config(
///     process.new_name("my_consumer"),
///     client: client,
///     group_id: "my-service-consumers",
///     topics: ["orders", "payments"],
///     callback: fn(msg, state) {
///       // Process message...
///       franz.GroupCommit(state)
///     },
///     init_state: MyState,
///   )
/// ```
pub fn default_group_subscriber_config(
  name: process.Name(GroupSubscriberMessage),
  client client: Client,
  group_id group_id: String,
  topics topics: List(String),
  callback callback: fn(KafkaMessage, state) -> GroupCallbackAction(state),
  init_state init_state: state,
) -> GroupSubscriberConfig(state) {
  GroupSubscriberConfig(
    name:,
    client:,
    group_id:,
    topics:,
    message_type: SingleMessage,
    callback:,
    init_state:,
    group_options: [],
    consumer_options: [],
  )
}

/// Internal helper to wrap user callback with GroupCallbackAction.
@external(erlang, "franz_ffi", "group_ack")
fn do_group_ack(state: state) -> GroupCallbackReturn

@external(erlang, "franz_ffi", "group_commit")
fn do_group_commit(state: state) -> GroupCallbackReturn

fn wrap_group_callback(
  user_callback: fn(KafkaMessage, state) -> GroupCallbackAction(state),
) -> fn(KafkaMessage, state) -> GroupCallbackReturn {
  fn(msg, state) {
    case user_callback(msg, state) {
      GroupAck(new_state) -> do_group_ack(new_state)
      GroupCommit(new_state) -> do_group_commit(new_state)
    }
  }
}

@external(erlang, "franz_ffi", "start_group_subscriber")
fn do_start_group_subscriber(
  client: Client,
  group_id: String,
  topics: List(String),
  consumer_options: List(BrodOption),
  group_options: List(BrodOption),
  message_type: MessageType,
  callback: fn(KafkaMessage, state) -> GroupCallbackReturn,
  init_state: state,
) -> Result(process.Pid, Dynamic)

/// Starts the group subscriber and begins consuming messages.
///
/// The subscriber will:
/// 1. Join the consumer group
/// 2. Receive partition assignments from Kafka
/// 3. Begin fetching and delivering messages to your callback
///
/// Returns the subscriber handle which can be used with `group_subscriber_stop`.
pub fn start_group_subscriber(
  config: GroupSubscriberConfig(state),
) -> actor.StartResult(GroupSubscriber) {
  let brod_consumer_options =
    list.map(config.consumer_options, consumer_option_to_brod)
  let brod_group_options = list.map(config.group_options, group_option_to_brod)
  case
    do_start_group_subscriber(
      config.client,
      config.group_id,
      config.topics,
      brod_consumer_options,
      brod_group_options,
      config.message_type,
      wrap_group_callback(config.callback),
      config.init_state,
    )
  {
    Ok(pid) -> {
      case process.register(pid, config.name) {
        Error(Nil) -> {
          let _ = do_stop_group_subscriber(pid)
          Error(
            actor.InitExited(
              process.Abnormal(dynamic.string("Name already registered")),
            ),
          )
        }
        Ok(_) -> Ok(actor.Started(pid, GroupSubscriber(pid, config.name)))
      }
    }
    Error(error) -> Error(actor.InitExited(process.Abnormal(error)))
  }
}

@external(erlang, "franz_ffi", "stop_group_subscriber")
fn do_stop_group_subscriber(pid: process.Pid) -> Result(Nil, GroupError)

/// Stops a running group subscriber.
///
/// This will gracefully shut down the subscriber, leaving the consumer group
/// and committing any pending offsets (if auto-commit is enabled).
///
/// ```gleam
/// let assert Ok(_) = franz.group_subscriber_stop(subscriber)
/// ```
pub fn group_subscriber_stop(
  subscriber: GroupSubscriber,
) -> Result(Nil, GroupError) {
  let GroupSubscriber(pid, name) = subscriber
  let _ = process.unregister(name)
  do_stop_group_subscriber(pid)
}

/// Creates a child specification for supervising the group subscriber.
///
/// Use with `gleam_otp` supervision trees for automatic restart on failure:
///
/// ```gleam
/// let children = [
///   franz.group_subscriber_supervised(subscriber_config),
/// ]
/// supervision.start(children)
/// ```
pub fn group_subscriber_supervised(
  config: GroupSubscriberConfig(state),
) -> supervision.ChildSpecification(GroupSubscriber) {
  supervision.worker(fn() { start_group_subscriber(config) })
}

// =============================================================================
// TOPIC SUBSCRIBER
// =============================================================================

/// Callback return type for topic subscribers (internal).
type TopicSubscriberCallbackReturn

/// Configuration for a Kafka topic subscriber.
///
/// Topic subscribers provide low-level access to Kafka partitions without
/// consumer group coordination. Use this when you need direct control over
/// partition assignment and offset management.
///
/// For most use cases, prefer `GroupSubscriberConfig` which provides
/// automatic partition assignment and offset tracking.
pub type TopicSubscriberConfig(state) {
  TopicSubscriberConfig(
    /// Registered process name for the subscriber.
    name: process.Name(TopicSubscriberMessage),
    /// Franz client for Kafka connections.
    client: Client,
    /// Topic to subscribe to.
    topic: String,
    /// Which partitions to consume from.
    partitions: SubscribePartitions,
    /// Starting offsets for each partition as `#(partition, offset)` tuples.
    /// Partitions not listed will use the `BeginOffset` consumer option.
    committed_offsets: List(#(Int, Int)),
    /// Whether to deliver single messages or batches.
    message_type: MessageType,
    /// Callback invoked for each message. Receives partition number and message.
    callback: fn(Int, KafkaMessage, state) -> TopicCallbackAction(state),
    /// Initial state passed to the callback.
    initial_state: state,
    /// Consumer fetch configuration options.
    consumer_options: List(ConsumerOption),
  )
}

/// Creates a new topic subscriber configuration with default settings.
///
/// The callback receives the partition number along with each message,
/// allowing you to handle messages differently based on partition.
///
/// ```gleam
/// let config =
///   franz.default_topic_subscriber(
///     process.new_name("my_subscriber"),
///     client: client,
///     topic: "events",
///     callback: fn(partition, msg, state) {
///       io.println("Partition " <> int.to_string(partition))
///       franz.TopicAck(state)
///     },
///     initial_state: Nil,
///   )
/// ```
pub fn default_topic_subscriber(
  name: process.Name(TopicSubscriberMessage),
  client client: Client,
  topic topic: String,
  callback callback: fn(Int, KafkaMessage, state) -> TopicCallbackAction(state),
  initial_state initial_state: state,
) -> TopicSubscriberConfig(state) {
  TopicSubscriberConfig(
    name:,
    client:,
    topic:,
    partitions: AllPartitions,
    committed_offsets: [],
    message_type: SingleMessage,
    callback:,
    initial_state:,
    consumer_options: [],
  )
}

/// Internal helper to wrap user callback with TopicCallbackAction.
@external(erlang, "franz_ffi", "topic_ack")
fn do_topic_ack(state: state) -> TopicSubscriberCallbackReturn

fn wrap_topic_callback(
  user_callback: fn(Int, KafkaMessage, state) -> TopicCallbackAction(state),
) -> fn(Int, Dynamic, state) -> TopicSubscriberCallbackReturn {
  fn(partition, raw_msg, state) {
    // Convert raw brod kafka_message to proper Gleam KafkaMessage
    let msg = convert_subscriber_message(raw_msg)
    case user_callback(partition, msg, state) {
      TopicAck(new_state) -> do_topic_ack(new_state)
    }
  }
}

/// Convert raw brod message (single or batch) to proper Gleam KafkaMessage
fn convert_subscriber_message(raw: Dynamic) -> KafkaMessage {
  let decoder = decode.one_of(decode_single_message(), [decode_message_set()])
  let assert Ok(msg) = decode.run(raw, decoder)
    as "Failed to decode Kafka message: unexpected format from brod"
  msg
}

/// Decode a single kafka_message record
/// brod format: {kafka_message, Offset, Key, Value, TsType, Ts, Headers}
/// Tuple indices: 0=tag, 1=offset, 2=key, 3=value, 4=ts_type, 5=ts, 6=headers
fn decode_single_message() {
  use offset <- decode.subfield([1], decode.int)
  use key <- decode.subfield([2], decode.bit_array)
  use value <- decode.subfield([3], decode.bit_array)
  use timestamp_type <- decode.subfield(
    [4],
    atom.decoder() |> decode.map(convert_timestamp_type),
  )
  use timestamp <- decode.subfield(
    [5],
    decode.int |> decode.map(timestamp_from_ms),
  )
  use headers <- decode.subfield([6], headers_decoder())

  decode.success(KafkaMessage(
    offset:,
    key:,
    value:,
    timestamp_type:,
    timestamp:,
    headers:,
  ))
}

/// Decode a message_set record (batch)
/// brod format: {kafka_message_set, Topic, Partition, HighWmOffset, Messages}
/// Tuple indices: 0=tag, 1=topic, 2=partition, 3=high_wm_offset, 4=messages
fn decode_message_set() {
  use topic <- decode.subfield([1], decode.string)
  use partition <- decode.subfield([2], decode.int)
  use high_wm_offset <- decode.subfield([3], decode.int)
  use messages <- decode.subfield([4], decode.list(decode_single_message()))

  decode.success(KafkaMessageSet(
    topic: topic,
    partition: partition,
    high_wm_offset: high_wm_offset,
    messages: messages,
  ))
}

@external(erlang, "franz_ffi", "start_topic_subscriber")
fn do_start_topic_subscriber(
  client: Client,
  topic: String,
  partitions: SubscribePartitions,
  consumer_options: List(BrodOption),
  committed_offsets: List(#(Int, Int)),
  message_type: MessageType,
  callback: fn(Int, Dynamic, state) -> TopicSubscriberCallbackReturn,
  init_state: state,
) -> Result(process.Pid, Dynamic)

/// Starts the topic subscriber and begins consuming messages.
///
/// The subscriber will immediately begin fetching messages from the
/// configured partitions at the specified offsets (or using `BeginOffset`).
///
/// Unlike group subscribers, topic subscribers don't coordinate with
/// other consumers - each subscriber independently consumes from its
/// assigned partitions.
pub fn start_topic_subscriber(
  builder: TopicSubscriberConfig(state),
) -> actor.StartResult(TopicSubscriber) {
  let brod_consumer_options =
    list.map(builder.consumer_options, consumer_option_to_brod)
  case
    do_start_topic_subscriber(
      builder.client,
      builder.topic,
      builder.partitions,
      brod_consumer_options,
      builder.committed_offsets,
      builder.message_type,
      wrap_topic_callback(builder.callback),
      builder.initial_state,
    )
  {
    Ok(pid) -> {
      case process.register(pid, builder.name) {
        Error(Nil) -> {
          let _ = do_stop_topic_subscriber(pid)
          Error(
            actor.InitExited(
              process.Abnormal(dynamic.string("Name already registered")),
            ),
          )
        }
        Ok(_) -> Ok(actor.Started(pid, TopicSubscriber(pid, builder.name)))
      }
    }
    Error(error) -> Error(actor.InitExited(process.Abnormal(error)))
  }
}

@external(erlang, "franz_ffi", "stop_topic_subscriber")
fn do_stop_topic_subscriber(pid: process.Pid) -> Result(Nil, Nil)

/// Stops a running topic subscriber.
///
/// This will gracefully shut down the subscriber and stop consuming messages
/// from the topic partitions.
///
/// ```gleam
/// let assert Ok(_) = franz.topic_subscriber_stop(subscriber)
/// ```
pub fn topic_subscriber_stop(subscriber: TopicSubscriber) -> Result(Nil, Nil) {
  let TopicSubscriber(pid, name) = subscriber
  let _ = process.unregister(name)
  do_stop_topic_subscriber(pid)
}

/// Creates a child specification for supervising the topic subscriber.
///
/// Use with `gleam_otp` supervision trees for automatic restart on failure:
///
/// ```gleam
/// let children = [
///   franz.topic_subscriber_supervised(subscriber_config),
/// ]
/// supervision.start(children)
/// ```
///
/// For dynamic subscriber management, consider using `factory_supervisor`
/// from `gleam_otp` to spawn subscribers on demand.
pub fn topic_subscriber_supervised(
  builder: TopicSubscriberConfig(state),
) -> supervision.ChildSpecification(TopicSubscriber) {
  supervision.worker(fn() { start_topic_subscriber(builder) })
}

// =============================================================================
// INTERNAL HELPERS
// =============================================================================

/// Converts a Duration to milliseconds (Int) for FFI calls.
fn duration_to_ms(d: Duration) -> Int {
  let #(seconds, nanos) = duration.to_seconds_and_nanoseconds(d)
  seconds * 1000 + nanos / 1_000_000
}

/// Converts a Duration to seconds (Int) for FFI calls.
fn duration_to_seconds(d: Duration) -> Int {
  let #(seconds, _) = duration.to_seconds_and_nanoseconds(d)
  seconds
}

/// Converts a Timestamp to milliseconds since epoch (Int) for FFI calls.
fn timestamp_to_ms(ts: Timestamp) -> Int {
  let #(seconds, nanos) = timestamp.to_unix_seconds_and_nanoseconds(ts)
  seconds * 1000 + nanos / 1_000_000
}

// =============================================================================
// BROD FFI CONVERSION UTILITIES
// =============================================================================

// BrodOption is an opaque type representing Erlang option tuples like {key, value}
type BrodOption

/// Coerces any value to BrodOption - this is safe because BrodOption is just
/// a type-level marker and at runtime these are regular Erlang terms.
@external(erlang, "gleam@function", "identity")
fn to_brod_option(value: a) -> BrodOption

// BrodValue is an opaque type representing the Erlang map #{value => ..., headers => ..., ts => ...}
type BrodValue

/// Creates a brod-compatible value map without timestamp.
@external(erlang, "franz_ffi", "make_value")
fn make_value(value: BitArray, headers: List(#(String, BitArray))) -> BrodValue

/// Creates a brod-compatible value map with timestamp in milliseconds.
@external(erlang, "franz_ffi", "make_value_with_ts")
fn make_value_with_ts(
  value: BitArray,
  ts_ms: Int,
  headers: List(#(String, BitArray)),
) -> BrodValue

fn produce_value_to_brod(val: ProduceValue) -> BrodValue {
  case val {
    Value(v, h) -> make_value(v, h)
    ValueWithTimestamp(v, ts, h) ->
      make_value_with_ts(v, timestamp_to_ms(ts), h)
  }
}

fn client_option_to_brod(opt: ClientOption) -> BrodOption {
  case opt {
    Sasl(creds) -> to_brod_option(#(atom.create("sasl"), sasl_to_brod(creds)))
    Ssl(ssl) -> to_brod_option(#(atom.create("ssl"), ssl_to_brod(ssl)))
    ConnectTimeout(d) ->
      to_brod_option(#(atom.create("connect_timeout"), duration_to_ms(d)))
    RequestTimeout(d) ->
      to_brod_option(#(atom.create("request_timeout"), duration_to_ms(d)))
    RestartDelay(d) ->
      to_brod_option(#(
        atom.create("restart_delay_seconds"),
        duration_to_seconds(d),
      ))
    ReconnectCoolDown(d) ->
      to_brod_option(#(
        atom.create("reconnect_cool_down_seconds"),
        duration_to_seconds(d),
      ))
    AllowTopicAutoCreation(b) ->
      to_brod_option(#(atom.create("allow_topic_auto_creation"), b))
    AutoStartProducers(b) ->
      to_brod_option(#(atom.create("auto_start_producers"), b))
    DefaultProducerConfig(opts) ->
      to_brod_option(#(
        atom.create("default_producer_config"),
        list.map(opts, producer_option_to_brod),
      ))

    UnknownTopicCacheTtl(d) ->
      to_brod_option(#(
        atom.create("topic_metadata_refresh_interval_seconds"),
        duration_to_seconds(d),
      ))
  }
}

fn sasl_to_brod(creds: SaslCredentials) -> #(atom.Atom, String, String) {
  let SaslCredentials(mechanism, username, password) = creds
  let mech_atom = case mechanism {
    Plain -> atom.create("plain")
    ScramSha256 -> atom.create("scram_sha_256")
    ScramSha512 -> atom.create("scram_sha_512")
  }
  #(mech_atom, username, password)
}

fn ssl_to_brod(ssl: SslOption) -> BrodOption {
  case ssl {
    SslEnabled -> to_brod_option(True)
    SslWithOptions(cacertfile, certfile, keyfile, verify) -> {
      let verify_atom = case verify {
        VerifyPeer -> atom.create("verify_peer")
        VerifyNone -> atom.create("verify_none")
      }
      let options = [to_brod_option(#(atom.create("verify"), verify_atom))]
      let options = case keyfile {
        option.Some(path) -> [
          to_brod_option(#(atom.create("keyfile"), path)),
          ..options
        ]
        option.None -> options
      }
      let options = case certfile {
        option.Some(path) -> [
          to_brod_option(#(atom.create("certfile"), path)),
          ..options
        ]
        option.None -> options
      }
      let options = case cacertfile {
        option.Some(path) -> [
          to_brod_option(#(atom.create("cacertfile"), path)),
          ..options
        ]
        option.None -> options
      }
      to_brod_option(options)
    }
  }
}

fn compression_to_brod(c: Compression) -> atom.Atom {
  case c {
    NoCompression -> atom.create("no_compression")
    Gzip -> atom.create("gzip")
    Snappy -> atom.create("snappy")
    Lz4 -> atom.create("lz4")
  }
}

fn producer_option_to_brod(opt: ProducerOption) -> BrodOption {
  case opt {
    RequiredAcks(n) -> to_brod_option(#(atom.create("required_acks"), n))
    AckTimeout(d) ->
      to_brod_option(#(atom.create("ack_timeout"), duration_to_ms(d)))
    PartitionBufferLimit(n) ->
      to_brod_option(#(atom.create("partition_buffer_limit"), n))
    PartitionOnWireLimit(n) ->
      to_brod_option(#(atom.create("partition_onwire_limit"), n))
    MaxBatchSize(n) -> to_brod_option(#(atom.create("max_batch_size"), n))
    MaxRetries(n) -> to_brod_option(#(atom.create("max_retries"), n))
    RetryBackoff(d) ->
      to_brod_option(#(atom.create("retry_backoff_ms"), duration_to_ms(d)))
    Compression(c) ->
      to_brod_option(#(atom.create("compression"), compression_to_brod(c)))
    MaxLinger(d) ->
      to_brod_option(#(atom.create("max_linger_ms"), duration_to_ms(d)))
    MaxLingerCount(n) -> to_brod_option(#(atom.create("max_linger_count"), n))
  }
}

fn starting_offset_to_brod(offset: StartingOffset) -> BrodOption {
  case offset {
    Latest -> to_brod_option(atom.create("latest"))
    Earliest -> to_brod_option(atom.create("earliest"))
    AtTimestamp(ts) -> to_brod_option(timestamp_to_ms(ts))
    AtOffset(n) -> to_brod_option(n)
  }
}

fn offset_reset_policy_to_brod(policy: OffsetResetPolicy) -> atom.Atom {
  case policy {
    ResetBySubscriber -> atom.create("reset_by_subscriber")
    ResetToEarliest -> atom.create("reset_to_earliest")
    ResetToLatest -> atom.create("reset_to_latest")
  }
}

fn isolation_level_to_brod(level: IsolationLevel) -> atom.Atom {
  case level {
    ReadCommitted -> atom.create("read_committed")
    ReadUncommitted -> atom.create("read_uncommitted")
  }
}

fn consumer_option_to_brod(opt: ConsumerOption) -> BrodOption {
  case opt {
    BeginOffset(offset) ->
      to_brod_option(#(
        atom.create("begin_offset"),
        starting_offset_to_brod(offset),
      ))

    MinBytes(n) -> to_brod_option(#(atom.create("min_bytes"), n))
    MaxBytes(n) -> to_brod_option(#(atom.create("max_bytes"), n))
    MaxWaitTime(d) ->
      to_brod_option(#(atom.create("max_wait_time"), duration_to_ms(d)))
    SleepTimeout(d) ->
      to_brod_option(#(atom.create("sleep_timeout"), duration_to_ms(d)))
    PrefetchCount(n) -> to_brod_option(#(atom.create("prefetch_count"), n))
    PrefetchBytes(n) -> to_brod_option(#(atom.create("prefetch_bytes"), n))
    OffsetResetPolicy(p) ->
      to_brod_option(#(
        atom.create("offset_reset_policy"),
        offset_reset_policy_to_brod(p),
      ))
    SizeStatWindow(n) -> to_brod_option(#(atom.create("size_stat_window"), n))
    ConsumerIsolationLevel(l) ->
      to_brod_option(#(
        atom.create("isolation_level"),
        isolation_level_to_brod(l),
      ))
    ShareLeaderConn(b) -> to_brod_option(#(atom.create("share_leader_conn"), b))
  }
}

fn group_option_to_brod(opt: GroupOption) -> BrodOption {
  case opt {
    SessionTimeout(d) ->
      to_brod_option(#(
        atom.create("session_timeout_seconds"),
        duration_to_seconds(d),
      ))

    RebalanceTimeout(d) ->
      to_brod_option(#(
        atom.create("rebalance_timeout_seconds"),
        duration_to_seconds(d),
      ))

    HeartbeatRate(d) ->
      to_brod_option(#(
        atom.create("heartbeat_rate_seconds"),
        duration_to_seconds(d),
      ))

    MaxRejoinAttempts(n) ->
      to_brod_option(#(atom.create("max_rejoin_attempts"), n))

    RejoinDelay(d) ->
      to_brod_option(#(
        atom.create("rejoin_delay_seconds"),
        duration_to_seconds(d),
      ))

    OffsetCommitInterval(d) ->
      to_brod_option(#(
        atom.create("offset_commit_interval_seconds"),
        duration_to_seconds(d),
      ))

    OffsetRetention(d) ->
      to_brod_option(#(
        atom.create("offset_retention_seconds"),
        duration_to_seconds(d),
      ))
  }
}

fn fetch_option_to_brod(opt: FetchOption) -> BrodOption {
  case opt {
    FetchMaxWaitTime(d) ->
      to_brod_option(#(atom.create("max_wait_time"), duration_to_ms(d)))
    FetchMinBytes(n) -> to_brod_option(#(atom.create("min_bytes"), n))
    FetchMaxBytes(n) -> to_brod_option(#(atom.create("max_bytes"), n))
    FetchIsolationLevel(l) ->
      to_brod_option(#(
        atom.create("isolation_level"),
        isolation_level_to_brod(l),
      ))
  }
}
