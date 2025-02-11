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

pub opaque type ProducerBuilder {
  ProducerBuilder(
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

/// Produce one or more messages.
/// A producer for the particular topic has to be already started (by calling producer.start()), unless you have specified AutoStartProducers(True) when starting the client.
@external(erlang, "franz_ffi", "produce")
pub fn produce(
  client: franz.FranzClient,
  topic: String,
  partition: ProducerPartition,
  key: BitArray,
  value: Value,
) -> Result(Nil, franz.FranzError)

/// This function will await the kafka ack before returning.
/// A producer for the particular topic has to be already started (by calling producer.start()), unless you have specified AutoStartProducers(True) when starting the client.
/// This function will return the offset of the produced message.
@external(erlang, "franz_ffi", "produce_sync_offset")
pub fn produce_sync_offset(
  client: franz.FranzClient,
  topic: String,
  partition: ProducerPartition,
  key: BitArray,
  value: Value,
) -> Result(Int, franz.FranzError)

/// This function will await the kafka ack before returning.
/// A producer for the particular topic has to be already started (by calling producer.start()), unless you have specified AutoStartProducers(True) when starting the client.
@external(erlang, "franz_ffi", "produce_sync")
pub fn produce_sync(
  client: franz.FranzClient,
  topic: String,
  partition: ProducerPartition,
  key: BitArray,
  value: Value,
) -> Result(Nil, franz.FranzError)

/// This function will await the kafka ack before returning and calling the callback.
/// A producer for the particular topic has to be already started (by calling producer.start()), unless you have specified AutoStartProducers(True) when starting the client.
/// Returns the partititon of the produced message.
@external(erlang, "franz_ffi", "produce_cb")
pub fn produce_cb(
  client: franz.FranzClient,
  topic: String,
  partition: ProducerPartition,
  key: BitArray,
  value: Value,
  callback: fn(Int, Int) -> any,
) -> Result(Int, franz.FranzError)

@external(erlang, "franz_ffi", "start_producer")
fn start_producer(
  client: franz.FranzClient,
  topic: String,
  consumer_config: List(producer_config.ProducerConfig),
) -> Result(Nil, franz.FranzError)

/// Creates a new producer builder with the given Franz client and topic.
pub fn new(client: franz.FranzClient, topic: String) -> ProducerBuilder {
  ProducerBuilder(client, topic, [])
}

/// Add a producer configuration to the producer builder.
pub fn with_config(
  builder: ProducerBuilder,
  config: producer_config.ProducerConfig,
) -> ProducerBuilder {
  ProducerBuilder(builder.client, builder.topic, [config, ..builder.configs])
}

/// Start a producer with the given configuration.
/// A producer for the particular topic has to be already started (by calling producer.start()), unless you have specified AutoStartProducers(True) when starting the client.
pub fn start(builder: ProducerBuilder) -> Result(Nil, franz.FranzError) {
  start_producer(builder.client, builder.topic, builder.configs)
}
