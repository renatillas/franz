import franz
import franz/consumer/config
import franz/consumer/message_type
import gleam/dynamic
import gleam/erlang/process.{type Pid}
import gleam/otp/actor
import gleam/otp/supervision

pub type Message

pub type TopicSubscriber {
  TopicSubscriber(name: process.Name(Message))
}

/// Specifies which partitions to consume from.
pub type Partitions {
  /// Consume from specific partition numbers.
  Partitions(List(Int))
  /// Consume from all available partitions.
  All
}

/// A builder for creating and configuring a Kafka topic subscriber.
pub opaque type Builder(callback_init_state) {
  Builder(
    name: process.Name(Message),
    client: franz.Client,
    topic: String,
    partitions: Partitions,
    commited_offsets: List(#(Int, Int)),
    message_type: message_type.MessageType,
    callback: fn(Int, franz.KafkaMessage, callback_init_state) -> Ack,
    init_callback_state: callback_init_state,
    consumer_config: List(config.Config),
  )
}

/// Return type for topic subscriber acknowledgements.
pub type Ack

/// Acknowledges the processing of a message.
/// Use this in your callback to confirm message receipt.
@external(erlang, "franz_ffi", "ack")
pub fn ack(cb_state: cb_state) -> Ack

@external(erlang, "franz_ffi", "start_topic_subscriber")
fn start_topic_subscriber(
  client: franz.Client,
  topic: String,
  partitions: Partitions,
  consumer_config: List(config.Config),
  commited_offsets: List(#(Int, Int)),
  message_type: message_type.MessageType,
  callback: fn(Int, franz.KafkaMessage, cb_state) -> Ack,
  init_callback_state: cb_state,
) -> Result(Pid, dynamic.Dynamic)

/// Creates a new topic subscriber builder.
/// The callback will be called for each message received from the topic partitions.
pub fn new(
  name name: process.Name(Message),
  client client: franz.Client,
  topic topic: String,
  partitions partitions: Partitions,
  message_type message_type: message_type.MessageType,
  callback callback: fn(Int, franz.KafkaMessage, callback_init_state) -> Ack,
  init_callback_state init_callback_state: callback_init_state,
) -> Builder(callback_init_state) {
  Builder(
    name,
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

/// Adds a consumer configuration option to the topic subscriber builder.
/// Multiple configurations can be chained together.
pub fn with_config(
  builder: Builder(callback_init_state),
  consumer_config: config.Config,
) -> Builder(callback_init_state) {
  Builder(..builder, consumer_config: [
    consumer_config,
    ..builder.consumer_config
  ])
}

/// Adds a committed offset to the topic subscriber builder.
/// CommittedOffsets are the offsets for the messages that have been successfully processed (acknowledged),
/// not the begin-offset to start fetching from.
pub fn with_commited_offset(
  builder: Builder(callback_init_state),
  partition partition: Int,
  offset offset: Int,
) -> Builder(callback_init_state) {
  Builder(..builder, commited_offsets: [
    #(partition, offset),
    ..builder.commited_offsets
  ])
}

/// Starts a new topic subscriber with the configured settings.
pub fn start(
  builder: Builder(callback_init_state),
) -> actor.StartResult(TopicSubscriber) {
  case
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
  {
    Ok(pid) -> Ok(actor.Started(pid, named_client(builder.name)))
    Error(error) -> Error(actor.InitExited(process.Abnormal(error)))
  }
}

/// Creates a supervised worker for the topic subscriber.
/// This can be used with Gleam's OTP supervision trees to ensure the subscriber is restarted on failure.
pub fn supervised(builder) {
  supervision.worker(fn() { start(builder) })
}

pub fn named_client(name: process.Name(Message)) -> TopicSubscriber {
  TopicSubscriber(name)
}
