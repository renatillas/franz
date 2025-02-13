import franz
import franz/producer_config

pub type ProducerPartition {
  Partition(Int)
  Partitioner(Partitioner)
}

pub type Partitioner {
  /// Partititoner function with Topic, PartitionCount, Key and Value that should return a partition number.
  PartitionFun(fn(String, Int, BitArray, BitArray) -> Result(Int, Nil))
  /// Random partitioner.
  Random
  /// Hash partititoner
  Hash
}

pub opaque type Builder {
  Builder(
    client: franz.FranzClient,
    topic: String,
    configs: List(producer_config.ProducerConfig),
  )
}

pub type Value {
  Value(value: BitArray, headers: List(#(String, String)))
  ValueWithTimestamp(
    value: BitArray,
    timestamp: Int,
    headers: List(#(String, String)),
  )
}

pub type CbPartition {
  CbPartition(Int)
}

pub type CbOffset {
  CbOffset(Int)
}

/// Creates a new producer builder with the given Franz client and topic.
pub fn new(client: franz.FranzClient, topic: String) -> Builder {
  Builder(client, topic, [])
}

/// Add a producer configuration to the producer builder.
pub fn with_config(
  builder: Builder,
  config: producer_config.ProducerConfig,
) -> Builder {
  Builder(builder.client, builder.topic, [config, ..builder.configs])
}

/// Start a producer with the given configuration.
/// A producer for the particular topic has to be already started (by calling producer.start()), unless you have specified AutoStartProducers(True) when starting the client.
pub fn start(builder: Builder) -> Result(Nil, franz.FranzError) {
  do_start(builder.client, builder.topic, builder.configs)
}

@external(erlang, "franz_ffi", "start_producer")
fn do_start(
  client: franz.FranzClient,
  topic: String,
  consumer_config: List(producer_config.ProducerConfig),
) -> Result(Nil, franz.FranzError)

/// Produce one or more messages.
/// A producer for the particular topic has to be already started (by calling producer.start()), unless you have specified AutoStartProducers(True) when starting the client.
@external(erlang, "franz_ffi", "produce_no_ack")
pub fn produce_no_ack(
  client client: franz.FranzClient,
  topic topic: String,
  partition partition: ProducerPartition,
  key key: BitArray,
  value value: Value,
) -> Result(Nil, franz.FranzError)

/// This function will await the kafka ack before returning.
/// A producer for the particular topic has to be already started (by calling producer.start()), unless you have specified AutoStartProducers(True) when starting the client.
/// This function will return the offset of the produced message.
@external(erlang, "franz_ffi", "produce_sync_offset")
pub fn produce_sync_offset(
  client client: franz.FranzClient,
  topic topic: String,
  partition partition: ProducerPartition,
  key key: BitArray,
  value value: Value,
) -> Result(Int, franz.FranzError)

/// This function will await the kafka ack before returning.
/// A producer for the particular topic has to be already started (by calling producer.start()), unless you have specified AutoStartProducers(True) when starting the client.
@external(erlang, "franz_ffi", "produce_sync")
pub fn produce_sync(
  client client: franz.FranzClient,
  topic topic: String,
  partition partition: ProducerPartition,
  key key: BitArray,
  value value: Value,
) -> Result(Nil, franz.FranzError)

/// This function will await the kafka ack before returning and calling the callback.
/// A producer for the particular topic has to be already started (by calling producer.start()), unless you have specified AutoStartProducers(True) when starting the client.
/// Returns the partititon of the produced message.
/// The callback expects the partition and offset of the produced message.
@external(erlang, "franz_ffi", "produce_cb")
pub fn produce_cb(
  client client: franz.FranzClient,
  topic topic: String,
  partition partition: ProducerPartition,
  key key: BitArray,
  value value: Value,
  callback callback: fn(CbPartition, CbOffset) -> any,
) -> Result(Int, franz.FranzError)
