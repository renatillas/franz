import franz
import franz/producer/config

/// Specifies how to select the partition for produced messages.
pub type Partition {
  Partition(Int)
  Partitioner(Partitioner)
}

/// Different strategies for partitioning messages across Kafka partitions.
pub type Partitioner {
  /// Partititoner function with Topic, PartitionCount, Key and Value that should return a partition number.
  PartitionFun(fn(String, Int, BitArray, BitArray) -> Result(Int, Nil))
  /// Random partitioner.
  Random
  /// Hash partititoner
  Hash
}

/// A builder for creating and configuring a Kafka producer.
pub opaque type Builder {
  Builder(client: franz.Client, topic: String, configs: List(config.Config))
}

/// The value to be produced to Kafka, optionally with headers and timestamp.
pub type Value {
  Value(value: BitArray, headers: List(#(String, String)))
  ValueWithTimestamp(
    value: BitArray,
    timestamp: Int,
    headers: List(#(String, String)),
  )
}

/// Wrapper type for partition numbers in callbacks.
pub type CbPartition {
  CbPartition(Int)
}

/// Wrapper type for message offsets in callbacks.
pub type CbOffset {
  CbOffset(Int)
}

/// Creates a new producer builder with the given Franz client and topic.
pub fn new(client: franz.Client, topic: String) -> Builder {
  Builder(client, topic, [])
}

/// Add a producer configuration to the producer builder.
pub fn with_config(builder: Builder, config: config.Config) -> Builder {
  Builder(builder.client, builder.topic, [config, ..builder.configs])
}

/// Start a producer with the given configuration.
/// A producer for the particular topic has to be already started (by calling producer.start()), unless you have specified AutoStartProducers(True) when starting the client.
pub fn start(builder: Builder) -> Result(Nil, franz.FranzError) {
  do_start(builder.client, builder.topic, builder.configs)
}

@external(erlang, "franz_ffi", "start_producer")
fn do_start(
  client: franz.Client,
  topic: String,
  config: List(config.Config),
) -> Result(Nil, franz.FranzError)

/// Produce one or more messages.
/// A producer for the particular topic has to be already started (by calling producer.start()), unless you have specified AutoStartProducers(True) when starting the client.
@external(erlang, "franz_ffi", "produce_no_ack")
pub fn produce_no_ack(
  client client: franz.Client,
  topic topic: String,
  partition partition: Partition,
  key key: BitArray,
  value value: Value,
) -> Result(Nil, franz.FranzError)

/// This function will await the kafka ack before returning.
/// A producer for the particular topic has to be already started (by calling producer.start()), unless you have specified AutoStartProducers(True) when starting the client.
/// This function will return the offset of the produced message.
@external(erlang, "franz_ffi", "produce_sync_offset")
pub fn produce_sync_offset(
  client client: franz.Client,
  topic topic: String,
  partition partition: Partition,
  key key: BitArray,
  value value: Value,
) -> Result(Int, franz.FranzError)

/// This function will await the kafka ack before returning.
/// A producer for the particular topic has to be already started (by calling producer.start()), unless you have specified AutoStartProducers(True) when starting the client.
@external(erlang, "franz_ffi", "produce_sync")
pub fn produce_sync(
  client client: franz.Client,
  topic topic: String,
  partition partition: Partition,
  key key: BitArray,
  value value: Value,
) -> Result(Nil, franz.FranzError)

/// This function will await the kafka ack before returning and calling the callback.
/// A producer for the particular topic has to be already started (by calling producer.start()), unless you have specified AutoStartProducers(True) when starting the client.
/// Returns the partititon of the produced message.
/// The callback expects the partition and offset of the produced message.
@external(erlang, "franz_ffi", "produce_cb")
pub fn produce_cb(
  client client: franz.Client,
  topic topic: String,
  partition partition: Partition,
  key key: BitArray,
  value value: Value,
  callback callback: fn(CbPartition, CbOffset) -> any,
) -> Result(Partition, franz.FranzError)
