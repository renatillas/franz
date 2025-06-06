import franz
import franz/consumer_config
import franz/group_subscriber
import franz/isolation_level
import franz/message_type
import franz/partitions
import franz/producer
import franz/producer_config
import franz/topic_subscriber
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn create_topic() {
  let topic = "test_topic"
  let endpoint = franz.Endpoint("127.0.0.1", 9092)
  franz.create_topic(
    endpoints: [endpoint],
    name: topic,
    partitions: 1,
    replication_factor: 1,
    configs: [],
    timeout_ms: 1000,
  )
  |> should.be_ok()
  franz.delete_topics(endpoints: [endpoint], names: [topic], timeout_ms: 10_000)
  |> should.be_ok()
}

pub fn start_stop_client_test() {
  let endpoint = franz.Endpoint("localhost", 9092)
  let client =
    franz.new([endpoint])
    |> franz.start()
    |> should.be_ok()

  franz.stop_client(client)
  |> should.equal(Nil)
}

pub fn start_client_with_config_test() {
  let endpoint = franz.Endpoint("localhost", 9092)
  let client =
    franz.new([endpoint])
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
    |> should.be_ok()

  franz.stop_client(client)
  |> should.equal(Nil)
}

pub fn produce_sync_test() {
  let endpoint = franz.Endpoint("localhost", 9092)
  let client =
    franz.new([endpoint])
    |> franz.start()
    |> should.be_ok()

  producer.new(client, "test_topic")
  |> producer.start()
  |> should.be_ok()

  producer.produce_sync(
    client: client,
    topic: "test_topic",
    partition: producer.Partition(0),
    key: <<"key">>,
    value: producer.Value(<<"value">>, []),
  )
  |> should.be_ok()
}

pub fn produce_sync_offset_test() {
  let endpoint = franz.Endpoint("localhost", 9092)
  let client =
    franz.new([endpoint])
    |> franz.start()
    |> should.be_ok()

  producer.new(client, "test_topic")
  |> producer.start()
  |> should.be_ok()

  producer.produce_sync_offset(
    client: client,
    topic: "test_topic",
    partition: producer.Partition(0),
    key: <<"key">>,
    value: producer.Value(<<"value">>, []),
  )
  |> should.be_ok()
}

pub fn produce_cb_test() {
  let endpoint = franz.Endpoint("localhost", 9092)
  let client =
    franz.new([endpoint])
    |> franz.start()
    |> should.be_ok()

  producer.new(client, "test_topic")
  |> producer.start()
  |> should.be_ok()

  producer.produce_cb(
    client: client,
    topic: "test_topic",
    partition: producer.Partition(0),
    key: <<"key">>,
    value: producer.Value(<<"value">>, []),
    callback: fn(partition, offset) {
      partition |> should.equal(producer.CbPartition(0))
      let producer.CbOffset(offset) = offset
      let assert True = offset > 0
    },
  )
  |> should.be_ok()
}

pub fn produce_no_ack_test() {
  let endpoint = franz.Endpoint("localhost", 9092)
  let client =
    franz.new([endpoint])
    |> franz.start()
    |> should.be_ok()

  producer.new(client, "test_topic")
  |> producer.start()
  |> should.be_ok()

  producer.produce_no_ack(
    client: client,
    topic: "test_topic",
    partition: producer.Partition(0),
    key: <<"key">>,
    value: producer.Value(<<"value">>, []),
  )
  |> should.be_ok()
}

pub fn start_producer_with_config_test() {
  let endpoint = franz.Endpoint("localhost", 9092)
  let client =
    franz.new([endpoint])
    |> franz.start()
    |> should.be_ok()

  producer.new(client, "test_topic")
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
  |> should.be_ok()
}

pub fn start_topic_subscriber_test() {
  let endpoint = franz.Endpoint("localhost", 9092)
  let client =
    franz.new([endpoint])
    |> franz.with_config(franz.AutoStartProducers(True))
    |> franz.start()
    |> should.be_ok()

  topic_subscriber.new(
    client: client,
    topic: "test_topic",
    partitions: partitions.Partitions([0]),
    message_type: message_type.Message,
    callback: fn(partition, message, cb_state) {
      partition |> should.equal(0)
      let assert franz.KafkaMessage(
        offset,
        <<"key">>,
        <<"value">>,
        franz.Create,
        _timestamp,
        [],
      ) = message
      let assert True = offset > 0
      topic_subscriber.ack(cb_state)
    },
    init_callback_state: 0,
  )
  |> topic_subscriber.with_commited_offset(partition: 0, offset: 0)
  |> topic_subscriber.start()
  |> should.be_ok()

  producer.produce_sync(
    client: client,
    topic: "test_topic",
    partition: producer.Partition(0),
    key: <<"key">>,
    value: producer.Value(<<"value">>, []),
  )
  |> should.be_ok()
}

pub fn start_group_subscriber_test() {
  let endpoint = franz.Endpoint("localhost", 9092)
  let client =
    franz.new([endpoint])
    |> franz.with_config(franz.AutoStartProducers(True))
    |> franz.start()
    |> should.be_ok()

  group_subscriber.new(
    client: client,
    group_id: "test_group",
    topics: ["test_topic"],
    message_type: message_type.Message,
    callback: fn(message: franz.KafkaMessage, cb_state) {
      let assert franz.KafkaMessage(
        offset,
        <<"key">>,
        <<"value">>,
        franz.Create,
        _timestamp,
        [],
      ) = message
      let assert True = offset > 0
      group_subscriber.commit(cb_state)
    },
    init_callback_state: 0,
  )
  |> group_subscriber.with_consumer_config(consumer_config.IsolationLevel(
    isolation_level.ReadUncommitted,
  ))
  |> group_subscriber.start()
  |> should.be_ok()

  producer.produce_sync(
    client: client,
    topic: "test_topic",
    partition: producer.Partition(0),
    key: <<"key">>,
    value: producer.Value(<<"value">>, []),
  )
  |> should.be_ok()
}
