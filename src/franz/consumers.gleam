import franz
import gleam/erlang/process.{type Pid}

pub type ConsumerPartition {
  ConsumerPartitions(List(Int))
  All
}

pub type OffsetResetPolicy {
  ResetBySubscriber
  ResetToEarliest
  ResetToLatest
}

pub type OffsetTime {
  Earliest
  Latest
  MessageTimestamp(Int)
}

pub type IsolationLevel {
  ReadCommitted
  ReadUncommitted
}

pub type ConsumerConfig {
  BeginOffset(OffsetTime)
  MinBytes(Int)
  MaxBytes(Int)
  MaxWaitTime(Int)
  SleepTimeout(Int)
  PrefetchCount(Int)
  PrefetchBytes(Int)
  OffsetResetPolicy(OffsetResetPolicy)
  SizeStatWindow(Int)
  IsolationLevel(IsolationLevel)
  ShareLeaderConn(Bool)
}

pub type GroupConfig {
  SessionTimeoutSeconds(Int)
  RebalanceTimeoutSeconds(Int)
  HeartbeatRateSeconds(Int)
  MaxRejoinAttempts(Int)
  RejoinDelaySeconds(Int)
  OffsetCommitIntervalSeconds(Int)
  OffsetRetentionSeconds(Int)
}

pub type CommitedOffset {
  CommitedOffset(partition: Int, offset: Int)
}

pub type MessageType {
  Message
  MessageSet
}

pub type Ack

pub type Commit

pub type AckOrCommit(ack_or_commit)

@external(erlang, "franz_ffi", "start_consumer")
pub fn start_consumer(
  client: franz.FranzClient,
  topic: String,
  options: List(ConsumerConfig),
) -> Result(Nil, franz.FranzError)

@external(erlang, "franz_ffi", "start_topic_subscriber")
pub fn start_topic_subscriber(
  client: franz.FranzClient,
  topic: String,
  partitions: ConsumerPartition,
  consumer_config: List(ConsumerConfig),
  commited_offsets: List(CommitedOffset),
  message_type: MessageType,
  callback: fn(Int, franz.KafkaMessage, cb_state) -> AckOrCommit(Ack),
  init_callback_state: cb_state,
) -> Result(Pid, franz.FranzError)

@external(erlang, "franz_ffi", "start_group_subscriber")
pub fn start_group_subscriber(
  client: franz.FranzClient,
  group_id: String,
  topics: List(String),
  consumer_config: List(ConsumerConfig),
  group_config: List(GroupConfig),
  message_type: MessageType,
  callback: fn(franz.KafkaMessage, cb_init_state) -> AckOrCommit(ack_or_commit),
  init_callback_state: cb_init_state,
) -> Result(Pid, franz.FranzError)

@external(erlang, "franz_ffi", "ack_return")
pub fn ack_return(cb_state: cb_state) -> AckOrCommit(Ack)

@external(erlang, "franz_ffi", "commit_return")
pub fn commit_return(cb_state: cb_state) -> AckOrCommit(Commit)
