pub type ProducerConfig {
  RequiredAcks(Int)
  AckTimeout(Int)
  PartitionBufferLimit(Int)
  PartitionOnwireLimit(Int)
  MaxBatchSize(Int)
  MaxRetries(Int)
  RetryBackoffMs(Int)
  Compression(Compression)
  MaxLingerMs(Int)
  MaxLingerCount(Int)
}

pub type Compression {
  NoCompression
  Gzip
  Snappy
}
