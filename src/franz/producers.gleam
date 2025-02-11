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
