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

@external(erlang, "franz_ffi", "stop_client")
pub fn stop_client(client: FranzClient) -> Nil

@external(erlang, "franz_ffi", "create_topic")
pub fn create_topic(
  bootstrap_endpoints: List(#(String, Int)),
  topic: Topic,
  partitions: Partition,
  replication_factor: Int,
) -> Result(Nil, FranzError)

@external(erlang, "franz_ffi", "fetch")
pub fn fetch(
  client: FranzClient,
  topic: Topic,
  partition: Partition,
  offset: Offset,
) -> Result(#(Offset, KafkaMessage), FranzError)
