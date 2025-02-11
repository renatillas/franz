import franz

pub type ProducerPartition {
  Partition(Int)
  Partitioner(Partitioner)
}

pub type Partitioner {
  PartitionFun(fn(String, Int, BitArray, BitArray) -> Result(Int, Nil))
  Random
  Hash
}

pub opaque type ProducerBuilder {
  ProducerBuilder(
    client: franz.FranzClient,
    topic: String,
    configs: List(franz.ProducerConfig),
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

@external(erlang, "franz_ffi", "produce_sync_offset")
pub fn produce_sync_offset(
  client: franz.FranzClient,
  topic: String,
  partition: ProducerPartition,
  key: BitArray,
  value: Value,
) -> Result(Int, franz.FranzError)

@external(erlang, "franz_ffi", "produce_sync")
pub fn produce_sync(
  client: franz.FranzClient,
  topic: String,
  partition: ProducerPartition,
  key: BitArray,
  value: Value,
) -> Result(Nil, franz.FranzError)

@external(erlang, "franz_ffi", "produce")
pub fn produce(
  client: franz.FranzClient,
  topic: String,
  partition: ProducerPartition,
  key: BitArray,
  value: Value,
) -> Result(Nil, franz.FranzError)

@external(erlang, "franz_ffi", "produce_cb")
pub fn produce_cb(
  client: franz.FranzClient,
  topic: String,
  partition: ProducerPartition,
  key: BitArray,
  value: Value,
  callback: fn(franz.Partition, franz.Offset) -> any,
) -> Result(Int, franz.FranzError)

@external(erlang, "franz_ffi", "start_producer")
fn start_producer(
  client: franz.FranzClient,
  topic: String,
  consumer_config: List(franz.ProducerConfig),
) -> Result(Nil, franz.FranzError)

pub fn new(client: franz.FranzClient, topic: String) -> ProducerBuilder {
  ProducerBuilder(client, topic, [])
}

pub fn with_config(
  builder: ProducerBuilder,
  config: franz.ProducerConfig,
) -> ProducerBuilder {
  ProducerBuilder(builder.client, builder.topic, [config, ..builder.configs])
}

pub fn start(builder: ProducerBuilder) -> Result(Nil, franz.FranzError) {
  start_producer(builder.client, builder.topic, builder.configs)
}
