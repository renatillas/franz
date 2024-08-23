import gleam/dynamic
import gleam/erlang/process
import gleam/io
import gleam/otp/task

pub type Offset =
  Int

pub type ClientError {
  ClientDown
}

pub type ProducerError {
  ProducerNotFound(topic: String, partititon: Int)
}

pub type ConsumerError

pub type SubscribeError

pub type OffsetTimeMilliseconds =
  Int

pub fn main() {
  start_client("localhost", 9092)
  start_producer("test-topic")
  start_consumer("test-topic")
  subscribe("test-topic", 0, [])

  process.sleep_forever
}

@external(erlang, "franz_ffi", "start_client")
pub fn start_client(hostname: String, port: Int) -> Result(Nil, ClientError)

@external(erlang, "franz_ffi", "start_producer")
pub fn start_producer(topic: String) -> Result(Nil, ProducerError)

@external(erlang, "franz_ffi", "produce_sync_offset")
pub fn produce_sync_offset(
  topic: String,
  partition: Int,
  key: String,
  value: String,
) -> Result(Offset, Nil)

@external(erlang, "franz_ffi", "produce_sync")
pub fn produce_sync(
  topic: String,
  partition: Int,
  key: String,
  value: String,
) -> Result(Nil, Nil)

@external(erlang, "franz_ffi", "start_consumer")
pub fn start_consumer(topic: String) -> Result(Nil, ConsumerError)

@external(erlang, "franz_ffi", "subscribe")
fn do_subscribe(
  pid: process.Pid,
  topic: String,
  partition: Int,
  options: a,
) -> Result(process.Pid, SubscribeError)

pub fn subscribe(topic, partition, options) {
  let subject = process.new_subject()
  do_subscribe(process.subject_owner(subject), topic, partition, options)
  |> io.debug
  process.new_selector()
  |> process.selecting_anything(mapping: fn(dynamic: dynamic.Dynamic) {
    io.debug(dynamic)
  })
  |> process.select(1000)
  |> io.debug
}
