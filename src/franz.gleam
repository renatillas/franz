import franz/isolation_level
import franz/producer_config

pub type FranzClient

pub type FranzError {
  UnknownError
  ClientDown
  UnknownTopicOrPartition
  ProducerDown
  TopicAlreadyExists
  ConsumerNotFound(String)
  ProducerNotFound(String, Int)
  OffsetOutOfRange
}

pub type KafkaMessage {
  KafkaMessage(
    offset: Int,
    key: BitArray,
    value: BitArray,
    timestamp_type: TimeStampType,
    timestamp: Int,
    headers: List(#(String, String)),
  )
  KafkaMessageSet(
    topic: String,
    partition: Int,
    high_wm_offset: Int,
    messages: List(KafkaMessage),
  )
}

pub type TimeStampType {
  Undefined
  Create
  Append
}

pub type Endpoint {
  Endpoint(host: String, port: Int)
}

pub type FetchOption {
  /// The maximum time (in millis) to block wait until there are enough messages that have in sum at least min_bytes bytes.
  /// The waiting will end as soon as either min_bytes is satisfied or max_wait_time is exceeded, whichever comes first.
  /// Defaults to 1 second.
  MaxWaitTime(Int)
  /// The minimum size of the message set. If it there are not enough messages, Kafka will block wait (but at most for max_wait_time).
  /// This implies that the response may be actually smaller in case the time runs out. If you set it to 0, Kafka will respond immediately (possibly with an empty message set).
  /// You can use this option together with max_wait_time to configure throughput, latency, and size of message sets. 
  /// Defaults to 0.
  MinBytes(Int)
  /// The maximum size of the message set. 
  /// Note that this is not an absolute maximum, if the first message in the message set is larger than this value, the message will still be returned to ensure that progress can be made.
  /// Defaults to 1 MB.
  MaxBytes(Int)
  /// This setting controls the visibility of transactional records.
  /// Using read_uncommitted makes all records visible. With read_committed, non-transactional and committed transactional records are visible.
  /// To be more concrete, read_committed returns all data from offsets smaller than the current LSO (last stable offset), and enables the inclusion of the list of aborted transactions in the result, which allows consumers to discard aborted transactional records.
  /// Defaults to read_committed.
  IsolationLevel(isolation_level.IsolationLevel)
}

pub type ClientConfig {
  /// How long to wait between attempts to restart FranzClient process when it crashes.
  /// Default: 10 seconds
  RestartDelaySeconds(Int)
  /// Delay this configured number of seconds before retrying to establish a new connection to the kafka partition leader.
  /// Default: 1 second
  ReconnectCoolDownSeconds(Int)
  /// By default, Franz respects what is configured in the broker about topic auto-creation. i.e. whether auto.create.topics.enable is set in the broker configuration.
  /// However if allow_topic_auto_creation is set to false in client config, Franz will avoid sending metadata requests that may cause an auto-creation of the topic regardless of what broker config is.
  /// Default: true
  AllowTopicAutoCreation(Bool)
  /// If true, Franz client will spawn a producer automatically when user is trying to call produce but did not call Franz.start_client() explicitly. 
  /// Can be useful for applications which don't know beforehand which topics they will be working with.
  /// Default: false
  AutoStartProducers(Bool)
  /// Producer configuration to use when auto_start_producers is true.
  /// Default: []
  DefaultProducerConfig(List(producer_config.ProducerConfig))
  /// For how long unknown_topic error will be cached, in ms.
  /// Default: 120000
  UnknownTopicCacheTtl(Int)
}

pub type ConsumerGroup {
  ConsumerGroup(group_id: String, protocol_type: String)
}

pub opaque type ClientBuilder {
  ClientBuilder(bootstrap_endpoints: List(Endpoint), config: List(ClientConfig))
}

@external(erlang, "franz_ffi", "start_client")
fn do_start(
  bootstrap_endpoints: List(Endpoint),
  client_config: List(ClientConfig),
) -> Result(FranzClient, FranzError)

/// Create a new client builder with the given bootstrap endpoints.
pub fn new(bootstrap_endpoints: List(Endpoint)) -> ClientBuilder {
  ClientBuilder(bootstrap_endpoints, [])
}

/// Add a client configuration to the client builder.
pub fn with_config(
  client_builder: ClientBuilder,
  client_config: ClientConfig,
) -> ClientBuilder {
  ClientBuilder(..client_builder, config: [
    client_config,
    ..client_builder.config
  ])
}

/// Start a new client with the given configuration.
pub fn start(client_builder: ClientBuilder) -> Result(FranzClient, FranzError) {
  do_start(client_builder.bootstrap_endpoints, client_builder.config)
}

/// Stops a client.
@external(erlang, "franz_ffi", "stop_client")
pub fn stop_client(client: FranzClient) -> Nil

/// Create a new topic with the given number of partitions and replication factor.
@external(erlang, "franz_ffi", "create_topic")
pub fn create_topic(
  endpoints endpoints: List(Endpoint),
  name name: String,
  partitions partitions: Int,
  replication_factor replication_factor: Int,
  configs configs: List(#(String, String)),
  timeout_ms timeout: Int,
) -> Result(Nil, FranzError)

/// Fetch a single message set from the given topic-partition.
/// On success, the function returns the messages along with the last stable offset (when using ReadCommited mode, the last committed offset) or the high watermark offset (offset of the last message that was successfully copied to all replicas, incremented by 1), whichever is lower. 
/// In essence, this is the offset up to which it was possible to read the messages at the time of fetching
@external(erlang, "franz_ffi", "fetch")
pub fn fetch(
  client client: FranzClient,
  topic topic: String,
  partition partition: Int,
  offset offset: Int,
  options fetch_options: List(FetchOption),
) -> Result(#(Int, KafkaMessage), FranzError)

@external(erlang, "franz_ffi", "delete_topics")
pub fn delete_topics(
  endpoints endpoints: List(Endpoint),
  names names: List(String),
  timeout_ms timeout: Int,
) -> Result(Nil, FranzError)
