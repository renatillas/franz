pub type GroupConfig {
  SessionTimeoutSeconds(Int)
  RebalanceTimeoutSeconds(Int)
  HeartbeatRateSeconds(Int)
  MaxRejoinAttempts(Int)
  RejoinDelaySeconds(Int)
  OffsetCommitIntervalSeconds(Int)
  OffsetRetentionSeconds(Int)
}
