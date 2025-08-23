import franz

pub fn simple_create_topic_test() {
  let endpoint = franz.Endpoint("localhost", 9092)
  let topic = "simple_test_topic_99"

  // Delete if exists
  let _ =
    franz.delete_topics(endpoints: [endpoint], names: [topic], timeout_ms: 1000)

  // Create topic
  let create_result =
    franz.create_topic(
      endpoints: [endpoint],
      name: topic,
      partitions: 1,
      replication_factor: 1,
      configs: [],
      timeout_ms: 5000,
    )

  // Check what we got
  case create_result {
    Ok(_) -> {
      // Success - clean up
      let _ =
        franz.delete_topics(
          endpoints: [endpoint],
          names: [topic],
          timeout_ms: 1000,
        )
      Nil
    }
    Error(_) -> {
      panic as "Failed to create topic, got error"
    }
  }
}
