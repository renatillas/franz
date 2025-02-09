import gleam/dynamic
import gleam/erlang/process.{type Pid, type Subject}
import gleam/io
import gleam/otp/task

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

pub type Ack

pub type KafkaMessage {
  KafkaMessage(
    offset: Int,
    key: BitArray,
    value: BitArray,
    timestamp_type: TimeStampType,
    timestamp: Int,
    headers: List(#(String, String)),
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

@external(erlang, "franz_ffi", "start_client")
pub fn start_client(
  bootstrap_endpoints: List(#(String, Int)),
  client_config: List(ClientConfig),
) -> Result(FranzClient, FranzError)

@external(erlang, "franz_ffi", "produce_sync_offset")
pub fn produce_sync_offset(
  client: FranzClient,
  topic: String,
  partition: Int,
  key: BitArray,
  value: BitArray,
) -> Result(Int, FranzError)

@external(erlang, "franz_ffi", "produce_sync_offset")
pub fn produce_sync(
  client: FranzClient,
  topic: String,
  partition: Int,
  key: BitArray,
  value: BitArray,
) -> Result(Nil, FranzError)

@external(erlang, "franz_ffi", "create_topic")
pub fn create_topic(
  bootstrap_endpoints: List(#(String, Int)),
  topic: String,
  partitions: Int,
  replication_factor: Int,
) -> Result(Nil, FranzError)

@external(erlang, "franz_ffi", "start_topic_subscriber")
pub fn start_topic_subscriber(
  client: FranzClient,
  topic: String,
  partitions: List(Int),
  callback: fn(Int, message, callback_state) -> Ack,
) -> Result(Pid, FranzError)

@external(erlang, "franz_ffi", "example")
pub fn example() -> dynamic.Dynamic

@external(erlang, "franz_ffi", "ack")
pub fn ack(pid: Pid) -> Ack

@external(erlang, "franz_ffi", "start_consumer")
pub fn start_consumer(
  client: FranzClient,
  topic: String,
  options: List(ConsumerConfig),
) -> Result(Nil, FranzError)
