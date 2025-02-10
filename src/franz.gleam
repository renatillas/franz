import gleam/erlang/process.{type Pid}

pub type FranzError {
  UnknownError
  ClientDown
  UnknownTopicOrPartition
  ProducerDown
  TopicAlreadyExists
  ConsumerNotFound(String)
  ProducerNotFound(String, Int)
}

pub type FranzClient

pub type Partition =
  Int

pub type Offset =
  Int

pub type Topic =
  String

pub type Ack

pub type Commit

pub type AckOrCommit(callback_state)

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
    topic: Topic,
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

pub type ConsumerConfig {
  BeginOffset(OffsetTime)
  MinBytes(Int)
  MaxBytes(Int)
  MaxWaitTime(Int)
  SleepTimeout(Int)
  PrefetchCount(Int)
  PrefetchBytes(Int)
  OffsetResetPolicy(OffsetResetPolicy)
  SizeStatWindow(Int)
  IsolationLevel(IsolationLevel)
  ShareLeaderConn(Bool)
}

pub type GroupConfig {
  SessionTimeoutSeconds(Int)
  RebalanceTimeoutSeconds(Int)
  HeartbeatRateSeconds(Int)
  MaxRejoinAttempts(Int)
  RejoinDelaySeconds(Int)
  OffsetCommitIntervalSeconds(Int)
  OffsetRetentionSeconds(Int)
}

pub type OffsetTime {
  Earliest
  Latest
  MessageTimestamp(Int)
}

pub type IsolationLevel {
  ReadCommitted
  ReadUncommitted
}

pub type OffsetResetPolicy {
  ResetBySubscriber
  ResetToEarliest
  ResetToLatest
}

pub type ClientConfig {
  RestartDelaySeconds(Int)
  GetMetadataTimeoutSeconds(Int)
  ReconnectCoolDownSeconds(Int)
  AllowTopicAutoCreation(Bool)
  AutoStartProducers(Bool)
  DefaultProducerConfig(List(ProducerConfig))
  UnknownTopicCacheTtl(Int)
}

pub type ProducerConfig {
  RequiredAcks(Int)
  AckTimeout(Int)
  PartitionBufferLimit(Int)
  PartitionOnwireLimit(Int)
  MaxBatchSize(Int)
  MaxRetries(Int)
  RetryBackoffMs(Int)
  Compression(Compression)
  MaxLingerMs(Int)
  MaxLingerCount(Int)
}

pub type Compression {
  NoCompression
  Gzip
  Snappy
}

pub type ProducerPartition {
  Partition(Int)
  Partitioner(Partitioner)
}

pub type Partitioner {
  PartitionFun(fn(String, Int, BitArray, BitArray) -> Result(Int, Nil))
  Random
  Hash
}

pub type Value {
  Value(value: BitArray, headers: List(#(String, String)))
  ValueWithTimestamp(
    value: BitArray,
    timestamp: Int,
    headers: List(#(String, String)),
  )
}

pub type ConsumerPartition {
  ConsumerPartitions(List(Int))
  All
}

pub type MessageType {
  Message
  MessageSet
}

@external(erlang, "franz_ffi", "start_client")
pub fn start_client(
  bootstrap_endpoints: List(#(String, Int)),
  client_config: List(ClientConfig),
) -> Result(FranzClient, FranzError)

@external(erlang, "franz_ffi", "produce_sync_offset")
pub fn produce_sync_offset(
  client: FranzClient,
  topic: Topic,
  partition: ProducerPartition,
  key: BitArray,
  value: Value,
) -> Result(Int, FranzError)

@external(erlang, "franz_ffi", "produce_sync")
pub fn produce_sync(
  client: FranzClient,
  topic: Topic,
  partition: ProducerPartition,
  key: BitArray,
  value: Value,
) -> Result(Nil, FranzError)

@external(erlang, "franz_ffi", "produce")
pub fn produce(
  client: FranzClient,
  topic: Topic,
  partition: ProducerPartition,
  key: BitArray,
  value: Value,
) -> Result(Nil, FranzError)

@external(erlang, "franz_ffi", "create_topic")
pub fn create_topic(
  bootstrap_endpoints: List(#(String, Int)),
  topic: Topic,
  partitions: Partition,
  replication_factor: Int,
) -> Result(Nil, FranzError)

@external(erlang, "franz_ffi", "start_topic_subscriber")
pub fn start_topic_subscriber(
  client: FranzClient,
  topic: Topic,
  partitions: ConsumerPartition,
  consumer_config: List(ConsumerConfig),
  commited_offsets_by_partition: List(#(Partition, Offset)),
  message_type: MessageType,
  callback: fn(Int, KafkaMessage, cb_state) -> AckOrCommit(Ack),
  init_callback_state: cb_state,
) -> Result(Pid, FranzError)

@external(erlang, "franz_ffi", "ack_return")
pub fn ack_return(cb_state: cb_state) -> AckOrCommit(Ack)

@external(erlang, "franz_ffi", "commit_return")
pub fn commit_return(cb_state: cb_state) -> AckOrCommit(Commit)

@external(erlang, "franz_ffi", "start_consumer")
pub fn start_consumer(
  client: FranzClient,
  topic: String,
  options: List(ConsumerConfig),
) -> Result(Nil, FranzError)

@external(erlang, "franz_ffi", "stop_client")
pub fn stop_client(client: FranzClient) -> Nil

@external(erlang, "franz_ffi", "produce_cb")
pub fn produce_cb(
  client: FranzClient,
  topic: Topic,
  partition: ProducerPartition,
  key: BitArray,
  value: Value,
  callback: fn(Partition, Offset) -> any,
) -> Result(Int, FranzError)

@external(erlang, "franz_ffi", "fetch")
pub fn fetch(
  client: FranzClient,
  topic: Topic,
  partition: Partition,
  offset: Offset,
) -> Result(#(Offset, KafkaMessage), FranzError)

@external(erlang, "franz_ffi", "start_group_subscriber")
pub fn start_group_subscriber(
  client: FranzClient,
  group_id: String,
  topics: List(Topic),
  consumer_config: List(ConsumerConfig),
  group_config: List(GroupConfig),
  message_type: MessageType,
  callback: fn(KafkaMessage, cb_init_state) -> AckOrCommit(ack_or_commit),
  init_callback_state: cb_state,
) -> Result(Pid, FranzError)
