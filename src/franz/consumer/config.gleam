import franz/isolation_level

/// Configuration options for Kafka consumers.
pub type Config {
  /// The offset from which to begin fetch requests. A subscriber may consume and process messages, then persist the associated offset to a persistent storage, then start (or restart) from last_processed_offset + 1 as the begin_offset to proceed. The offset has to already exist at the time of calling.
  /// Default: Latest
  BeginOffset(OffsetTime)
  /// Minimal bytes to fetch in a batch of messages
  /// Default: 0
  MinBytes(Int)
  /// Maximum bytes to fetch in a batch of messages.
  /// NOTE: this value might be expanded to retry when it is not enough to fetch even a single message, then slowly shrunk back to the given value.
  /// Default: 1 MB
  MaxBytes(Int)
  /// Max number of seconds allowed for the broker to collect min_bytes of messages in fetch response.
  /// Default: 10000 ms
  MaxWaitTime(Int)
  /// Allow consumer process to sleep this amount of ms if kafka replied 'empty' message set.
  /// Default: 1000 ms
  SleepTimeout(Int)
  /// The window size (number of messages) allowed to fetch-ahead.
  /// Default: 10
  PrefetchCount(Int)
  /// The total number of bytes allowed to fetch-ahead. 
  /// Default: 100KB
  PrefetchBytes(Int)
  /// How to reset BeginOffset if OffsetOutOfRange exception is received.
  /// Default: ResetBySubscriber
  OffsetResetPolicy(OffsetResetPolicy)
  /// The moving-average window size to calculate average message size. Average message size is used to shrink max_bytes in fetch requests after it has been expanded to fetch a large message. Use 0 to immediately shrink back to original max_bytes from config. A size estimation allows users to set a relatively small max_bytes, then let it dynamically adjust to a number around PrefetchCount * AverageSize.
  /// Default: 5
  SizeStatWindow(Int)
  /// Level to control what transaction records are exposed to the consumer.
  /// Two values are allowed, read_uncommitted to retrieve all records, independently on the transaction outcome (if any), and read_committed to get only the records from committed transactions
  /// Default: ReadCommited
  IsolationLevel(isolation_level.IsolationLevel)
  /// Whether or not share the partition leader connection with other producers or consumers. Set to true to consume less TCP connections towards Kafka, but may lead to higher fetch latency. This is because Kafka can ony accumulate messages for the oldest fetch request, later requests behind it may get blocked until max_wait_time expires for the oldest one.
  ShareLeaderConn(Bool)
}

/// Specifies the starting offset position for message consumption.
pub type OffsetTime {
  /// Start consuming from the latest available message (default).
  Latest
  /// Start consuming from the earliest available message.
  Earliest
  /// Start consuming from a specific timestamp.
  MessageTimestamp(Int)
}

/// Policy for handling offset out of range errors.
pub type OffsetResetPolicy {
  /// Let the subscriber handle the reset (default).
  ResetBySubscriber
  /// Reset to the earliest available offset.
  ResetToEarliest
  /// Reset to the latest available offset.
  ResetToLatest
}
