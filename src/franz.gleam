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

pub type Ack(callback_state)

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

pub type ProducerPartition {
  Partition(Int)
  Partitioner(Partitioner)
}

pub type Partitioner {
  PartitionFun(fn(Int, Int, BitArray, BitArray) -> Result(Int, Nil))
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

@external(erlang, "franz_ffi", "start_client")
pub fn start_client(
  bootstrap_endpoints: List(#(String, Int)),
  client_config: List(ClientConfig),
) -> Result(FranzClient, FranzError)

@external(erlang, "franz_ffi", "produce_sync_offset")
pub fn produce_sync_offset(
  client: FranzClient,
  topic: String,
  partition: ProducerPartition,
  key: BitArray,
  value: Value,
) -> Result(Int, FranzError)

@external(erlang, "franz_ffi", "produce_sync")
pub fn produce_sync(
  client: FranzClient,
  topic: String,
  partition: ProducerPartition,
  key: BitArray,
  value: Value,
) -> Result(Nil, FranzError)

@external(erlang, "franz_ffi", "produce")
pub fn produce(
  client: FranzClient,
  topic: String,
  partition: ProducerPartition,
  key: BitArray,
  value: Value,
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
  partitions: ConsumerPartition,
  consumer_config: List(ConsumerConfig),
  commited_offsets: List(#(Int, Int)),
  callback: fn(Int, message, cb_state) -> Ack(cb_state),
  init_callback_state: cb_state,
) -> Result(Pid, FranzError)

@external(erlang, "franz_ffi", "ack_return")
pub fn ack_return(cb_state: cb_state) -> Ack(cb_state)

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
  topic: String,
  partition: ProducerPartition,
  key: BitArray,
  value: BitArray,
  callback: fn(Int, Int) -> any,
) -> Result(Int, FranzError)

@external(erlang, "franz_ffi", "fetch")
pub fn fetch(
  client: FranzClient,
  topic: String,
  partition: Int,
  offset: Int,
) -> Result(#(Int, KafkaMessage), FranzError)
