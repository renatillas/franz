import franz
import franz/consumer_config
import franz/group_config
import franz/message_type
import gleam/erlang/process.{type Pid}

pub type CallbackReturn

pub opaque type GroupBuilder(callback_init_state) {
  GroupBuilder(
    client: franz.FranzClient,
    group_id: String,
    topics: List(String),
    message_type: message_type.MessageType,
    callback: fn(franz.KafkaMessage, callback_init_state) -> CallbackReturn,
    init_callback_state: callback_init_state,
    group_config: List(group_config.GroupConfig),
    consumer_config: List(consumer_config.ConsumerConfig),
  )
}

/// Commit the offset of the last message that was successfully processed.
@external(erlang, "franz_ffi", "commit")
pub fn commit(cb_state: cb_state) -> CallbackReturn

/// Acknowledge the processing of the message.
@external(erlang, "franz_ffi", "ack")
pub fn ack(cb_state: cb_state) -> CallbackReturn

@external(erlang, "franz_ffi", "start_group_subscriber")
fn start_group_subscriber(
  client: franz.FranzClient,
  group_id: String,
  topics: List(String),
  consumer_config: List(consumer_config.ConsumerConfig),
  group_config: List(group_config.GroupConfig),
  message_type: message_type.MessageType,
  callback: fn(franz.KafkaMessage, cb_init_state) -> CallbackReturn,
  init_callback_state: cb_init_state,
) -> Result(Pid, franz.FranzError)

/// Create a new group subscriber builder.
pub fn new(
  client client: franz.FranzClient,
  group_id group_id: String,
  topics topics: List(String),
  message_type message_type: message_type.MessageType,
  callback callback: fn(franz.KafkaMessage, callback_init_state) ->
    CallbackReturn,
  init_callback_state init_callback_state: callback_init_state,
) -> GroupBuilder(callback_init_state) {
  GroupBuilder(
    client,
    group_id,
    topics,
    message_type,
    callback,
    init_callback_state,
    [],
    [],
  )
}

/// Add a group configuration to the group builder.
pub fn with_group_config(
  group_builder: GroupBuilder(callback_init_state),
  group_config: group_config.GroupConfig,
) -> GroupBuilder(callback_init_state) {
  GroupBuilder(..group_builder, group_config: [
    group_config,
    ..group_builder.group_config
  ])
}

/// Add a consumer configuration to the group builder.
pub fn with_consumer_config(
  group_builder: GroupBuilder(callback_init_state),
  consumer_config: consumer_config.ConsumerConfig,
) -> GroupBuilder(callback_init_state) {
  GroupBuilder(..group_builder, consumer_config: [
    consumer_config,
    ..group_builder.consumer_config
  ])
}

/// Start a new group subscriber.
pub fn start(
  group_builder: GroupBuilder(callback_init_state),
) -> Result(Pid, franz.FranzError) {
  start_group_subscriber(
    group_builder.client,
    group_builder.group_id,
    group_builder.topics,
    group_builder.consumer_config,
    group_builder.group_config,
    group_builder.message_type,
    group_builder.callback,
    group_builder.init_callback_state,
  )
}

@external(erlang, "franz_ffi", "start_group_subscriber")
pub fn stop(pid: Pid) -> Result(Nil, franz.FranzError)
