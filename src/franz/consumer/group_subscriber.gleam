import franz
import franz/consumer/config as consumer_config
import franz/consumer/message_type
import gleam/dynamic
import gleam/erlang/process.{type Pid}
import gleam/otp/actor
import gleam/otp/supervision

pub type Message

pub type GroupSubscriber {
  GroupSubscriber(name: process.Name(Message))
}

/// Configuration options for Kafka consumer groups.
pub type Config {
  /// Time in seconds for the group coordinator broker to consider a member 'down' if no heartbeat or any kind of requests received from a broker in the past N seconds.
  /// A group member may also consider the coordinator broker 'down' if no heartbeat response response received in the past N seconds.
  SessionTimeoutSeconds(Int)
  /// Time in seconds for each worker to join the group once a rebalance has begun.
  /// If the timeout is exceeded, then the worker will be removed from the group, which will cause offset commit failures.
  RebalanceTimeoutSeconds(Int)
  /// Time in seconds for the member to 'ping' the group coordinator.
  /// OBS: Care should be taken when picking the number, on one hand, we do not want to flush the broker with requests if we set it too low, on the other hand, if set it too high, it may take too long for the members to realise status changes of the group such as assignment rebalacing or group coordinator switchover etc.
  HeartbeatRateSeconds(Int)
  /// Maximum number of times allowed for a member to re-join the group.
  /// The gen_server will stop if it reached the maximum number of retries.
  /// OBS: 'let it crash' may not be the optimal strategy here because the group member id is kept in the gen_server looping state and it is reused when re-joining the group.
  MaxRejoinAttempts(Int)
  /// Delay in seconds before re-joining the group.
  RejoinDelaySeconds(Int)
  /// The time interval between two OffsetCommitRequest messages.
  OffsetCommitIntervalSeconds(Int)
  /// How long the time is to be kept in kafka before it is deleted.
  /// The default special value -1 indicates that the __consumer_offsets topic retention policy is used.
  OffsetRetentionSeconds(Int)
}

/// Return type for group subscriber callbacks.
pub type CallbackReturn

/// A builder for creating and configuring a Kafka consumer group subscriber.
pub opaque type Builder(callback_init_state) {
  Builder(
    name: process.Name(Message),
    client: franz.Client,
    group_id: String,
    topics: List(String),
    message_type: message_type.MessageType,
    callback: fn(franz.KafkaMessage, callback_init_state) -> CallbackReturn,
    init_callback_state: callback_init_state,
    group_config: List(Config),
    consumer_config: List(consumer_config.Config),
  )
}

/// Commits the offset of the last message that was successfully processed.
/// Use this in your callback to mark messages as processed.
@external(erlang, "franz_ffi", "commit")
pub fn commit(cb_state: cb_state) -> CallbackReturn

/// Acknowledges the processing of the message.
/// Use this in your callback to confirm message receipt.
@external(erlang, "franz_ffi", "ack")
pub fn ack(cb_state: cb_state) -> CallbackReturn

@external(erlang, "franz_ffi", "start_group_subscriber")
fn start_group_subscriber(
  client: franz.Client,
  group_id: String,
  topics: List(String),
  consumer_config: List(consumer_config.Config),
  group_config: List(Config),
  message_type: message_type.MessageType,
  callback: fn(franz.KafkaMessage, cb_init_state) -> CallbackReturn,
  init_callback_state: cb_init_state,
) -> Result(Pid, dynamic.Dynamic)

/// Creates a new group subscriber builder.
/// The callback will be called for each message received from the subscribed topics.
pub fn new(
  name name: process.Name(Message),
  client client: franz.Client,
  group_id group_id: String,
  topics topics: List(String),
  message_type message_type: message_type.MessageType,
  callback callback: fn(franz.KafkaMessage, callback_init_state) ->
    CallbackReturn,
  init_callback_state init_callback_state: callback_init_state,
) -> Builder(callback_init_state) {
  Builder(
    name,
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

/// Adds a group configuration option to the group builder.
/// Multiple configurations can be chained together.
pub fn with_group_config(
  builder: Builder(callback_init_state),
  group_config: Config,
) -> Builder(callback_init_state) {
  Builder(..builder, group_config: [group_config, ..builder.group_config])
}

/// Adds a consumer configuration option to the group builder.
/// Multiple configurations can be chained together.
pub fn with_consumer_config(
  builder: Builder(callback_init_state),
  consumer_config: consumer_config.Config,
) -> Builder(callback_init_state) {
  Builder(..builder, consumer_config: [
    consumer_config,
    ..builder.consumer_config
  ])
}

/// Starts a new group subscriber with the configured settings.
/// Returns the process ID of the subscriber on success.
pub fn start(
  builder: Builder(callback_init_state),
) -> actor.StartResult(GroupSubscriber) {
  case
    start_group_subscriber(
      builder.client,
      builder.group_id,
      builder.topics,
      builder.consumer_config,
      builder.group_config,
      builder.message_type,
      builder.callback,
      builder.init_callback_state,
    )
  {
    Ok(pid) -> Ok(actor.Started(pid, named_client(builder.name)))
    Error(error) -> Error(actor.InitExited(process.Abnormal(error)))
  }
}

/// Stops a running group subscriber.
@external(erlang, "franz_ffi", "start_group_subscriber")
pub fn stop(pid: Pid) -> Result(Nil, franz.FranzError)

/// This can be used with Gleam's OTP supervision trees to ensure the subscriber is restarted on failure.
pub fn supervised(builder) {
  supervision.worker(fn() { start(builder) })
}

pub fn named_client(name: process.Name(Message)) -> GroupSubscriber {
  GroupSubscriber(name)
}
