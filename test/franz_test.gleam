import franz
import gleam/erlang/process
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
    franz.delete_topics(endpoints: [endpoint], names: [topic], timeout_ms: 1000)

  let _ =
    franz.create_topic(
      endpoints: [endpoint],
      name: topic,
      partitions: 1,
      replication_factor: 1,
      configs: [],
      timeout_ms: 5000,
    )

  fun()
}

fn setup_client(
  endpoint endpoint: franz.Endpoint,
  name name: process.Name(franz.Message),
  fun fun: fn(franz.Client) -> Nil,
) {
  let assert Ok(_actor_started) =
    franz.client()
    |> franz.endpoints([endpoint])
    |> franz.name(name)
    |> franz.start()
  let named_client = franz.named(name)

  fun(named_client)
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
      timeout_ms: 5000,
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
    franz.client()
    |> franz.endpoints([endpoint])
    |> franz.name(name)
    |> franz.option(franz.RestartDelaySeconds(100))
    |> franz.option(franz.ReconnectCoolDownSeconds(100))
    |> franz.option(franz.AllowTopicAutoCreation(True))
    |> franz.option(franz.AutoStartProducers(True))
    |> franz.option(franz.UnknownTopicCacheTtl(120_000))
    |> franz.option(
      franz.DefaultProducerConfig([
        franz.RequiredAcks(1),
        franz.AckTimeout(1000),
        franz.PartitionBufferLimit(1000),
        franz.PartitionOnWireLimit(1000),
        franz.MaxBatchSize(1000),
        franz.MaxRetries(1000),
        franz.RetryBackoffMs(1000),
        franz.Compression(franz.NoCompression),
        franz.MaxLingerMs(1000),
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
    franz.producer(client, topic)
    |> franz.producer_start()

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
    franz.producer(client, topic)
    |> franz.producer_start()

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
    franz.producer(client, topic)
    |> franz.producer_start()
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
    franz.producer(client, topic)
    |> franz.producer_start()

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
    == franz.producer(client, topic)
    |> franz.producer_option(franz.RequiredAcks(1))
    |> franz.producer_option(franz.RequiredAcks(1))
    |> franz.producer_option(franz.AckTimeout(1000))
    |> franz.producer_option(franz.PartitionBufferLimit(1000))
    |> franz.producer_option(franz.PartitionOnWireLimit(1000))
    |> franz.producer_option(franz.MaxBatchSize(1000))
    |> franz.producer_option(franz.MaxRetries(1000))
    |> franz.producer_option(franz.RetryBackoffMs(1000))
    |> franz.producer_option(franz.Compression(franz.NoCompression))
    |> franz.producer_option(franz.MaxLingerMs(1000))
    |> franz.producer_option(franz.MaxLingerCount(1000))
    |> franz.producer_start()
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
    franz.producer(client, topic)
    |> franz.producer_start()

  let assert Ok(_actor_started) =
    franz.TopicSubscriberConfig(
      ..franz.default_topic_subscriber(
        subscriber_name,
        client:,
        topic:,
        callback: fn(partition: Int, message: franz.KafkaMessage, cb_state: Int) {
          process.send(partition_subject, partition)
          process.send(message_subject, message)
          franz.TopicAck(cb_state)
        },
        initial_state: 0,
      ),
      partitions: franz.Partitions([0]),
      message_type: franz.SingleMessage,
      committed_offsets: [#(0, -1)],
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

  // Check the important fields
  assert Ok(Nil)
    == franz.delete_topics(
      endpoints: [endpoint],
      names: ["test_topic"],
      timeout_ms: 1000,
    )
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
    franz.producer(client, topic)
    |> franz.producer_start()

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

  // Now start the consumer with earliest offset to read the existing message
  let assert Ok(_) =
    franz.GroupSubscriberConfig(
      ..franz.default_group_subscriber_config(
        subscriber_name,
        client:,
        group_id: "test_consumer_group_unique",
        topics: [topic],
        callback: fn(message: franz.KafkaMessage, cb_state) {
          process.send(message_subject, message)
          franz.GroupCommit(cb_state)
        },
        init_state: 0,
      ),
      consumer_options: [
        franz.BeginOffset(franz.Earliest),
        franz.OffsetResetPolicy(franz.ResetToEarliest),
      ],
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
    == franz.producer(client, topic)
    |> franz.producer_option(franz.Compression(franz.Lz4))
    |> franz.producer_start()
}
