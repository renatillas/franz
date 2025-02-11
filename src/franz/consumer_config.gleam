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

pub type IsolationLevel {
  ReadCommitted
  ReadUncommitted
}

pub type OffsetTime {
  Earliest
  Latest
  MessageTimestamp(Int)
}

pub type OffsetResetPolicy {
  ResetBySubscriber
  ResetToEarliest
  ResetToLatest
}
