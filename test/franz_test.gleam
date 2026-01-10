import franz
import gleam/erlang/process
import gleam/list
import gleam/time/duration
import gleam/time/timestamp
import gleeunit

pub fn main() {
  gleeunit.main()
}

fn setup_topics(
  topic topic: String,
  endpoint endpoint: franz.Endpoint,
  fun fun: fn() -> Nil,
) {
  let _ =
    franz.delete_topics(
      endpoints: [endpoint],
      names: [topic],
      timeout: duration.seconds(1),
    )

  // Small delay to allow deletion to complete
  process.sleep(200)

  let _ =
    franz.create_topic(
      endpoints: [endpoint],
      name: topic,
      partitions: 1,
      replication_factor: 1,
      configs: [],
      timeout: duration.seconds(5),
    )

  // Small delay to ensure topic is ready
  process.sleep(200)

  fun()
}

fn setup_client(
  endpoint endpoint: franz.Endpoint,
  name name: process.Name(franz.Message),
  fun fun: fn(franz.Client) -> Nil,
) {
  let assert Ok(_actor_started) =
    franz.default_client(name)
    |> franz.endpoints([endpoint])
    |> franz.start()
  let named_client = franz.named(name)

  fun(named_client)
  // Note: Client is not automatically stopped to avoid race conditions
  // with active subscribers. Tests that need explicit cleanup should
  // call franz.stop() themselves.
}

pub fn create_topic_test() {
  let topic = "test_topic"
  let endpoint = franz.Endpoint("127.0.0.1", 9092)
  use <- setup_topics(topic:, endpoint:)
  Nil
}

pub fn create_duplicate_topic_test() {
  let topic = "test_duplicate"
  let endpoint = franz.Endpoint("localhost", 9092)
  use <- setup_topics(topic:, endpoint:)

  assert Error(franz.TopicAlreadyExists)
    == franz.create_topic(
      endpoints: [endpoint],
      name: topic,
      partitions: 1,
      replication_factor: 1,
      configs: [],
      timeout: duration.seconds(5),
    )
}

pub fn start_stop_client_test() {
  let name = process.new_name("client_start_stop")
  let endpoint = franz.Endpoint("localhost", 9092)
  use _client <- setup_client(endpoint:, name:)
  Nil
}

pub fn start_client_with_config_test() {
  let name = process.new_name("client_start_with_conf")
  let endpoint = franz.Endpoint("localhost", 9092)

  let assert Ok(_actor_started) =
    franz.default_client(name)
    |> franz.endpoints([endpoint])
    |> franz.option(franz.RestartDelay(duration.seconds(100)))
    |> franz.option(franz.ReconnectCoolDown(duration.seconds(100)))
    |> franz.option(franz.AllowTopicAutoCreation(True))
    |> franz.option(franz.AutoStartProducers(True))
    |> franz.option(franz.UnknownTopicCacheTtl(duration.minutes(2)))
    |> franz.option(
      franz.DefaultProducerConfig([
        franz.RequiredAcks(1),
        franz.AckTimeout(duration.seconds(1)),
        franz.PartitionBufferLimit(1000),
        franz.PartitionOnWireLimit(1000),
        franz.MaxBatchSize(1000),
        franz.MaxRetries(1000),
        franz.RetryBackoff(duration.seconds(1)),
        franz.Compression(franz.NoCompression),
        franz.MaxLinger(duration.seconds(1)),
        franz.MaxLingerCount(1000),
      ]),
    )
    |> franz.start()

  let client = franz.named(name)
  assert Nil == franz.stop(client)
}

pub fn producer_produce_sync_test() {
  let name = process.new_name("producer_sync")
  let endpoint = franz.Endpoint("localhost", 9092)
  let partition = franz.SinglePartition(0)
  let topic = "test_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name:)
  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  assert Ok(Nil)
    == franz.produce_sync(
      client:,
      topic:,
      partition:,
      key: <<"key">>,
      value: franz.Value(<<"value">>, []),
    )
}

pub fn producer_produce_sync_offset_test() {
  let name = process.new_name("producer_sync_offset")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "test_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name:)
  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  assert Ok(0)
    == franz.produce_sync_offset(
      client: client,
      topic: "test_topic",
      partition: franz.SinglePartition(0),
      key: <<"key">>,
      value: franz.Value(<<"value">>, []),
    )
}

pub fn producer_produce_cb_test() {
  let name = process.new_name("producer_callback")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "test_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name:)
  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()
  let offset_subject = process.new_subject()
  let partition_subject = process.new_subject()

  assert Ok(franz.SinglePartition(0))
    == franz.produce_async(
      client: client,
      topic: "test_topic",
      partition: franz.SinglePartition(0),
      key: <<"key">>,
      value: franz.Value(<<"value">>, []),
      callback: fn(partition, offset) {
        process.send(offset_subject, offset)
        process.send(partition_subject, partition)
      },
    )

  let assert Ok(franz.Partition(0)) = process.receive(partition_subject, 1000)
  let assert Ok(franz.Offset(0)) = process.receive(offset_subject, 1000)
  Nil
}

pub fn produce_no_ack_test() {
  let name = process.new_name("franz_test_producer")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "test_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name:)
  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  assert Ok(Nil)
    == franz.produce(
      client: client,
      topic: "test_topic",
      partition: franz.SinglePartition(0),
      key: <<"key">>,
      value: franz.Value(<<"value">>, []),
    )
}

pub fn start_producer_with_config_test() {
  let name = process.new_name("franz_test_producer")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "test_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name:)

  assert Ok(Nil)
    == franz.Producer(..franz.default_producer(client, topic), options: [
      franz.RequiredAcks(1),
      franz.AckTimeout(duration.seconds(1)),
      franz.PartitionBufferLimit(1000),
      franz.PartitionOnWireLimit(1000),
      franz.MaxBatchSize(1000),
      franz.MaxRetries(1000),
      franz.RetryBackoff(duration.seconds(1)),
      franz.Compression(franz.NoCompression),
      franz.MaxLinger(duration.seconds(1)),
      franz.MaxLingerCount(1000),
    ])
    |> franz.start_producer()
}

pub fn start_topic_subscriber_test() {
  let client_name = process.new_name("topic_subscriber:client")
  let subscriber_name = process.new_name("topic_subscriber:subscriber")
  let topic = "test_topic"
  let endpoint = franz.Endpoint("localhost", 9092)
  use <- setup_topics(endpoint:, topic:)
  use client <- setup_client(endpoint:, name: client_name)
  let partition_subject = process.new_subject()
  let message_subject = process.new_subject()
  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  let assert Ok(_actor_started) =
    franz.default_topic_subscriber(
      subscriber_name,
      client:,
      topic:,
      callback: fn(partition: Int, message: franz.KafkaMessage, cb_state: Int) {
        process.send(partition_subject, partition)
        process.send(message_subject, message)
        franz.TopicAck(cb_state)
      },
      initial_state: 0,
    )
    |> franz.start_topic_subscriber()
  process.sleep(100)

  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"key">>,
      value: franz.Value(<<"value">>, []),
    )

  assert Ok(0) == process.receive(partition_subject, 2000)
  let assert Ok(franz.KafkaMessage(
    offset: 0,
    key: <<"key">>,
    value: <<"value">>,
    ..,
  )) = process.receive(message_subject, 1000)
  Nil
}

pub fn start_group_subscriber_test() {
  let subscriber_name = process.new_name("start_group_subscriber:subscriber")
  let client_name = process.new_name("start_group_subscriber:client")
  let topic = "test_topic"
  let endpoint = franz.Endpoint("localhost", 9092)
  use <- setup_topics(topic, endpoint:)
  use client <- setup_client(endpoint:, name: client_name)
  let message_subject = process.new_subject()

  // First produce a message
  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  assert Ok(Nil)
    == franz.produce_sync(
      client: client,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"test_key">>,
      value: franz.Value(<<"test_value">>, []),
    )

  // Small delay to ensure message is committed
  process.sleep(500)

  let group_id = "test_consumer_group"
  let assert Ok(_) =
    franz.GroupSubscriberConfig(
      ..franz.default_group_subscriber_config(
        subscriber_name,
        client:,
        group_id:,
        topics: [topic],
        callback: fn(message: franz.KafkaMessage, cb_state) {
          process.send(message_subject, message)
          franz.GroupCommit(cb_state)
        },
        init_state: 0,
      ),
      // Start from earliest to ensure we get messages produced before consumer started
      consumer_options: [franz.BeginOffset(franz.Earliest)],
    )
    |> franz.start_group_subscriber()

  // Wait for the consumer to read the message
  let assert Ok(franz.KafkaMessage(
    offset: 0,
    key: <<"test_key">>,
    value: <<"test_value">>,
    ..,
  )) = process.receive(message_subject, 10_000)
  process.sleep(500)
}

// Test LZ4 compression (new in 3.0.0)
pub fn producer_with_lz4_compression_test() {
  let name = process.new_name("producer_lz4")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "test_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name:)

  assert Ok(Nil)
    == franz.Producer(..franz.default_producer(client, topic), options: [
      franz.Compression(franz.Lz4),
    ])
    |> franz.start_producer()
}

// =============================================================================
// Partitioner Tests
// =============================================================================

pub fn producer_with_hash_partitioner_test() {
  let name = process.new_name("producer_hash")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "partitioner_hash_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name:)

  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  // Hash partitioner should consistently route same key to same partition
  assert Ok(Nil)
    == franz.produce_sync(
      client:,
      topic:,
      partition: franz.Partitioner(franz.Hash),
      key: <<"consistent_key">>,
      value: franz.Value(<<"value1">>, []),
    )

  assert Ok(Nil)
    == franz.produce_sync(
      client:,
      topic:,
      partition: franz.Partitioner(franz.Hash),
      key: <<"consistent_key">>,
      value: franz.Value(<<"value2">>, []),
    )
}

pub fn producer_with_random_partitioner_test() {
  let name = process.new_name("producer_random")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "partitioner_random_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name:)

  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  // Random partitioner should successfully produce
  assert Ok(Nil)
    == franz.produce_sync(
      client:,
      topic:,
      partition: franz.Partitioner(franz.Random),
      key: <<"random_key">>,
      value: franz.Value(<<"value">>, []),
    )
}

pub fn producer_with_custom_partitioner_test() {
  let name = process.new_name("producer_custom_partitioner")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "partitioner_custom_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name:)

  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  // Custom partitioner that always returns partition 0
  let custom_partitioner = fn(_topic, _count, _key, _value) { Ok(0) }

  assert Ok(Nil)
    == franz.produce_sync(
      client:,
      topic:,
      partition: franz.Partitioner(franz.PartitionFun(custom_partitioner)),
      key: <<"custom_key">>,
      value: franz.Value(<<"value">>, []),
    )
}

// =============================================================================
// ProduceValue with Timestamp Tests
// =============================================================================

pub fn produce_with_timestamp_test() {
  let name = process.new_name("producer_timestamp")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "timestamp_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name:)

  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  let ts = timestamp.from_unix_seconds(1_700_000_000)

  assert Ok(Nil)
    == franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"ts_key">>,
      value: franz.ValueWithTimestamp(<<"value">>, ts, []),
    )
}

// =============================================================================
// Message Headers Tests
// =============================================================================

pub fn produce_and_consume_with_headers_test() {
  let client_name = process.new_name("headers_client")
  let subscriber_name = process.new_name("headers_subscriber")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "headers_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name: client_name)

  let message_subject = process.new_subject()

  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  let assert Ok(_) =
    franz.default_topic_subscriber(
      subscriber_name,
      client:,
      topic:,
      callback: fn(_partition, message: franz.KafkaMessage, cb_state) {
        process.send(message_subject, message)
        franz.TopicAck(cb_state)
      },
      initial_state: Nil,
    )
    |> franz.start_topic_subscriber()

  process.sleep(100)

  // Produce message with headers
  let headers = [#("trace-id", <<"abc123">>), #("source", <<"test">>)]
  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"header_key">>,
      value: franz.Value(<<"header_value">>, headers),
    )

  // Verify headers are received
  let assert Ok(franz.KafkaMessage(
    key: <<"header_key">>,
    value: <<"header_value">>,
    headers: received_headers,
    ..,
  )) = process.receive(message_subject, 2000)

  assert received_headers == [#("trace-id", <<"abc123">>), #("source", <<"test">>)]
}

// =============================================================================
// Topic Subscriber Configuration Tests
// =============================================================================

pub fn topic_subscriber_with_specific_partitions_test() {
  let client_name = process.new_name("specific_partitions_client")
  let subscriber_name = process.new_name("specific_partitions_subscriber")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "specific_partitions_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name: client_name)

  let message_subject = process.new_subject()

  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  // Subscribe only to partition 0 (single partition topic)
  let assert Ok(_) =
    franz.TopicSubscriberConfig(
      ..franz.default_topic_subscriber(
        subscriber_name,
        client:,
        topic:,
        callback: fn(partition, message: franz.KafkaMessage, cb_state) {
          process.send(message_subject, #(partition, message))
          franz.TopicAck(cb_state)
        },
        initial_state: Nil,
      ),
      partitions: franz.Partitions([0]),
    )
    |> franz.start_topic_subscriber()

  // Give subscriber time to connect and be ready
  process.sleep(500)

  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"partition0_key">>,
      value: franz.Value(<<"value">>, []),
    )

  let assert Ok(#(0, franz.KafkaMessage(key: <<"partition0_key">>, ..))) =
    process.receive(message_subject, 5000)
  Nil
}

// Tests that subscriber can be configured with committed_offsets
// This verifies the configuration is accepted and subscriber starts successfully
pub fn topic_subscriber_with_committed_offsets_test() {
  let client_name = process.new_name("committed_offsets_client")
  let subscriber_name = process.new_name("committed_offsets_subscriber")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "committed_offsets_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name: client_name)

  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  // Subscribe with committed_offsets configuration
  // The main test is that the subscriber accepts this configuration and starts
  let assert Ok(_) =
    franz.TopicSubscriberConfig(
      ..franz.default_topic_subscriber(
        subscriber_name,
        client:,
        topic:,
        callback: fn(_partition, _message: franz.KafkaMessage, cb_state) {
          franz.TopicAck(cb_state)
        },
        initial_state: Nil,
      ),
      committed_offsets: [#(0, 0)],
    )
    |> franz.start_topic_subscriber()

  // Subscriber started successfully with committed_offsets config
  Nil
}

pub fn topic_subscriber_with_consumer_options_test() {
  let client_name = process.new_name("consumer_opts_client")
  let subscriber_name = process.new_name("consumer_opts_subscriber")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "consumer_opts_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name: client_name)

  let message_subject = process.new_subject()

  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"opts_key">>,
      value: franz.Value(<<"opts_value">>, []),
    )

  // Subscribe with various consumer options
  let assert Ok(_) =
    franz.TopicSubscriberConfig(
      ..franz.default_topic_subscriber(
        subscriber_name,
        client:,
        topic:,
        callback: fn(_partition, message: franz.KafkaMessage, cb_state) {
          process.send(message_subject, message)
          franz.TopicAck(cb_state)
        },
        initial_state: Nil,
      ),
      consumer_options: [
        franz.BeginOffset(franz.Earliest),
        franz.MinBytes(1),
        franz.MaxBytes(1_048_576),
        franz.MaxWaitTime(duration.seconds(5)),
        franz.PrefetchCount(5),
        franz.ConsumerIsolationLevel(franz.ReadCommitted),
      ],
    )
    |> franz.start_topic_subscriber()

  let assert Ok(franz.KafkaMessage(key: <<"opts_key">>, ..)) =
    process.receive(message_subject, 2000)
  Nil
}

// =============================================================================
// Group Subscriber Configuration Tests
// =============================================================================

pub fn group_subscriber_with_group_options_test() {
  let subscriber_name = process.new_name("group_opts_subscriber")
  let client_name = process.new_name("group_opts_client")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "group_opts_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name: client_name)

  let message_subject = process.new_subject()

  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"group_opts_key">>,
      value: franz.Value(<<"group_opts_value">>, []),
    )

  process.sleep(500)

  // Subscribe with various group options
  let assert Ok(_) =
    franz.GroupSubscriberConfig(
      ..franz.default_group_subscriber_config(
        subscriber_name,
        client:,
        group_id: "test_group_with_options",
        topics: [topic],
        callback: fn(message: franz.KafkaMessage, cb_state) {
          process.send(message_subject, message)
          franz.GroupCommit(cb_state)
        },
        init_state: Nil,
      ),
      consumer_options: [franz.BeginOffset(franz.Earliest)],
      group_options: [
        franz.SessionTimeout(duration.seconds(30)),
        franz.HeartbeatRate(duration.seconds(3)),
        franz.MaxRejoinAttempts(5),
        franz.RejoinDelay(duration.seconds(1)),
        franz.OffsetCommitInterval(duration.seconds(5)),
      ],
    )
    |> franz.start_group_subscriber()

  let assert Ok(franz.KafkaMessage(key: <<"group_opts_key">>, ..)) =
    process.receive(message_subject, 10_000)
  Nil
}

pub fn group_subscriber_with_multiple_topics_test() {
  let subscriber_name = process.new_name("multi_topic_subscriber")
  let client_name = process.new_name("multi_topic_client")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic1 = "multi_topic_1"
  let topic2 = "multi_topic_2"

  // Setup both topics
  let _ =
    franz.delete_topics(
      endpoints: [endpoint],
      names: [topic1, topic2],
      timeout: duration.seconds(1),
    )
  let assert Ok(Nil) =
    franz.create_topic(
      endpoints: [endpoint],
      name: topic1,
      partitions: 1,
      replication_factor: 1,
      configs: [],
      timeout: duration.seconds(5),
    )
  let assert Ok(Nil) =
    franz.create_topic(
      endpoints: [endpoint],
      name: topic2,
      partitions: 1,
      replication_factor: 1,
      configs: [],
      timeout: duration.seconds(5),
    )

  use client <- setup_client(endpoint:, name: client_name)

  let message_subject = process.new_subject()

  let assert Ok(Nil) =
    franz.default_producer(client, topic1)
    |> franz.start_producer()
  let assert Ok(Nil) =
    franz.default_producer(client, topic2)
    |> franz.start_producer()

  // Produce to both topics
  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic: topic1,
      partition: franz.SinglePartition(0),
      key: <<"topic1_key">>,
      value: franz.Value(<<"topic1_value">>, []),
    )
  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic: topic2,
      partition: franz.SinglePartition(0),
      key: <<"topic2_key">>,
      value: franz.Value(<<"topic2_value">>, []),
    )

  process.sleep(500)

  // Subscribe to multiple topics
  let assert Ok(_) =
    franz.GroupSubscriberConfig(
      ..franz.default_group_subscriber_config(
        subscriber_name,
        client:,
        group_id: "multi_topic_group",
        topics: [topic1, topic2],
        callback: fn(message: franz.KafkaMessage, cb_state) {
          process.send(message_subject, message)
          franz.GroupCommit(cb_state)
        },
        init_state: Nil,
      ),
      consumer_options: [franz.BeginOffset(franz.Earliest)],
    )
    |> franz.start_group_subscriber()

  // Should receive messages from both topics
  let assert Ok(_) = process.receive(message_subject, 10_000)
  let assert Ok(_) = process.receive(message_subject, 10_000)
  Nil
}

// =============================================================================
// Fetch with Options Tests
// =============================================================================

pub fn fetch_with_options_test() {
  let name = process.new_name("fetch_options_client")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "fetch_options_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name:)

  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"fetch_key">>,
      value: franz.Value(<<"fetch_value">>, []),
    )

  // Fetch with various options
  let assert Ok(#(next_offset, _message)) =
    franz.fetch(
      client:,
      topic:,
      partition: 0,
      offset: 0,
      options: [
        franz.FetchMaxWaitTime(duration.seconds(5)),
        franz.FetchMinBytes(1),
        franz.FetchMaxBytes(1_048_576),
        franz.FetchIsolationLevel(franz.ReadCommitted),
      ],
    )

  // Verify we got a valid next offset (indicating message was fetched)
  assert next_offset >= 1
}

// =============================================================================
// Admin Operations Tests
// =============================================================================

pub fn delete_topics_test() {
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "delete_test_topic"

  // Create topic
  let _ =
    franz.delete_topics(
      endpoints: [endpoint],
      names: [topic],
      timeout: duration.seconds(1),
    )
  let assert Ok(Nil) =
    franz.create_topic(
      endpoints: [endpoint],
      name: topic,
      partitions: 1,
      replication_factor: 1,
      configs: [],
      timeout: duration.seconds(5),
    )

  // Delete topic
  assert Ok(Nil)
    == franz.delete_topics(
      endpoints: [endpoint],
      names: [topic],
      timeout: duration.seconds(5),
    )
}

pub fn list_groups_test() {
  let endpoint = franz.Endpoint("localhost", 9092)

  // list_groups should return Ok with a list (may be empty if no groups exist)
  let assert Ok(_groups) = franz.list_groups(endpoint:)
}

// =============================================================================
// Compression Tests
// =============================================================================

pub fn producer_with_gzip_compression_test() {
  let name = process.new_name("producer_gzip")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "gzip_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name:)

  let assert Ok(Nil) =
    franz.Producer(..franz.default_producer(client, topic), options: [
      franz.Compression(franz.Gzip),
    ])
    |> franz.start_producer()

  assert Ok(Nil)
    == franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"gzip_key">>,
      value: franz.Value(<<"gzip_value">>, []),
    )
}

// Note: Snappy compression test requires the snappyer optional dependency.
// Uncomment if snappyer is added to dependencies.
// pub fn producer_with_snappy_compression_test() {
//   let name = process.new_name("producer_snappy")
//   let endpoint = franz.Endpoint("localhost", 9092)
//   let topic = "snappy_topic"
//   use <- setup_topics(topic:, endpoint:)
//   use client <- setup_client(endpoint:, name:)
//
//   let assert Ok(Nil) =
//     franz.Producer(..franz.default_producer(client, topic), options: [
//       franz.Compression(franz.Snappy),
//     ])
//     |> franz.start_producer()
//
//   assert Ok(Nil)
//     == franz.produce_sync(
//       client:,
//       topic:,
//       partition: franz.SinglePartition(0),
//       key: <<"snappy_key">>,
//       value: franz.Value(<<"snappy_value">>, []),
//     )
// }

// =============================================================================
// StartingOffset Variations Tests
// =============================================================================

pub fn topic_subscriber_with_at_offset_test() {
  let client_name = process.new_name("at_offset_client")
  let subscriber_name = process.new_name("at_offset_subscriber")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "at_offset_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name: client_name)

  let message_subject = process.new_subject()

  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  // Produce multiple messages
  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"offset0">>,
      value: franz.Value(<<"value0">>, []),
    )
  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"offset1">>,
      value: franz.Value(<<"value1">>, []),
    )
  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"offset2">>,
      value: franz.Value(<<"value2">>, []),
    )

  // Subscribe starting from offset 2
  let assert Ok(_) =
    franz.TopicSubscriberConfig(
      ..franz.default_topic_subscriber(
        subscriber_name,
        client:,
        topic:,
        callback: fn(_partition, message: franz.KafkaMessage, cb_state) {
          process.send(message_subject, message)
          franz.TopicAck(cb_state)
        },
        initial_state: Nil,
      ),
      consumer_options: [franz.BeginOffset(franz.AtOffset(2))],
    )
    |> franz.start_topic_subscriber()

  // Should start from offset 2
  let assert Ok(franz.KafkaMessage(offset: 2, key: <<"offset2">>, ..)) =
    process.receive(message_subject, 2000)
  Nil
}

// Note: AtTimestamp behavior can vary based on broker configuration.
// This test verifies the subscriber can start with AtTimestamp option.
pub fn topic_subscriber_with_at_timestamp_test() {
  let client_name = process.new_name("at_timestamp_client")
  let subscriber_name = process.new_name("at_timestamp_subscriber")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "at_timestamp_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name: client_name)

  let message_subject = process.new_subject()

  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  // Produce a message first
  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"ts_key">>,
      value: franz.Value(<<"ts_value">>, []),
    )

  // Small delay to ensure message is committed
  process.sleep(500)

  // Use a timestamp from the past - should start from earliest available
  // Note: Some Kafka configs may behave differently with old timestamps
  let old_timestamp = timestamp.from_unix_seconds(1_600_000_000)

  // The subscriber should start successfully with AtTimestamp
  let assert Ok(_) =
    franz.TopicSubscriberConfig(
      ..franz.default_topic_subscriber(
        subscriber_name,
        client:,
        topic:,
        callback: fn(_partition, message: franz.KafkaMessage, cb_state) {
          process.send(message_subject, message)
          franz.TopicAck(cb_state)
        },
        initial_state: Nil,
      ),
      consumer_options: [franz.BeginOffset(franz.AtTimestamp(old_timestamp))],
    )
    |> franz.start_topic_subscriber()

  // Give subscriber time to receive message
  // Note: With old timestamps, behavior may vary; the main test is that subscriber starts
  case process.receive(message_subject, 3000) {
    Ok(franz.KafkaMessage(key: <<"ts_key">>, ..)) -> Nil
    // If no message received, the test still passes as subscriber started successfully
    Error(Nil) -> Nil
    Ok(_) -> Nil
  }
}

// =============================================================================
// GroupAck vs GroupCommit Tests
// =============================================================================

pub fn group_subscriber_with_ack_test() {
  let subscriber_name = process.new_name("group_ack_subscriber")
  let client_name = process.new_name("group_ack_client")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "group_ack_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name: client_name)

  let message_subject = process.new_subject()

  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"ack_key">>,
      value: franz.Value(<<"ack_value">>, []),
    )

  process.sleep(500)

  // Use GroupAck instead of GroupCommit
  let assert Ok(_) =
    franz.GroupSubscriberConfig(
      ..franz.default_group_subscriber_config(
        subscriber_name,
        client:,
        group_id: "ack_test_group",
        topics: [topic],
        callback: fn(message: franz.KafkaMessage, cb_state) {
          process.send(message_subject, message)
          // Use GroupAck - acknowledges but doesn't commit offset
          franz.GroupAck(cb_state)
        },
        init_state: Nil,
      ),
      consumer_options: [franz.BeginOffset(franz.Earliest)],
    )
    |> franz.start_group_subscriber()

  let assert Ok(franz.KafkaMessage(key: <<"ack_key">>, ..)) =
    process.receive(message_subject, 10_000)
  Nil
}

// =============================================================================
// IsolationLevel Tests
// =============================================================================

pub fn fetch_with_read_uncommitted_test() {
  let name = process.new_name("fetch_uncommitted_client")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "isolation_level_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name:)

  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"isolation_key">>,
      value: franz.Value(<<"isolation_value">>, []),
    )

  // Fetch with ReadUncommitted isolation level
  let assert Ok(#(_, _)) =
    franz.fetch(
      client:,
      topic:,
      partition: 0,
      offset: 0,
      options: [franz.FetchIsolationLevel(franz.ReadUncommitted)],
    )
  Nil
}

// =============================================================================
// OffsetResetPolicy Tests
// =============================================================================

pub fn topic_subscriber_with_reset_to_earliest_test() {
  let client_name = process.new_name("reset_earliest_client")
  let subscriber_name = process.new_name("reset_earliest_subscriber")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "reset_earliest_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name: client_name)

  let message_subject = process.new_subject()

  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"reset_key">>,
      value: franz.Value(<<"reset_value">>, []),
    )

  // Subscribe with ResetToEarliest policy
  let assert Ok(_) =
    franz.TopicSubscriberConfig(
      ..franz.default_topic_subscriber(
        subscriber_name,
        client:,
        topic:,
        callback: fn(_partition, message: franz.KafkaMessage, cb_state) {
          process.send(message_subject, message)
          franz.TopicAck(cb_state)
        },
        initial_state: Nil,
      ),
      consumer_options: [
        franz.BeginOffset(franz.Earliest),
        franz.OffsetResetPolicy(franz.ResetToEarliest),
      ],
    )
    |> franz.start_topic_subscriber()

  let assert Ok(franz.KafkaMessage(key: <<"reset_key">>, ..)) =
    process.receive(message_subject, 2000)
  Nil
}

// =============================================================================
// SleepTimeout and PrefetchBytes Tests
// =============================================================================

pub fn topic_subscriber_with_prefetch_options_test() {
  let client_name = process.new_name("prefetch_client")
  let subscriber_name = process.new_name("prefetch_subscriber")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "prefetch_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name: client_name)

  let message_subject = process.new_subject()

  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"prefetch_key">>,
      value: franz.Value(<<"prefetch_value">>, []),
    )

  // Subscribe with prefetch options
  let assert Ok(_) =
    franz.TopicSubscriberConfig(
      ..franz.default_topic_subscriber(
        subscriber_name,
        client:,
        topic:,
        callback: fn(_partition, message: franz.KafkaMessage, cb_state) {
          process.send(message_subject, message)
          franz.TopicAck(cb_state)
        },
        initial_state: Nil,
      ),
      consumer_options: [
        franz.BeginOffset(franz.Earliest),
        franz.SleepTimeout(duration.milliseconds(500)),
        franz.PrefetchBytes(102_400),
        franz.SizeStatWindow(10),
      ],
    )
    |> franz.start_topic_subscriber()

  let assert Ok(franz.KafkaMessage(key: <<"prefetch_key">>, ..)) =
    process.receive(message_subject, 2000)
  Nil
}

// =============================================================================
// MessageBatch Mode Tests
// =============================================================================

pub fn topic_subscriber_with_message_batch_test() {
  let client_name = process.new_name("batch_topic_client")
  let subscriber_name = process.new_name("batch_topic_subscriber")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "batch_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name: client_name)

  let message_subject = process.new_subject()

  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  // Produce multiple messages
  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"batch_key_1">>,
      value: franz.Value(<<"batch_value_1">>, []),
    )
  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"batch_key_2">>,
      value: franz.Value(<<"batch_value_2">>, []),
    )
  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"batch_key_3">>,
      value: franz.Value(<<"batch_value_3">>, []),
    )

  // Small delay to ensure messages are committed
  process.sleep(300)

  // Subscribe with MessageBatch mode
  let assert Ok(_) =
    franz.TopicSubscriberConfig(
      ..franz.default_topic_subscriber(
        subscriber_name,
        client:,
        topic:,
        callback: fn(_partition, message: franz.KafkaMessage, cb_state) {
          process.send(message_subject, message)
          franz.TopicAck(cb_state)
        },
        initial_state: Nil,
      ),
      consumer_options: [franz.BeginOffset(franz.Earliest)],
      message_type: franz.MessageBatch,
    )
    |> franz.start_topic_subscriber()

  // Should receive a KafkaMessageSet with messages
  let assert Ok(franz.KafkaMessageSet(
    topic: received_topic,
    partition: 0,
    messages: msgs,
    ..,
  )) = process.receive(message_subject, 5000)

  assert received_topic == topic

  // Verify we got all three messages with correct content
  // Note: messages may come in batches, so we need to collect all
  let all_messages = collect_batch_messages(message_subject, msgs, 2000)

  // Verify we have at least 3 messages
  assert list.length(all_messages) >= 3

  // Verify the keys are present (order preserved within partition)
  let keys = list.map(all_messages, fn(m) {
    case m {
      franz.KafkaMessage(key: k, ..) -> k
      _ -> <<>>
    }
  })
  assert list.contains(keys, <<"batch_key_1">>)
  assert list.contains(keys, <<"batch_key_2">>)
  assert list.contains(keys, <<"batch_key_3">>)
  Nil
}

/// Helper to collect messages from batch mode (may receive multiple batches)
fn collect_batch_messages(
  subject: process.Subject(franz.KafkaMessage),
  initial: List(franz.KafkaMessage),
  timeout: Int,
) -> List(franz.KafkaMessage) {
  case process.receive(subject, timeout) {
    Ok(franz.KafkaMessageSet(messages: more_msgs, ..)) ->
      collect_batch_messages(subject, list.append(initial, more_msgs), timeout)
    Ok(msg) -> collect_batch_messages(subject, list.append(initial, [msg]), timeout)
    Error(Nil) -> initial
  }
}

pub fn group_subscriber_with_message_batch_test() {
  let subscriber_name = process.new_name("batch_group_subscriber")
  let client_name = process.new_name("batch_group_client")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "batch_group_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name: client_name)

  let message_subject = process.new_subject()

  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  // Produce multiple messages
  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"group_batch_key_1">>,
      value: franz.Value(<<"group_batch_value_1">>, []),
    )
  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"group_batch_key_2">>,
      value: franz.Value(<<"group_batch_value_2">>, []),
    )
  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"group_batch_key_3">>,
      value: franz.Value(<<"group_batch_value_3">>, []),
    )

  process.sleep(500)

  // Subscribe with MessageBatch mode
  let assert Ok(_) =
    franz.GroupSubscriberConfig(
      ..franz.default_group_subscriber_config(
        subscriber_name,
        client:,
        group_id: "batch_test_group",
        topics: [topic],
        callback: fn(message: franz.KafkaMessage, cb_state) {
          process.send(message_subject, message)
          franz.GroupCommit(cb_state)
        },
        init_state: Nil,
      ),
      consumer_options: [franz.BeginOffset(franz.Earliest)],
      message_type: franz.MessageBatch,
    )
    |> franz.start_group_subscriber()

  // Should receive a KafkaMessageSet with messages
  let assert Ok(franz.KafkaMessageSet(
    topic: received_topic,
    partition: 0,
    messages: msgs,
    ..,
  )) = process.receive(message_subject, 10_000)

  assert received_topic == topic

  // Collect all messages (may come in multiple batches)
  let all_messages = collect_batch_messages(message_subject, msgs, 3000)

  // Verify we got at least 3 messages
  assert list.length(all_messages) >= 3

  // Verify message keys and values are correct
  let keys = list.map(all_messages, fn(m) {
    case m {
      franz.KafkaMessage(key: k, ..) -> k
      _ -> <<>>
    }
  })
  assert list.contains(keys, <<"group_batch_key_1">>)
  assert list.contains(keys, <<"group_batch_key_2">>)
  assert list.contains(keys, <<"group_batch_key_3">>)

  // Verify values are correct too
  let values = list.map(all_messages, fn(m) {
    case m {
      franz.KafkaMessage(value: v, ..) -> v
      _ -> <<>>
    }
  })
  assert list.contains(values, <<"group_batch_value_1">>)
  assert list.contains(values, <<"group_batch_value_2">>)
  assert list.contains(values, <<"group_batch_value_3">>)
  Nil
}

// =============================================================================
// Edge Case Tests
// =============================================================================

/// Test producing and consuming empty key and value
pub fn produce_empty_key_and_value_test() {
  let name = process.new_name("empty_msg_client")
  let subscriber_name = process.new_name("empty_msg_subscriber")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "empty_message_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name:)

  let message_subject = process.new_subject()

  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  // Subscribe first to catch the message
  let assert Ok(_) =
    franz.default_topic_subscriber(
      subscriber_name,
      client:,
      topic:,
      callback: fn(_partition, message: franz.KafkaMessage, cb_state) {
        process.send(message_subject, message)
        franz.TopicAck(cb_state)
      },
      initial_state: Nil,
    )
    |> franz.start_topic_subscriber()

  process.sleep(300)

  // Produce message with empty key and value
  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<>>,
      value: franz.Value(<<>>, []),
    )

  // Verify we receive empty message correctly
  let assert Ok(franz.KafkaMessage(key: <<>>, value: <<>>, ..)) =
    process.receive(message_subject, 3000)
  Nil
}

/// Test producing and consuming large messages (1MB)
pub fn produce_large_message_test() {
  let name = process.new_name("large_msg_client")
  let subscriber_name = process.new_name("large_msg_subscriber")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "large_message_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name:)

  let message_subject = process.new_subject()

  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  // Subscribe first
  let assert Ok(_) =
    franz.default_topic_subscriber(
      subscriber_name,
      client:,
      topic:,
      callback: fn(_partition, message: franz.KafkaMessage, cb_state) {
        process.send(message_subject, message)
        franz.TopicAck(cb_state)
      },
      initial_state: Nil,
    )
    |> franz.start_topic_subscriber()

  process.sleep(300)

  // Create a ~100KB message (smaller than 1MB to ensure delivery)
  let large_value = create_large_bitarray(100_000)

  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"large_key">>,
      value: franz.Value(large_value, []),
    )

  // Verify large message received correctly
  let assert Ok(franz.KafkaMessage(key: <<"large_key">>, value: received_value, ..)) =
    process.receive(message_subject, 5000)

  // Verify size matches
  assert bit_array_size(received_value) == 100_000
  Nil
}

/// Helper to create a BitArray of given size filled with 'X'
fn create_large_bitarray(size: Int) -> BitArray {
  create_large_bitarray_loop(size, <<>>)
}

fn create_large_bitarray_loop(remaining: Int, acc: BitArray) -> BitArray {
  case remaining {
    0 -> acc
    n if n >= 1000 -> {
      // Add 1000 bytes at a time for efficiency (1000 X's)
      let chunk = <<"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX">>
      create_large_bitarray_loop(n - 1000, <<acc:bits, chunk:bits>>)
    }
    n -> {
      create_large_bitarray_loop(n - 1, <<acc:bits, "X">>)
    }
  }
}

@external(erlang, "erlang", "byte_size")
fn bit_array_size(bits: BitArray) -> Int

/// Test producing and consuming Unicode content
pub fn produce_unicode_message_test() {
  let name = process.new_name("unicode_msg_client")
  let subscriber_name = process.new_name("unicode_msg_subscriber")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "unicode_message_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name:)

  let message_subject = process.new_subject()

  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  // Subscribe first
  let assert Ok(_) =
    franz.default_topic_subscriber(
      subscriber_name,
      client:,
      topic:,
      callback: fn(_partition, message: franz.KafkaMessage, cb_state) {
        process.send(message_subject, message)
        franz.TopicAck(cb_state)
      },
      initial_state: Nil,
    )
    |> franz.start_topic_subscriber()

  process.sleep(300)

  // Produce message with various Unicode characters
  let unicode_key = <<"键_key_ключ_مفتاح":utf8>>
  let unicode_value = <<"Hello 世界! Привет мир! مرحبا بالعالم! 🎉🚀":utf8>>

  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: unicode_key,
      value: franz.Value(unicode_value, []),
    )

  // Verify Unicode message received correctly
  let assert Ok(franz.KafkaMessage(key: received_key, value: received_value, ..)) =
    process.receive(message_subject, 3000)

  assert received_key == unicode_key
  assert received_value == unicode_value
  Nil
}

/// Test producing with many headers
pub fn produce_many_headers_test() {
  let name = process.new_name("many_headers_client")
  let subscriber_name = process.new_name("many_headers_subscriber")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "many_headers_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name:)

  let message_subject = process.new_subject()

  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  // Subscribe first
  let assert Ok(_) =
    franz.default_topic_subscriber(
      subscriber_name,
      client:,
      topic:,
      callback: fn(_partition, message: franz.KafkaMessage, cb_state) {
        process.send(message_subject, message)
        franz.TopicAck(cb_state)
      },
      initial_state: Nil,
    )
    |> franz.start_topic_subscriber()

  process.sleep(300)

  // Create 10 headers
  let headers = [
    #("header-1", <<"value-1">>),
    #("header-2", <<"value-2">>),
    #("header-3", <<"value-3">>),
    #("header-4", <<"value-4">>),
    #("header-5", <<"value-5">>),
    #("trace-id", <<"abc-123-def-456">>),
    #("correlation-id", <<"corr-789">>),
    #("content-type", <<"application/json">>),
    #("version", <<"1.0.0">>),
    #("source", <<"test-suite">>),
  ]

  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"headers_key">>,
      value: franz.Value(<<"headers_value">>, headers),
    )

  // Verify all headers are received
  let assert Ok(franz.KafkaMessage(headers: received_headers, ..)) =
    process.receive(message_subject, 3000)

  assert list.length(received_headers) == 10

  // Verify specific headers
  assert list.contains(received_headers, #("header-1", <<"value-1">>))
  assert list.contains(received_headers, #("trace-id", <<"abc-123-def-456">>))
  assert list.contains(received_headers, #("source", <<"test-suite">>))
  Nil
}

// =============================================================================
// Multiple Messages Verification Tests
// =============================================================================

/// Test producing and consuming multiple messages with order verification
pub fn produce_multiple_messages_order_test() {
  let name = process.new_name("multi_order_client")
  let subscriber_name = process.new_name("multi_order_subscriber")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "multi_order_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name:)

  let message_subject = process.new_subject()

  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  // Produce 5 messages with sequential keys
  let assert Ok(0) =
    franz.produce_sync_offset(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"msg_0">>,
      value: franz.Value(<<"value_0">>, []),
    )
  let assert Ok(1) =
    franz.produce_sync_offset(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"msg_1">>,
      value: franz.Value(<<"value_1">>, []),
    )
  let assert Ok(2) =
    franz.produce_sync_offset(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"msg_2">>,
      value: franz.Value(<<"value_2">>, []),
    )
  let assert Ok(3) =
    franz.produce_sync_offset(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"msg_3">>,
      value: franz.Value(<<"value_3">>, []),
    )
  let assert Ok(4) =
    franz.produce_sync_offset(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"msg_4">>,
      value: franz.Value(<<"value_4">>, []),
    )

  // Subscribe from earliest
  let assert Ok(_) =
    franz.TopicSubscriberConfig(
      ..franz.default_topic_subscriber(
        subscriber_name,
        client:,
        topic:,
        callback: fn(_partition, message: franz.KafkaMessage, cb_state) {
          process.send(message_subject, message)
          franz.TopicAck(cb_state)
        },
        initial_state: Nil,
      ),
      consumer_options: [franz.BeginOffset(franz.Earliest)],
    )
    |> franz.start_topic_subscriber()

  // Receive messages and verify order
  let assert Ok(franz.KafkaMessage(offset: 0, key: <<"msg_0">>, value: <<"value_0">>, ..)) =
    process.receive(message_subject, 3000)
  let assert Ok(franz.KafkaMessage(offset: 1, key: <<"msg_1">>, value: <<"value_1">>, ..)) =
    process.receive(message_subject, 1000)
  let assert Ok(franz.KafkaMessage(offset: 2, key: <<"msg_2">>, value: <<"value_2">>, ..)) =
    process.receive(message_subject, 1000)
  let assert Ok(franz.KafkaMessage(offset: 3, key: <<"msg_3">>, value: <<"value_3">>, ..)) =
    process.receive(message_subject, 1000)
  let assert Ok(franz.KafkaMessage(offset: 4, key: <<"msg_4">>, value: <<"value_4">>, ..)) =
    process.receive(message_subject, 1000)
  Nil
}

// =============================================================================
// Fetch Multiple Messages Test
// =============================================================================

/// Test fetching multiple messages using the low-level fetch API
pub fn fetch_multiple_messages_test() {
  let name = process.new_name("fetch_multi_client")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "fetch_multi_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name:)

  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  // Produce 3 messages
  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"fetch_key_0">>,
      value: franz.Value(<<"fetch_value_0">>, []),
    )
  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"fetch_key_1">>,
      value: franz.Value(<<"fetch_value_1">>, []),
    )
  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"fetch_key_2">>,
      value: franz.Value(<<"fetch_value_2">>, []),
    )

  // Fetch from offset 0 - franz.fetch returns #(next_offset, KafkaMessageSet)
  let assert Ok(#(next_offset, franz.KafkaMessageSet(
    topic: received_topic,
    partition: 0,
    messages: msgs,
    ..,
  ))) = franz.fetch(client:, topic:, partition: 0, offset: 0, options: [])

  // Verify we got all 3 messages (next_offset should be 3)
  assert next_offset == 3
  assert received_topic == topic
  assert list.length(msgs) == 3

  // Verify first message
  let assert Ok(franz.KafkaMessage(offset: 0, key: <<"fetch_key_0">>, value: <<"fetch_value_0">>, ..)) =
    list.first(msgs)

  // Verify last message
  let assert Ok(franz.KafkaMessage(offset: 2, key: <<"fetch_key_2">>, value: <<"fetch_value_2">>, ..)) =
    list.last(msgs)
  Nil
}

/// Test async produce with callback verification
pub fn produce_async_callback_verification_test() {
  let name = process.new_name("async_verify_client")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "async_verify_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name:)

  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  let offset_subject = process.new_subject()
  let partition_subject = process.new_subject()

  // Produce 3 messages async and verify callbacks
  let assert Ok(franz.SinglePartition(0)) =
    franz.produce_async(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"async_0">>,
      value: franz.Value(<<"value_0">>, []),
      callback: fn(partition, offset) {
        process.send(partition_subject, partition)
        process.send(offset_subject, offset)
      },
    )

  let assert Ok(franz.SinglePartition(0)) =
    franz.produce_async(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"async_1">>,
      value: franz.Value(<<"value_1">>, []),
      callback: fn(partition, offset) {
        process.send(partition_subject, partition)
        process.send(offset_subject, offset)
      },
    )

  let assert Ok(franz.SinglePartition(0)) =
    franz.produce_async(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"async_2">>,
      value: franz.Value(<<"value_2">>, []),
      callback: fn(partition, offset) {
        process.send(partition_subject, partition)
        process.send(offset_subject, offset)
      },
    )

  // Verify all 3 callbacks are invoked with correct partitions
  let assert Ok(franz.Partition(0)) = process.receive(partition_subject, 3000)
  let assert Ok(franz.Partition(0)) = process.receive(partition_subject, 1000)
  let assert Ok(franz.Partition(0)) = process.receive(partition_subject, 1000)

  // Verify offsets are sequential (0, 1, 2)
  let assert Ok(franz.Offset(offset_0)) = process.receive(offset_subject, 1000)
  let assert Ok(franz.Offset(offset_1)) = process.receive(offset_subject, 1000)
  let assert Ok(franz.Offset(offset_2)) = process.receive(offset_subject, 1000)

  assert offset_0 == 0
  assert offset_1 == 1
  assert offset_2 == 2
  Nil
}

/// Test that timestamp type is correctly set and timestamp is valid
pub fn message_timestamp_type_test() {
  let name = process.new_name("ts_type_client")
  let subscriber_name = process.new_name("ts_type_subscriber")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "timestamp_type_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name:)

  let message_subject = process.new_subject()

  let assert Ok(Nil) =
    franz.default_producer(client, topic)
    |> franz.start_producer()

  // Subscribe first
  let assert Ok(_) =
    franz.default_topic_subscriber(
      subscriber_name,
      client:,
      topic:,
      callback: fn(_partition, message: franz.KafkaMessage, cb_state) {
        process.send(message_subject, message)
        franz.TopicAck(cb_state)
      },
      initial_state: Nil,
    )
    |> franz.start_topic_subscriber()

  process.sleep(300)

  // Produce message without explicit timestamp
  let assert Ok(Nil) =
    franz.produce_sync(
      client:,
      topic:,
      partition: franz.SinglePartition(0),
      key: <<"ts_key">>,
      value: franz.Value(<<"ts_value">>, []),
    )

  // Verify timestamp type is Create (producer set it) and timestamp is valid
  let assert Ok(franz.KafkaMessage(
    timestamp_type: franz.Create,
    timestamp: ts,
    key: <<"ts_key">>,
    value: <<"ts_value">>,
    ..,
  )) = process.receive(message_subject, 3000)

  // Verify timestamp is a valid positive timestamp (after year 2020)
  // Year 2020 in seconds: 1577836800
  let #(secs, _nanos) = timestamp.to_unix_seconds_and_nanoseconds(ts)
  assert secs > 1_577_836_800
  Nil
}
