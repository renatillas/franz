import franz
import gleam/io
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn create_topic_success_test() {
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "test_create_success_12345"

  io.println("Creating topic: " <> topic)

  let result =
    franz.create_topic(
      endpoints: [endpoint],
      name: topic,
      partitions: 1,
      replication_factor: 1,
      configs: [],
      timeout_ms: 5000,
    )

  should.be_ok(result)

  // Cleanup
  let _ =
    franz.delete_topics(endpoints: [endpoint], names: [topic], timeout_ms: 5000)
  Nil
}

pub fn create_duplicate_topic_test() {
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "test_duplicate_12345"

  // Create first time
  let result1 =
    franz.create_topic(
      endpoints: [endpoint],
      name: topic,
      partitions: 1,
      replication_factor: 1,
      configs: [],
      timeout_ms: 5000,
    )

  io.println("First create result")
  should.be_ok(result1)

  // Create second time - should fail
  let result2 =
    franz.create_topic(
      endpoints: [endpoint],
      name: topic,
      partitions: 1,
      replication_factor: 1,
      configs: [],
      timeout_ms: 5000,
    )

  io.println("Second create result (should fail)")

  case result2 {
    Error(franz.TopicAlreadyExists) -> {
      io.println("Got expected TopicAlreadyExists error")
      Nil
    }
    Error(_other) -> {
      io.println("Got different error")
      Nil
    }
    Ok(_) -> panic as "Should not succeed creating duplicate topic"
  }

  // Cleanup
  let _ =
    franz.delete_topics(endpoints: [endpoint], names: [topic], timeout_ms: 5000)
  Nil
}
