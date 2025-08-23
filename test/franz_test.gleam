import franz
import franz/consumer/config as consumer_config
import franz/consumer/group_subscriber
import franz/consumer/message_type
import franz/consumer/topic_subscriber
import franz/isolation_level
import franz/producer
import franz/producer/config as producer_config
import gleam/erlang/process
import gleam/int
import gleeunit

pub fn main() {
  gleeunit.main()
}

fn setup_topics(
  topic topic: String,
  endpoint endpoint: franz.Endpoint,
  fun fun: fn() -> Nil,
) {
  // Try to delete and recreate topics, but ignore errors in CI
  // where topics might be pre-created
  let _ =
    franz.delete_topics(endpoints: [endpoint], names: [topic], timeout_ms: 1000)
  
  // Try to create topic, but don't assert - it might already exist in CI
  let _ = franz.create_topic(
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
    franz.new([endpoint], name)
    |> franz.start
  let named_client = franz.named_client(name)

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
    franz.new([endpoint], name)
    |> franz.with_config(franz.RestartDelaySeconds(100))
    |> franz.with_config(franz.ReconnectCoolDownSeconds(100))
    |> franz.with_config(franz.AllowTopicAutoCreation(True))
    |> franz.with_config(franz.AutoStartProducers(True))
    |> franz.with_config(franz.UnknownTopicCacheTtl(120_000))
    |> franz.with_config(
      franz.DefaultProducerConfig([
        producer_config.RequiredAcks(1),
        producer_config.AckTimeout(1000),
        producer_config.PartitionBufferLimit(1000),
        producer_config.PartitionOnwireLimit(1000),
        producer_config.MaxBatchSize(1000),
        producer_config.MaxRetries(1000),
        producer_config.RetryBackoffMs(1000),
        producer_config.Compression(producer_config.NoCompression),
        producer_config.MaxLingerMs(1000),
        producer_config.MaxLingerCount(1000),
      ]),
    )
    |> franz.start()

  let client = franz.named_client(name)
  assert Nil == franz.stop_client(client)
}

pub fn producer_produce_sync_test() {
  let name = process.new_name("producer_sync")
  let endpoint = franz.Endpoint("localhost", 9092)
  let partition = producer.Partition(0)
  let topic = "test_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name:)
  let assert Ok(Nil) =
    producer.new(client, topic)
    |> producer.start()

  assert Ok(Nil)
    == producer.produce_sync(
      client:,
      topic:,
      partition:,
      key: <<"key">>,
      value: producer.Value(<<"value">>, []),
    )
}

pub fn producer_produce_sync_offset_test() {
  let name = process.new_name("producer_sync_offset")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "test_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name:)
  let assert Ok(Nil) =
    producer.new(client, topic)
    |> producer.start()

  assert Ok(0)
    == producer.produce_sync_offset(
      client: client,
      topic: "test_topic",
      partition: producer.Partition(0),
      key: <<"key">>,
      value: producer.Value(<<"value">>, []),
    )
}

pub fn producer_produce_cb_test() {
  let name = process.new_name("producer_callback")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "test_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name:)
  let assert Ok(Nil) =
    producer.new(client, topic)
    |> producer.start()
  let offset_subject = process.new_subject()
  let partition_subject = process.new_subject()

  assert Ok(producer.Partition(0))
    == producer.produce_cb(
      client: client,
      topic: "test_topic",
      partition: producer.Partition(0),
      key: <<"key">>,
      value: producer.Value(<<"value">>, []),
      callback: fn(partition, offset) {
        process.send(offset_subject, offset)
        process.send(partition_subject, partition)
      },
    )

  let assert Ok(producer.CbPartition(0)) =
    process.receive(partition_subject, 1000)
  let assert Ok(producer.CbOffset(0)) = process.receive(offset_subject, 1000)
  Nil
}

pub fn produce_no_ack_test() {
  let name = process.new_name("franz_test_producer")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "test_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name:)
  let assert Ok(Nil) =
    producer.new(client, topic)
    |> producer.start()

  assert Ok(Nil)
    == producer.produce_no_ack(
      client: client,
      topic: "test_topic",
      partition: producer.Partition(0),
      key: <<"key">>,
      value: producer.Value(<<"value">>, []),
    )
}

pub fn start_producer_with_config_test() {
  let name = process.new_name("franz_test_producer")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "test_topic"
  use <- setup_topics(topic:, endpoint:)
  use client <- setup_client(endpoint:, name:)

  assert Ok(Nil)
    == producer.new(client, topic)
    |> producer.with_config(producer_config.RequiredAcks(1))
    |> producer.with_config(producer_config.RequiredAcks(1))
    |> producer.with_config(producer_config.AckTimeout(1000))
    |> producer.with_config(producer_config.PartitionBufferLimit(1000))
    |> producer.with_config(producer_config.PartitionOnwireLimit(1000))
    |> producer.with_config(producer_config.MaxBatchSize(1000))
    |> producer.with_config(producer_config.MaxRetries(1000))
    |> producer.with_config(producer_config.RetryBackoffMs(1000))
    |> producer.with_config(producer_config.Compression(
      producer_config.NoCompression,
    ))
    |> producer.with_config(producer_config.MaxLingerMs(1000))
    |> producer.with_config(producer_config.MaxLingerCount(1000))
    |> producer.start()
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
    producer.new(client, topic)
    |> producer.start()

  let assert Ok(_actor_started) =
    topic_subscriber.new(
      name: subscriber_name,
      client:,
      topic:,
      partitions: topic_subscriber.Partitions([0]),
      message_type: message_type.Message,
      callback: fn(partition: Int, message: franz.KafkaMessage, cb_state: Int) {
        process.send(partition_subject, partition)
        process.send(message_subject, message)
        topic_subscriber.ack(cb_state)
      },
      init_callback_state: 0,
    )
    |> topic_subscriber.with_commited_offset(partition: 0, offset: -1)
    |> topic_subscriber.start()
  process.sleep(100)

  let assert Ok(Nil) =
    producer.produce_sync(
      client:,
      topic:,
      partition: producer.Partition(0),
      key: <<"key">>,
      value: producer.Value(<<"value">>, []),
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
    producer.new(client, topic)
    |> producer.start()
  
  assert Ok(Nil)
    == producer.produce_sync(
      client: client,
      topic:,
      partition: producer.Partition(0),
      key: <<"test_key">>,
      value: producer.Value(<<"test_value">>, []),
    )
  
  // Small delay to ensure message is committed
  process.sleep(500)

  // Now start the consumer with earliest offset to read the existing message
  let assert Ok(_) =
    group_subscriber.new(
      name: subscriber_name,
      client: client,
      group_id: "test_consumer_group_unique",
      topics: [topic],
      message_type: message_type.Message,
      callback: fn(message: franz.KafkaMessage, cb_state) {
        process.send(message_subject, message)
        group_subscriber.commit(cb_state)
      },
      init_callback_state: 0,
    )
    |> group_subscriber.with_consumer_config(consumer_config.BeginOffset(
      consumer_config.Earliest,
    ))
    |> group_subscriber.with_consumer_config(consumer_config.OffsetResetPolicy(
      consumer_config.ResetToEarliest,
    ))
    |> group_subscriber.start()
  
  // Wait for the consumer to read the message
  let assert Ok(franz.KafkaMessage(
    offset: 0,
    key: <<"test_key">>,
    value: <<"test_value">>,
    ..,
  )) = process.receive(message_subject, 10_000)
  process.sleep(500)
}
