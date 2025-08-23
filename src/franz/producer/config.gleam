/// Configuration options for Kafka producers.
pub type Config {
  /// How many acknowledgements the kafka broker should receive from the clustered replicas before acking producer.
  ///  0: the broker will not send any response (this is the only case where the broker will not reply to a request) 
  ///  1: The leader will wait the data is written to the local log before sending a response. 
  /// -1: If it is -1 the broker will block until the message is committed by all in sync replicas before acking.
  /// Default: -1.
  RequiredAcks(Int)
  /// Maximum time in milliseconds the broker can await the receipt of the number of acknowledgements in RequiredAcks. The timeout is not an exact limit on the request time for a few reasons: 
  /// (1) it does not include network latency, 
  /// (2) the timer begins at the beginning of the processing of this request so if many requests are queued due to broker overload that wait time will not be included,
  /// (3) kafka leader will not terminate a local write so if the local write time exceeds this timeout it will not be respected.
  /// Default: 10000 ms.
  AckTimeout(Int)
  /// How many requests (per-partition) can be buffered without blocking the caller.
  /// The callers are released (by receiving the 'brod_produce_req_buffered' reply) once the request is taken into buffer and after the request has been put on wire, then the caller may expect a reply 'brod_produce_req_acked' when the request is accepted by kafka.
  /// Default: 256.
  PartitionBufferLimit(Int)
  /// How many message sets (per-partition) can be sent to kafka broker asynchronously before receiving ACKs from broker.
  /// NOTE: setting a number greater than 1 may cause messages being persisted in an order different from the order they were produced.
  /// Default: 1.
  PartitionOnwireLimit(Int)
  /// In case callers are producing faster than brokers can handle (or congestion on wire), try to accumulate small requests into batches as much as possible but not exceeding max_batch_size.
  /// OBS: If compression is enabled, care should be taken when picking the max batch size, because a compressed batch will be produced as one message and this message might be larger than 'max.message.bytes' in kafka config (or topic config)
  /// Default: 1M.
  MaxBatchSize(Int)
  /// If MaxRetries(Int) is given, the producer retry produce request for N times before crashing in case of failures like connection being shutdown by remote or exceptions received in produce response from kafka.
  /// The special value N = -1 means "retry indefinitely"
  /// Default: 3.
  MaxRetries(Int)
  /// Time in milli-seconds to sleep before retry the failed produce request.
  /// Default: 500 ms.
  RetryBackoffMs(Int)
  /// Use this option to enable compression of messages.
  /// Default: NoCompression.
  Compression(Compression)
  /// Messages are allowed to 'linger' in buffer for this amount of milli-seconds before being sent. Definition of 'linger': A message is in "linger" state when it is allowed to be sent on-wire, but chosen not to (for better batching).
  /// The default value is 0 for 2 reasons:
  ///   1. Backward compatibility (for 2.x releases)
  ///   2. Not to surprise consumer.produce_sync() callers
  /// Default: 0 ms.
  MaxLingerMs(Int)
  /// At most this amount (count not size) of messages are allowed to "linger" in buffer. Messages will be sent regardless of "linger" age when this threshold is hit.
  /// NOTE: It does not make sense to have this value set larger than PartitionBufferLimit(Int)
  /// Default: 0.
  MaxLingerCount(Int)
}

/// Compression algorithms available for message batching.
pub type Compression {
  /// No compression (default).
  NoCompression
  /// Gzip compression algorithm.
  Gzip
  /// Snappy compression algorithm.
  Snappy
}
