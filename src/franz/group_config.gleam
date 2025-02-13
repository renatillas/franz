pub type GroupConfig {
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
