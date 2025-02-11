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
  import franz/consumers
  import franz/producers

  let topic = "gleamy_topic"
  let endpoint = #("localhost", 9092)
  let assert Ok(connection) =
    franz.start_client([endpoint], [franz.AutoStartProducers(True)])

  let assert Ok(Nil) = franz.create_topic([endpoint], topic, 1, 1)

  let assert Ok(Nil) =
    producers.produce_sync(
      connection,
      topic,
      producers.Partitioner(producers.Random),
      <<"gracias">>,
      producers.Value(<<"bitte">>, [#("meta", "data")]),
    )

  let counter = 0
  let assert Ok(pid) =
    consumers.start_group_subscriber(
      connection,
      "group",
      [topic],
      [consumers.BeginOffset(consumers.Earliest)],
      [consumers.OffsetCommitIntervalSeconds(5)],
      consumers.Message,
      fn(message, counter) {
        // io.debug(message)
        // io.debug(counter)
        consumers.commit_return(counter + 1)
      },
      counter,
    )
```
