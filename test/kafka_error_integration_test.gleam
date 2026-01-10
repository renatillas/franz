//// Integration tests for Franz error types.
////
//// These tests verify that Kafka errors are correctly mapped to the appropriate
//// Franz error types. Each test triggers a specific error condition and asserts
//// that the correct error variant is returned.
////
//// ## Running These Tests
////
//// These tests require a running Kafka broker on localhost:9092.
////
//// ```sh
//// # Start Kafka (using Docker)
//// docker run -d --name kafka -p 9092:9092 apache/kafka:latest
//// sleep 15
////
//// # Run tests
//// gleam test
////
//// # Cleanup
//// docker stop kafka && docker rm kafka
//// ```
////
//// ## Test Coverage
////
//// | Error Type | Test | Trigger |
//// |------------|------|---------|
//// | `TopicAlreadyExists` | `topic_already_exists_test` | Create duplicate topic |
//// | `TopicInvalidPartitions` | `topic_invalid_partitions_test` | Create topic with 0 partitions |
//// | `TopicInvalidReplicationFactor` | `topic_invalid_replication_factor_test` | Replication > brokers |
//// | `ProducerNotFound` | `producer_not_found_test` | Produce without starting producer |
//// | `FetchTopicNotFound` | `fetch_topic_not_found_test` | Fetch from non-existent topic |
//// | `FetchOffsetOutOfRange` | `fetch_offset_out_of_range_test` | Fetch with invalid offset |

import franz
import gleam/erlang/process
import gleam/result

// =============================================================================
// TopicError Tests
// =============================================================================

/// Test TopicAlreadyExists - Create a topic that already exists
pub fn topic_already_exists_test() {
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "error_test_topic_already_exists"

  // Clean up first
  let _ =
    franz.delete_topics(endpoints: [endpoint], names: [topic], timeout_ms: 5000)
  process.sleep(500)

  // Create topic first time - should succeed
  let assert Ok(Nil) =
    franz.create_topic(
      endpoints: [endpoint],
      name: topic,
      partitions: 1,
      replication_factor: 1,
      configs: [],
      timeout_ms: 5000,
    )

  // Try to create the same topic again - should fail with TopicAlreadyExists
  let assert Error(franz.TopicAlreadyExists) =
    franz.create_topic(
      endpoints: [endpoint],
      name: topic,
      partitions: 1,
      replication_factor: 1,
      configs: [],
      timeout_ms: 5000,
    )

  // Cleanup
  franz.delete_topics(endpoints: [endpoint], names: [topic], timeout_ms: 5000)
  |> result.unwrap(Nil)
}

/// Test TopicInvalidPartitions - Create topic with 0 partitions
pub fn topic_invalid_partitions_test() {
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "error_test_invalid_partitions"

  let assert Error(franz.TopicInvalidPartitions) =
    franz.create_topic(
      endpoints: [endpoint],
      name: topic,
      partitions: 0,
      replication_factor: 1,
      configs: [],
      timeout_ms: 5000,
    )
}

/// Test TopicInvalidReplicationFactor - Create topic with replication > brokers
pub fn topic_invalid_replication_factor_test() {
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "error_test_invalid_replication"

  // Try to create topic with replication factor of 10 (assuming single broker)
  let assert Error(franz.TopicInvalidReplicationFactor) =
    franz.create_topic(
      endpoints: [endpoint],
      name: topic,
      partitions: 1,
      replication_factor: 10,
      configs: [],
      timeout_ms: 5000,
    )
}

// =============================================================================
// ProduceError Tests
// =============================================================================

/// Test ProducerNotFound - Produce without starting producer
pub fn producer_not_found_test() {
  let name = process.new_name("error_test_producer_not_found")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "error_test_producer_not_found_topic"

  let assert Ok(_) =
    franz.client()
    |> franz.endpoints([endpoint])
    |> franz.name(name)
    |> franz.option(franz.AutoStartProducers(False))
    |> franz.start()

  let client = franz.named(name)

  // Try to produce without starting producer
  assert Error(franz.ProducerNotFound(topic, 0))
    == franz.produce_sync(
      client: client,
      topic: topic,
      partition: franz.SinglePartition(0),
      key: <<"key">>,
      value: franz.Value(<<"value">>, []),
    )

  franz.stop(client)
}

// =============================================================================
// FetchError Tests
// =============================================================================

/// Test FetchTopicNotFound - Fetch from non-existent topic
pub fn fetch_topic_not_found_test() {
  let name = process.new_name("error_test_fetch_topic_not_found")
  let endpoint = franz.Endpoint("localhost", 9092)
  let non_existent_topic = "error_test_nonexistent_topic"

  let assert Ok(_) =
    franz.client()
    |> franz.endpoints([endpoint])
    |> franz.name(name)
    |> franz.option(franz.AllowTopicAutoCreation(False))
    |> franz.start()

  let client = franz.named(name)

  // Try to fetch from non-existent topic
  let assert Error(franz.FetchTopicNotFound) =
    franz.fetch(
      client: client,
      topic: non_existent_topic,
      partition: 0,
      offset: 0,
      options: [],
    )

  franz.stop(client)
}

/// Test FetchOffsetOutOfRange - Fetch with very high offset
pub fn fetch_offset_out_of_range_test() {
  let name = process.new_name("error_test_fetch_offset_out_of_range")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "error_test_offset_out_of_range"

  // Clean up and create topic
  let _ =
    franz.delete_topics(endpoints: [endpoint], names: [topic], timeout_ms: 5000)
  process.sleep(500)

  let assert Ok(Nil) =
    franz.create_topic(
      endpoints: [endpoint],
      name: topic,
      partitions: 1,
      replication_factor: 1,
      configs: [],
      timeout_ms: 5000,
    )

  let assert Ok(_) =
    franz.client()
    |> franz.endpoints([endpoint])
    |> franz.name(name)
    |> franz.start()

  let client = franz.named(name)

  // Wait for topic to be ready
  process.sleep(1000)

  // Try to fetch from a very high offset that doesn't exist
  let assert Error(franz.FetchOffsetOutOfRange) =
    franz.fetch(
      client: client,
      topic: topic,
      partition: 0,
      offset: 999_999_999,
      options: [],
    )

  franz.stop(client)

  // Cleanup
  franz.delete_topics(endpoints: [endpoint], names: [topic], timeout_ms: 5000)
  |> result.unwrap(Nil)
}
// =============================================================================
// Helper functions
// =============================================================================
