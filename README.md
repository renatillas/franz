<div align="center">

# Franz 📖

**A powerful Kafka client for Gleam**
*Build reliable event-driven systems with ease*

[![Package Version](https://img.shields.io/hexpm/v/franz)](https://hex.pm/packages/franz)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/franz/)

</div>

---

## Features

- **High Performance** - Built on battle-tested Erlang/OTP and brod client
- **Type-Safe** - Full Gleam type safety for your Kafka interactions
- **Single Import** - Everything you need from one module: `import franz`
- **Flexible Consumers** - Both group-based and topic-based subscription models
- **Async & Sync** - Choose between synchronous and asynchronous message production
- **Rich Configuration** - Fine-tune every aspect of your Kafka client
- **Multiple Partitioning Strategies** - Random, hash-based, or custom partitioners
- **Message Batching** - Efficient batch processing support
- **SASL Authentication** - Support for PLAIN and SCRAM authentication
- **OTP Supervision** - Full integration with gleam_otp supervision trees

## Installation

Add Franz to your Gleam project:

```sh
gleam add franz
```

## Quickstart

Here's a simple example to get you started with Franz:

```gleam
import franz
import gleam/erlang/process
import gleam/io

pub fn main() {
  // 1. Connect to Kafka
  let name = process.new_name("my_kafka_client")
  let assert Ok(_) =
    franz.client()
    |> franz.endpoints([franz.Endpoint("localhost", 9092)])
    |> franz.option(franz.AutoStartProducers(True))
    |> franz.name(name)
    |> franz.start()

  let client = franz.named(name)

  // 2. Send a message
  let assert Ok(_) =
    franz.produce_sync(
      client: client,
      topic: "greetings",
      partition: franz.SinglePartition(0),
      key: <<"user:123">>,
      value: franz.Value(<<"Hello, Franz!">>, []),
    )

  io.println("Message sent successfully!")
}
```

## Examples

### Starting a Client

Franz uses a builder pattern for configuration:

```gleam
import franz
import gleam/erlang/process

pub fn connect_to_kafka() {
  // Create a named client
  let name = process.new_name("my_client")
  let endpoints = [
    franz.Endpoint("broker1.example.com", 9092),
    franz.Endpoint("broker2.example.com", 9092),
  ]

  franz.client()
  |> franz.endpoints(endpoints)
  |> franz.option(franz.AutoStartProducers(True))
  |> franz.name(name)
  |> franz.start()
}

pub fn connect_with_auth() {
  // With SASL authentication
  let name = process.new_name("secure_client")

  franz.client()
  |> franz.endpoints([franz.Endpoint("secure.broker.com", 9093)])
  |> franz.sasl(franz.SaslCredentials(franz.ScramSha256, "username", "password"))
  |> franz.ssl(franz.SslEnabled)
  |> franz.name(name)
  |> franz.start()
}
```

### Producing Messages

Franz offers multiple ways to produce messages to Kafka:

#### Synchronous Production

```gleam
import franz
import gleam/bit_array

pub fn send_user_event(client: franz.Client, user_id: String, event: String) {
  // Start a producer for the topic
  let assert Ok(_) =
    franz.producer(client, "user-events")
    |> franz.producer_option(franz.RequiredAcks(-1))
    |> franz.producer_option(franz.Compression(franz.Gzip))
    |> franz.producer_start()

  // Send the message synchronously
  franz.produce_sync(
    client: client,
    topic: "user-events",
    partition: franz.Partitioner(franz.Hash),  // Use hash partitioner based on key
    key: bit_array.from_string(user_id),
    value: franz.Value(
      bit_array.from_string(event),
      [#("event-type", "user-action")],  // Headers
    ),
  )
}
```

#### Asynchronous Production with Callback

```gleam
import franz
import gleam/io
import gleam/int

pub fn send_async_with_confirmation(client: franz.Client) {
  franz.produce_async(
    client: client,
    topic: "async-events",
    partition: franz.Partitioner(franz.Random),  // Random partition
    key: <<"">>,
    value: franz.Value(<<"async data">>, []),
    callback: fn(partition, offset) {
      let franz.Partition(p) = partition
      let franz.Offset(o) = offset
      io.println("Message delivered to partition " <> int.to_string(p))
      io.println("At offset " <> int.to_string(o))
    },
  )
}
```

#### Fire and Forget (Highest Throughput)

```gleam
import franz

pub fn fire_and_forget(client: franz.Client) {
  // No acknowledgment - fastest but may lose messages
  franz.produce(
    client: client,
    topic: "metrics",
    partition: franz.Partitioner(franz.Random),
    key: <<"">>,
    value: franz.Value(<<"metric data">>, []),
  )
}
```

### Consuming Messages

Franz provides two main consumer types: Group Subscribers and Topic Subscribers.

#### Group Subscriber (Consumer Groups)

Perfect for scalable, fault-tolerant consumption with automatic partition assignment:

```gleam
import franz
import gleam/io
import gleam/erlang/process

pub fn start_consumer_group(client: franz.Client) {
  let name = process.new_name("analytics_consumer")

  franz.default_group_subscriber_config(
    name,
    client: client,
    group_id: "analytics-processors",
    topics: ["user-events", "system-events"],
    callback: fn(message, state) {
      case message {
        franz.KafkaMessage(offset, _key, value, _, _, _) -> {
          io.println("Processing message at offset " <> int.to_string(offset))
          // Process the message...

          // Commit the offset after processing
          franz.GroupCommit(state)
        }
        franz.KafkaMessageSet(topic, partition, _, messages) -> {
          io.println("Batch from " <> topic <> " partition " <> int.to_string(partition))
          // Process batch...
          franz.GroupCommit(state)
        }
      }
    },
    init_state: Nil,
  )
  |> franz.start_group_subscriber()
}
```

#### Topic Subscriber (Direct Subscription)

For fine-grained control over partition assignment:

```gleam
import franz
import gleam/io
import gleam/int
import gleam/erlang/process

pub fn subscribe_to_notifications(client: franz.Client) {
  let name = process.new_name("notification_subscriber")

  franz.default_topic_subscriber(
    name,
    client: client,
    topic: "notifications",
    callback: fn(partition, message, state) {
      let franz.KafkaMessage(offset, _key, value, _, _, _) = message
      io.println("Partition " <> int.to_string(partition) <> " offset " <> int.to_string(offset))
      // Process notification...
      franz.TopicAck(state)
    },
    initial_state: Nil,
  )
  |> franz.start_topic_subscriber()
}
```

### OTP Supervision

Franz components integrate with gleam_otp supervision trees:

```gleam
import franz
import gleam/otp/supervision
import gleam/erlang/process

pub fn start_supervised() {
  let client_name = process.new_name("supervised_client")
  let consumer_name = process.new_name("supervised_consumer")

  let client_builder =
    franz.client()
    |> franz.endpoints([franz.Endpoint("localhost", 9092)])
    |> franz.name(client_name)

  let client = franz.named(client_name)

  let consumer_builder =
    franz.default_group_subscriber_config(
      consumer_name,
      client: client,
      group_id: "my-group",
      topics: ["events"],
      callback: fn(msg, state) { franz.GroupCommit(state) },
      init_state: Nil,
    )

  let children = [
    franz.supervised(client_builder),
    franz.group_subscriber_supervised(consumer_builder),
  ]

  supervision.start(children)
}
```

## Configuration

All time-related options use `gleam/time/duration.Duration` for type safety.

### Client Options

| Option | Description | Default |
|--------|-------------|---------|
| `AutoStartProducers(Bool)` | Automatically start producers for topics | `False` |
| `ReconnectCoolDown(Duration)` | Cooldown between reconnection attempts | 1 second |
| `RestartDelay(Duration)` | Delay before restarting crashed client | 10 seconds |
| `AllowTopicAutoCreation(Bool)` | Allow automatic topic creation | `True` |
| `ConnectTimeout(Duration)` | TCP connection timeout | 5 seconds |
| `RequestTimeout(Duration)` | Request timeout | 30 seconds |
| `UnknownTopicCacheTtl(Duration)` | Cache TTL for unknown topic errors | 2 minutes |

### Producer Options

| Option | Description | Default |
|--------|-------------|---------|
| `RequiredAcks(Int)` | Acknowledgments required (0, 1, or -1 for all) | `-1` |
| `AckTimeout(Duration)` | Ack timeout | 10 seconds |
| `Compression(Compression)` | Compression algorithm | `NoCompression` |
| `MaxBatchSize(Int)` | Max batch size in bytes | `1048576` |
| `MaxRetries(Int)` | Max retry attempts | `3` |
| `RetryBackoff(Duration)` | Delay between retries | 500 ms |
| `MaxLinger(Duration)` | Max time to wait for batching | 0 (immediate) |

### Consumer Options

| Option | Description | Default |
|--------|-------------|---------|
| `BeginOffset(StartingOffset)` | Starting offset (Latest, Earliest, AtOffset, AtTimestamp) | `Latest` |
| `MinBytes(Int)` | Minimum bytes to fetch | `0` |
| `MaxBytes(Int)` | Maximum bytes to fetch | `1048576` |
| `MaxWaitTime(Duration)` | Max time to wait for data | 10 seconds |
| `SleepTimeout(Duration)` | Sleep when no data available | 1 second |
| `PrefetchCount(Int)` | Messages to prefetch | `10` |
| `ConsumerIsolationLevel(IsolationLevel)` | Transaction isolation | `ReadCommitted` |

### Group Options

| Option | Description | Default |
|--------|-------------|---------|
| `SessionTimeout(Duration)` | Session timeout | Kafka default |
| `HeartbeatRate(Duration)` | Heartbeat interval | Kafka default |
| `RebalanceTimeout(Duration)` | Rebalance timeout | Kafka default |
| `RejoinDelay(Duration)` | Delay before rejoin attempt | Kafka default |
| `OffsetCommitInterval(Duration)` | Auto-commit interval | Kafka default |
| `MaxRejoinAttempts(Int)` | Max rejoin attempts | Kafka default |

## Security

### SASL Authentication

Franz supports multiple SASL mechanisms:

```gleam
import franz
import gleam/erlang/process

let name = process.new_name("secure_client")

// PLAIN authentication (use with SSL!)
franz.default_client(name)
|> franz.endpoints([franz.Endpoint("kafka.example.com", 9093)])
|> franz.sasl(franz.SaslCredentials(franz.Plain, "username", "password"))

// SCRAM-SHA-256
franz.default_client(name)
|> franz.endpoints([franz.Endpoint("kafka.example.com", 9093)])
|> franz.sasl(franz.SaslCredentials(franz.ScramSha256, "username", "password"))

// SCRAM-SHA-512
franz.default_client(name)
|> franz.endpoints([franz.Endpoint("kafka.example.com", 9093)])
|> franz.sasl(franz.SaslCredentials(franz.ScramSha512, "username", "password"))
```

### SSL/TLS Configuration

```gleam
import franz
import gleam/erlang/process
import gleam/option.{Some}

let name = process.new_name("ssl_client")

// Simple SSL with system CA
franz.default_client(name)
|> franz.endpoints([franz.Endpoint("kafka.example.com", 9093)])
|> franz.ssl(franz.SslEnabled)

// Custom certificates (mTLS)
franz.default_client(name)
|> franz.endpoints([franz.Endpoint("kafka.example.com", 9093)])
|> franz.ssl(franz.SslWithOptions(
  cacertfile: Some("/path/to/ca.crt"),
  certfile: Some("/path/to/client.crt"),
  keyfile: Some("/path/to/client.key"),
  verify: franz.VerifyPeer,
))
```

## Error Handling

Franz provides specific error types for each operation category:

```gleam
import franz

pub fn handle_produce_result(result: Result(Nil, franz.ProduceError)) {
  case result {
    Ok(_) -> io.println("Success!")
    Error(franz.ProducerDown) -> restart_producer()
    Error(franz.ProducerMessageTooLarge) -> split_message()
    Error(franz.ProducerNotEnoughReplicas) -> retry_later()
    Error(error) -> log_error(error)
  }
}
```

Error types:
- `ClientError` - Connection and authentication failures
- `TopicError` - Topic administration errors
- `ProduceError` - Producer operation errors
- `FetchError` - Consumer/fetch operation errors
- `GroupError` - Consumer group errors

## Architecture

Franz is built on top of the battle-tested [brod](https://github.com/kafka4beam/brod) Erlang client, providing:

- **Connection pooling** for efficient resource usage
- **Automatic reconnection** with configurable backoff
- **Supervised processes** for fault tolerance
- **Backpressure handling** for flow control

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

```sh
# Run tests
gleam test

# Format code
gleam format

# Type check
gleam check
```

## License

Franz is released under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built on [brod](https://github.com/kafka4beam/brod) - the robust Erlang Kafka client
- Inspired by the Gleam community's commitment to type safety and developer experience
- Special thanks to all contributors and users of Franz

---

<div align="center">

**Made with love by the Gleam community**

[Report Bug](https://github.com/renatillas/franz/issues) | [Request Feature](https://github.com/renatillas/franz/issues) | [Join Discord](https://discord.gg/Fm8Pwmy)

</div>
