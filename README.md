# franz

[![Package Version](https://img.shields.io/hexpm/v/franz)](https://hex.pm/packages/franz)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/franz/)

`franz` is a Gleam library for interacting with Kafka. It provides functionalities to produce and consume messages, handle topics, and manage configurations.

## Installation

Add `franz` to your Gleam project:

```sh
gleam add franz
```

## Usage

```gleam
  import franz
  import franz/consumer
  import franz/producer

  let topic = "gleamy_topic"
  let endpoint = #("localhost", 9092)
  let assert Ok(connection) =
    franz.start_client([endpoint], [franz.AutoStartProducers(True)])

  let assert Ok(Nil) = franz.create_topic([endpoint], topic, 1, 1)

  let assert Ok(Nil) =
    producer.produce_sync(
      connection,
      topic,
      producer.Partitioner(producer.Random),
      <<"gracias">>,
      producer.Value(<<"bitte">>, [#("meta", "data")]),
    )

  let counter = 0
  let assert Ok(pid) =
    consumer.start_group_subscriber(
      connection,
      "group",
      [topic],
      [consumer.BeginOffset(consumer.Earliest)],
      [consumer.OffsetCommitIntervalSeconds(5)],
      consumer.Message,
      fn(message, counter) {
        // io.debug(message)
        // io.debug(counter)
        consumer.commit_return(counter + 1)
      },
      counter,
    )
```
