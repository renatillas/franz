import franz
import franz/consumer_config
import franz/message_type
import franz/partitions
import gleam/erlang/process.{type Pid}

pub opaque type Builder(callback_init_state) {
  Builder(
    client: franz.FranzClient,
    topic: String,
    partitions: partitions.Partitions,
    commited_offsets: List(#(Int, Int)),
    message_type: message_type.MessageType,
    callback: fn(Int, franz.KafkaMessage, callback_init_state) -> Ack,
    init_callback_state: callback_init_state,
    consumer_config: List(consumer_config.ConsumerConfig),
  )
}

pub type Ack

/// Acknowledge the processing of the message.
@external(erlang, "franz_ffi", "ack")
pub fn ack(cb_state: cb_state) -> Ack

@external(erlang, "franz_ffi", "start_topic_subscriber")
fn start_topic_subscriber(
  client: franz.FranzClient,
  topic: String,
  partitions: partitions.Partitions,
  consumer_config: List(consumer_config.ConsumerConfig),
  commited_offsets: List(#(Int, Int)),
  message_type: message_type.MessageType,
  callback: fn(Int, franz.KafkaMessage, cb_state) -> Ack,
  init_callback_state: cb_state,
) -> Result(Pid, franz.FranzError)

/// Create a new topic subscriber builder.
pub fn new(
  client: franz.FranzClient,
  topic: String,
  partitions: partitions.Partitions,
  message_type: message_type.MessageType,
  callback: fn(Int, franz.KafkaMessage, callback_init_state) -> Ack,
  init_callback_state: callback_init_state,
) -> Builder(callback_init_state) {
  Builder(
    client,
    topic,
    partitions,
    [],
    message_type,
    callback,
    init_callback_state,
    [],
  )
}

/// Add a consumer configuration to the topic subscriber builder.
pub fn with_config(
  builder: Builder(callback_init_state),
  consumer_config: consumer_config.ConsumerConfig,
) -> Builder(callback_init_state) {
  Builder(..builder, consumer_config: [
    consumer_config,
    ..builder.consumer_config
  ])
}

/// Add a commited offset to the topic subscriber builder.
pub fn with_commited_offset(
  builder: Builder(callback_init_state),
  partition: Int,
  offset: Int,
) -> Builder(callback_init_state) {
  Builder(..builder, commited_offsets: [
    #(partition, offset),
    ..builder.commited_offsets
  ])
}

/// Start a new topic subscriber.
pub fn start(
  builder: Builder(callback_init_state),
) -> Result(Pid, franz.FranzError) {
  start_topic_subscriber(
    builder.client,
    builder.topic,
    builder.partitions,
    builder.consumer_config,
    builder.commited_offsets,
    builder.message_type,
    builder.callback,
    builder.init_callback_state,
  )
}
