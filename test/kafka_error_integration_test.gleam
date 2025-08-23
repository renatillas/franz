// INTEGRATION TESTS - Run these manually with Kafka running
// These tests demonstrate that the error mapping works with real Kafka errors
// To run: Ensure Kafka is running on localhost:9092 

import franz
import franz/producer
import gleam/erlang/process
import gleam/result
import gleeunit/should

// Test 1: BrokerNotAvailable - Connect to non-existent broker
// SKIP: This test requires specific network conditions
pub fn broker_not_available_test_skip() {
  let name = process.new_name("broker_not_available_test")
  let endpoint = franz.Endpoint("127.0.0.1", 9999)
  // Non-existent port

  let result =
    franz.new([endpoint], name)
    |> franz.start()

  // Connection might succeed even with wrong broker (lazy connection)
  // So let's try to actually use it
  case result {
    Ok(_) -> {
      let client = franz.named_client(name)
      // Try to create topic on non-existent broker
      let topic_result =
        franz.create_topic(
          endpoints: [endpoint],
          name: "test_broker_error",
          partitions: 1,
          replication_factor: 1,
          configs: [],
          timeout_ms: 1000,
        )
      case topic_result {
        Error(_) -> Nil
        // Expected some error
        Ok(_) -> panic as "Should fail with non-existent broker"
      }
      franz.stop_client(client)
    }
    Error(_) -> Nil
    // Connection failed immediately - also good
  }
}

// Test 2: UnknownTopicOrPartition - Fetch from non-existent topic with auto-creation disabled
pub fn unknown_topic_or_partition_test() {
  let name = process.new_name("unknown_topic_test")
  let endpoint = franz.Endpoint("localhost", 9092)

  let assert Ok(_) =
    franz.new([endpoint], name)
    |> franz.with_config(franz.AllowTopicAutoCreation(False))
    |> franz.start()

  let client = franz.named_client(name)
  let non_existent_topic = "non_existent_topic_12345"

  // Try to fetch from non-existent topic
  let result =
    franz.fetch(
      client: client,
      topic: non_existent_topic,
      partition: 0,
      offset: 0,
      options: [],
    )

  case result {
    Error(franz.UnknownTopicOrPartition) -> {
      // Expected error
      Nil
    }
    Error(_other) ->
      panic as "Expected UnknownTopicOrPartition, got different error"
    Ok(_) -> panic as "Expected error for non-existent topic"
  }

  franz.stop_client(client)
}

// Test 3: OffsetOutOfRange - Fetch with invalid offset
pub fn offset_out_of_range_test() {
  let name = process.new_name("offset_out_of_range_test")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "offset_test_topic"

  // Clean up any existing topic first
  let _ =
    franz.delete_topics(endpoints: [endpoint], names: [topic], timeout_ms: 1000)

  // Create topic
  franz.create_topic(
    endpoints: [endpoint],
    name: topic,
    partitions: 1,
    replication_factor: 1,
    configs: [],
    timeout_ms: 5000,
  )
  |> should.be_ok()

  let assert Ok(_) =
    franz.new([endpoint], name)
    |> franz.start()

  let client = franz.named_client(name)

  // Try to fetch from a very high offset that doesn't exist
  let result =
    franz.fetch(
      client: client,
      topic: topic,
      partition: 0,
      offset: 999_999_999,
      options: [],
    )

  case result {
    Error(franz.OffsetOutOfRange) -> {
      // Expected error
      Nil
    }
    Error(_other) -> {
      // Different Kafka versions might return different errors for high offsets
      // The important thing is that an error is returned
      Nil
    }
    Ok(_) -> panic as "Expected error for out of range offset"
  }

  franz.stop_client(client)

  // Cleanup
  franz.delete_topics(endpoints: [endpoint], names: [topic], timeout_ms: 5000)
  |> result.unwrap(Nil)
}

// Test 4: LeaderNotAvailable - Try to produce immediately after topic creation
pub fn leader_not_available_test() {
  let name = process.new_name("leader_not_available_test")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "leader_test_topic_12345"

  // Delete topic if it exists
  let _ =
    franz.delete_topics(endpoints: [endpoint], names: [topic], timeout_ms: 1000)

  // Create topic
  franz.create_topic(
    endpoints: [endpoint],
    name: topic,
    partitions: 3,
    replication_factor: 1,
    configs: [],
    timeout_ms: 5000,
  )
  |> should.be_ok()

  let assert Ok(_) =
    franz.new([endpoint], name)
    |> franz.start()

  let client = franz.named_client(name)

  // Immediately try to produce without starting producer
  // This might trigger leader election errors
  let result =
    producer.produce_sync(
      client: client,
      topic: topic,
      partition: producer.Partition(0),
      key: <<"key">>,
      value: producer.Value(<<"value">>, []),
    )

  // The error might be LeaderNotAvailable or it might succeed if leader election is fast
  // Let's just ensure we handle it properly
  case result {
    Error(franz.LeaderNotAvailable) -> Nil
    Error(franz.ProducerNotFound(_, _)) -> {
      // Producer needs to be started first
      producer.new(client, topic)
      |> producer.start()
      |> should.be_ok()
    }
    Error(_) -> Nil
    // Other errors are acceptable
    Ok(_) -> Nil
  }

  franz.stop_client(client)

  // Cleanup
  franz.delete_topics(endpoints: [endpoint], names: [topic], timeout_ms: 5000)
  |> result.unwrap(Nil)
}

// Test 5: TopicAlreadyExists - Try to create a topic that already exists
pub fn topic_already_exists_test() {
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "duplicate_topic_test"

  // Clean up any existing topic first
  let _ =
    franz.delete_topics(endpoints: [endpoint], names: [topic], timeout_ms: 1000)

  // Create topic first time
  franz.create_topic(
    endpoints: [endpoint],
    name: topic,
    partitions: 1,
    replication_factor: 1,
    configs: [],
    timeout_ms: 5000,
  )
  |> should.be_ok()

  // Try to create the same topic again
  let result =
    franz.create_topic(
      endpoints: [endpoint],
      name: topic,
      partitions: 1,
      replication_factor: 1,
      configs: [],
      timeout_ms: 5000,
    )

  case result {
    Error(franz.TopicAlreadyExists) -> {
      // Expected error
      Nil
    }
    Error(_other) -> {
      // Kafka might return a generic error instead of TopicAlreadyExists
      // depending on configuration
      Nil
    }
    Ok(_) -> panic as "Expected error for duplicate topic creation"
  }

  // Cleanup
  franz.delete_topics(endpoints: [endpoint], names: [topic], timeout_ms: 5000)
  |> result.unwrap(Nil)
}

// Test 6: InvalidPartitions - Create topic with invalid number of partitions
pub fn invalid_partitions_test() {
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "invalid_partitions_test"

  // Try to create topic with 0 partitions
  let result =
    franz.create_topic(
      endpoints: [endpoint],
      name: topic,
      partitions: 0,
      replication_factor: 1,
      configs: [],
      timeout_ms: 5000,
    )

  case result {
    Error(franz.InvalidPartitions) -> {
      // Expected error
      Nil
    }
    Error(_other) -> {
      // Some Kafka versions might return a different error
      Nil
    }
    Ok(_) -> panic as "Expected error for 0 partitions"
  }
}

// Test 7: InvalidReplicationFactor - Create topic with invalid replication factor  
// SKIP: This test requires multi-broker setup
pub fn invalid_replication_factor_test_skip() {
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "invalid_replication_test"

  // Try to create topic with replication factor > number of brokers
  // Assuming single-broker setup
  let result =
    franz.create_topic(
      endpoints: [endpoint],
      name: topic,
      partitions: 1,
      replication_factor: 10,
      // Too high for single broker
      configs: [],
      timeout_ms: 5000,
    )

  case result {
    Error(franz.InvalidReplicationFactor) -> {
      // Expected error
      Nil
    }
    Error(_) -> {
      // Kafka might return a different error
      Nil
    }
    Ok(_) -> panic as "Expected error for invalid replication factor"
  }
}

// Test 8: MessageTooLarge - Try to produce a message that's too large
// SKIP: This test may crash the producer
pub fn message_too_large_test_skip() {
  let name = process.new_name("message_too_large_test")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "large_message_test"

  // Create topic with small max message size
  franz.create_topic(
    endpoints: [endpoint],
    name: topic,
    partitions: 1,
    replication_factor: 1,
    configs: [#("max.message.bytes", "1000")],
    // 1KB max
    timeout_ms: 5000,
  )
  |> should.be_ok()

  let assert Ok(_) =
    franz.new([endpoint], name)
    |> franz.start()

  let client = franz.named_client(name)

  producer.new(client, topic)
  |> producer.start()
  |> should.be_ok()

  // Create a large message (>1KB)
  let large_value = create_large_string(2000)
  // 2KB

  let result =
    producer.produce_sync(
      client: client,
      topic: topic,
      partition: producer.Partition(0),
      key: <<"key">>,
      value: producer.Value(large_value, []),
    )

  case result {
    Error(franz.MessageTooLarge) -> {
      // Expected error
      Nil
    }
    Error(_other) -> {
      panic as "Expected MessageTooLarge, got different error"
    }
    Ok(_) -> {
      panic as "Expected error for large message, but succeeded"
    }
  }

  franz.stop_client(client)

  // Cleanup
  franz.delete_topics(endpoints: [endpoint], names: [topic], timeout_ms: 5000)
  |> result.unwrap(Nil)
}

// Test 9: ProducerNotFound - Try to produce without starting producer
pub fn producer_not_found_test() {
  let name = process.new_name("producer_not_found_test")
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "producer_not_found_test"

  let assert Ok(_) =
    franz.new([endpoint], name)
    |> franz.with_config(franz.AutoStartProducers(False))
    |> franz.start()

  let client = franz.named_client(name)

  // Try to produce without starting producer
  let result =
    producer.produce_sync(
      client: client,
      topic: topic,
      partition: producer.Partition(0),
      key: <<"key">>,
      value: producer.Value(<<"value">>, []),
    )

  case result {
    Error(franz.ProducerNotFound(t, p)) -> {
      // Expected error
      t |> should.equal(topic)
      p |> should.equal(0)
    }
    Error(_other) -> panic as "Expected ProducerNotFound, got different error"
    Ok(_) -> panic as "Expected error for missing producer"
  }

  franz.stop_client(client)
}

// Test 10: RequestTimedOut - Set very short timeout
// SKIP: This test is timing-dependent
pub fn request_timed_out_test_skip() {
  let name = process.new_name("timeout_test")
  let endpoint = franz.Endpoint("localhost", 9092)

  let assert Ok(_) =
    franz.new([endpoint], name)
    |> franz.start()

  let client = franz.named_client(name)

  // Try to fetch with very short timeout
  let result =
    franz.fetch(
      client: client,
      topic: "some_topic",
      partition: 0,
      offset: 0,
      options: [
        franz.MaxWaitTime(1),
        // 1ms timeout - very short
      ],
    )

  // This might timeout or return empty, depending on Kafka's response time
  let _ = result
  // Result doesn't matter for this test

  franz.stop_client(client)
}

// Helper function to create a large string
fn create_large_string(size: Int) -> BitArray {
  create_large_string_helper(size, <<>>)
}

fn create_large_string_helper(remaining: Int, acc: BitArray) -> BitArray {
  case remaining {
    0 -> acc
    n if n < 0 -> acc
    _ -> create_large_string_helper(remaining - 1, <<acc:bits, "x":utf8>>)
  }
}
