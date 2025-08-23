<div align="center">
  
# 🐙 Franz

**A powerful Kafka client for Gleam**  
*Build reliable event-driven systems with ease*

[![Package Version](https://img.shields.io/hexpm/v/franz)](https://hex.pm/packages/franz)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/franz/)
[![CI](https://github.com/renatillas/franz/workflows/CI/badge.svg)](https://github.com/renatillas/franz/actions)

[Quickstart](#quickstart) | [Examples](#examples) | [API Docs](https://hexdocs.pm/franz/) | [Configuration](#configuration)

</div>

---

## ✨ Features

- **🚀 High Performance** - Built on battle-tested Erlang/OTP and brod client
- **🎯 Type-Safe** - Full Gleam type safety for your Kafka interactions
- **🔄 Flexible Consumers** - Both group-based and topic-based subscription models
- **⚡ Async & Sync** - Choose between synchronous and asynchronous message production
- **🛠️ Rich Configuration** - Fine-tune every aspect of your Kafka client
- **🎭 Multiple Partitioning Strategies** - Random, hash-based, or custom partitioners
- **📦 Message Batching** - Efficient batch processing support
- **🔐 SASL Authentication** - Support for PLAIN and SCRAM authentication

## 📦 Installation

Add Franz to your Gleam project:

```sh
gleam add franz
```

## 🚀 Quickstart

Here's a simple example to get you started with Franz:

```gleam
import franz
import franz/producer
import franz/group_subscriber
import franz/message_type
import gleam/io
import gleam/erlang/process

pub fn main() {
  // Connect to Kafka
  let assert Ok(client) = 
    franz.new([franz.Endpoint("localhost", 9092)])
    |> franz.with_config(franz.AutoStartProducers(True))
    |> franz.start()
  
  // Send a message
  let assert Ok(_) = producer.produce_sync(
    client: client,
    topic: "greetings",
    partition: producer.Partition(0),
    key: <<"user:123">>,
    value: producer.Value(<<"Hello, Franz!">>, []),
  )
  
  io.println("Message sent successfully! 🎉")
}
```

## 📚 Examples

### 🎬 Starting a Client

Franz supports multiple configuration options for connecting to your Kafka cluster:

```gleam
import franz
import franz/sasl

pub fn connect_to_kafka() {
  // Simple connection
  let endpoints = [
    franz.Endpoint("broker1.example.com", 9092),
    franz.Endpoint("broker2.example.com", 9092),
  ]
  
  franz.new(endpoints)
  |> franz.with_config(franz.AutoStartProducers(True))
  |> franz.with_config(franz.ClientId("my-gleam-app"))
  |> franz.start()
}

pub fn connect_with_auth() {
  // With SASL authentication
  franz.new([franz.Endpoint("secure.broker.com", 9092)])
  |> franz.with_config(franz.Sasl(sasl.Plain("username", "password")))
  |> franz.with_config(franz.SslOptions(True, None, None))
  |> franz.start()
}
```

### 📤 Producing Messages

Franz offers multiple ways to produce messages to Kafka:

#### Synchronous Production

```gleam
import franz/producer
import gleam/bit_array

pub fn send_user_event(client: franz.Client, user_id: String, event: String) {
  // Start a producer for the topic
  let assert Ok(_) = 
    producer.new(client, "user-events")
    |> producer.with_config(producer_config.RequiredAcks(1))
    |> producer.with_config(producer_config.Compression(producer_config.Gzip))
    |> producer.start()
  
  // Send the message synchronously
  producer.produce_sync(
    client: client,
    topic: "user-events",
    partition: producer.Hash,  // Use hash partitioner based on key
    key: bit_array.from_string(user_id),
    value: producer.Value(
      bit_array.from_string(event),
      [#("event-type", "user-action")]  // Headers
    ),
  )
}
```

#### Asynchronous Production with Callback

```gleam
import franz/producer

pub fn send_async_with_confirmation(client: franz.Client) {
  producer.produce(
    client: client,
    topic: "async-events",
    partition: producer.Random,  // Random partition
    key: <<"">>,
    value: producer.Value(<<"async data">>, []),
    callback: fn(partition, offset) {
      io.println("Message delivered to partition " <> int.to_string(partition))
      io.println("At offset " <> int.to_string(offset))
    },
  )
}
```

#### Custom Partitioner

```gleam
import franz/producer
import gleam/string
import gleam/int

pub fn custom_partitioner_example(client: franz.Client) {
  let custom_partitioner = producer.PartitionFun(
    fn(topic, partition_count, key, _value) {
      // Custom logic: partition based on first character of key
      case bit_array.to_string(key) {
        Ok(str) -> {
          case string.first(str) {
            Ok(char) -> {
              let hash = string.to_utf_codepoints(char) |> list.first
              Ok(int.modulo(hash, partition_count))
            }
            Error(_) -> Ok(0)
          }
        }
        Error(_) -> Ok(0)
      }
    }
  )
  
  producer.produce_sync(
    client: client,
    topic: "custom-partitioned",
    partition: producer.Partitioner(custom_partitioner),
    key: <<"custom-key">>,
    value: producer.Value(<<"data">>, []),
  )
}
```

### 📥 Consuming Messages

Franz provides two main consumer types: Group Subscribers and Topic Subscribers.

#### Group Subscriber (Consumer Groups)

Perfect for scalable, fault-tolerant consumption:

```gleam
import franz/group_subscriber
import franz/message_type
import franz/group_config
import franz/consumer_config
import gleam/io
import gleam/json
import gleam/dynamic

pub type UserEvent {
  UserEvent(id: String, action: String, timestamp: Int)
}

pub fn start_consumer_group(client: franz.Client) {
  group_subscriber.new(
    client: client,
    group_id: "analytics-processors",
    topics: ["user-events", "system-events"],
    message_type: message_type.MessageSet,  // Receive batches
    callback: process_message_batch,
    init_callback_state: InitialState(),
  )
  |> group_subscriber.with_group_config(
    group_config.SessionTimeout(30_000)
  )
  |> group_subscriber.with_consumer_config(
    consumer_config.BeginOffset(consumer_config.Latest)
  )
  |> group_subscriber.start()
}

fn process_message_batch(messages: franz.KafkaMessage, state: State) {
  case messages {
    franz.KafkaMessageSet(topic, partition, _high_wm, messages) -> {
      io.println("Processing " <> int.to_string(list.length(messages)) 
        <> " messages from " <> topic)
      
      list.each(messages, fn(msg) {
        // Process each message
        case process_single_message(msg) {
          Ok(_) -> Nil
          Error(err) -> io.println_error("Failed to process: " <> err)
        }
      })
      
      // Commit the batch after processing
      group_subscriber.commit(state)
    }
    
    franz.KafkaMessage(..) -> {
      // Single message processing
      process_single_message(messages)
      group_subscriber.ack(state)
    }
  }
}
```

#### Topic Subscriber (Direct Subscription)

For simple, direct topic consumption:

```gleam
import franz/topic_subscriber
import franz/consumer_config
import franz/partitions
import gleam/otp/task

pub fn subscribe_to_notifications(client: franz.Client) {
  // Subscribe to specific partitions
  topic_subscriber.new(
    client: client,
    topic: "notifications",
    partitions: partitions.Partitions([0, 1, 2]),
    message_type: message_type.Message,
    callback: fn(message, state) {
      let franz.KafkaMessage(offset, key, value, _, timestamp, headers) = message
      
      // Process notification
      io.println("Notification received at offset " <> int.to_string(offset))
      
      // Spawn async task for heavy processing
      task.async(fn() {
        process_notification(value)
      })
      
      Nil
    },
    init_callback_state: Nil,
  )
  |> topic_subscriber.with_consumer_config(
    consumer_config.MaxBytes(1_048_576)  // 1MB max
  )
  |> topic_subscriber.start()
}

pub fn subscribe_to_all_partitions(client: franz.Client) {
  // Subscribe to all partitions
  topic_subscriber.new(
    client: client,
    topic: "events",
    partitions: partitions.All,
    message_type: message_type.MessageSet,
    callback: handle_event_batch,
    init_callback_state: Nil,
  )
  |> topic_subscriber.start()
}
```

### 🔧 Advanced Configuration

#### Producer Configuration

```gleam
import franz/producer
import franz/producer_config

pub fn configured_producer(client: franz.Client) {
  producer.new(client, "configured-topic")
  // Batching configuration
  |> producer.with_config(producer_config.BatchSize(100))
  |> producer.with_config(producer_config.LingerMs(10))
  
  // Reliability configuration  
  |> producer.with_config(producer_config.RequiredAcks(producer_config.All))
  |> producer.with_config(producer_config.MaxRetries(3))
  
  // Performance configuration
  |> producer.with_config(producer_config.Compression(producer_config.Snappy))
  |> producer.with_config(producer_config.BufferMemory(33_554_432))
  
  |> producer.start()
}
```

#### Consumer Configuration

```gleam
import franz/consumer_config
import franz/group_config
import franz/isolation_level

pub fn configured_consumer() {
  group_subscriber.new(
    client: client,
    group_id: "configured-group",
    topics: ["topic1", "topic2"],
    message_type: message_type.MessageSet,
    callback: process,
    init_callback_state: Nil,
  )
  // Consumer configs
  |> group_subscriber.with_consumer_config(
    consumer_config.MinBytes(1024)
  )
  |> group_subscriber.with_consumer_config(
    consumer_config.MaxWaitTime(100)
  )
  |> group_subscriber.with_consumer_config(
    consumer_config.IsolationLevel(isolation_level.ReadCommitted)
  )
  
  // Group configs
  |> group_subscriber.with_group_config(
    group_config.ProtocolType("consumer")
  )
  |> group_subscriber.with_group_config(
    group_config.HeartbeatRate(1000)
  )
  |> group_subscriber.with_group_config(
    group_config.RejoinDelayMs(10_000)
  )
  |> group_subscriber.start()
}
```

### 🎯 Real-World Example: Event Sourcing System

Here's a complete example of an event sourcing system using Franz:

```gleam
import franz
import franz/producer
import franz/group_subscriber
import franz/message_type
import gleam/json
import gleam/dynamic
import gleam/result
import gleam/option.{None, Some}

// Domain events
pub type DomainEvent {
  UserCreated(id: String, name: String, email: String)
  UserUpdated(id: String, changes: List(#(String, String)))
  UserDeleted(id: String)
}

// Event store
pub fn create_event_store() {
  let assert Ok(client) = 
    franz.new([franz.Endpoint("localhost", 9092)])
    |> franz.with_config(franz.AutoStartProducers(True))
    |> franz.with_config(franz.ClientId("event-store"))
    |> franz.start()
  
  // Start the events producer
  let assert Ok(_) = 
    producer.new(client, "domain-events")
    |> producer.with_config(producer_config.RequiredAcks(producer_config.All))
    |> producer.with_config(producer_config.Compression(producer_config.Gzip))
    |> producer.start()
  
  client
}

// Publish an event
pub fn publish_event(client: franz.Client, event: DomainEvent) {
  let #(key, value) = serialize_event(event)
  
  producer.produce_sync(
    client: client,
    topic: "domain-events",
    partition: producer.Hash,
    key: key,
    value: producer.Value(
      value,
      [
        #("event-type", event_type(event)),
        #("timestamp", int.to_string(current_timestamp())),
      ]
    ),
  )
}

// Event projection
pub fn start_projection(client: franz.Client, projection_name: String) {
  group_subscriber.new(
    client: client,
    group_id: projection_name <> "-projection",
    topics: ["domain-events"],
    message_type: message_type.Message,
    callback: project_event,
    init_callback_state: ProjectionState(name: projection_name, processed: 0),
  )
  |> group_subscriber.with_consumer_config(
    consumer_config.BeginOffset(consumer_config.Earliest)
  )
  |> group_subscriber.start()
}

fn project_event(message: franz.KafkaMessage, state: ProjectionState) {
  let franz.KafkaMessage(_, key, value, _, _, headers) = message
  
  // Deserialize and process the event
  case deserialize_event(value, headers) {
    Ok(event) -> {
      case event {
        UserCreated(id, name, email) -> {
          // Update read model
          update_user_projection(id, name, email)
        }
        UserUpdated(id, changes) -> {
          apply_user_changes(id, changes)
        }
        UserDeleted(id) -> {
          remove_user_projection(id)
        }
      }
      
      // Acknowledge processing
      group_subscriber.commit(state)
    }
    Error(err) -> {
      io.println_error("Failed to deserialize event: " <> err)
      // Decide whether to skip or retry
      group_subscriber.ack(state)
    }
  }
}

// Usage
pub fn main() {
  let client = create_event_store()
  
  // Start projections
  start_projection(client, "user-read-model")
  start_projection(client, "analytics")
  
  // Publish events
  publish_event(client, UserCreated(
    id: "user-123",
    name: "Alice",
    email: "alice@example.com"
  ))
  
  // Keep the application running
  process.sleep_forever()
}
```

## 🔐 Security

### SASL Authentication

Franz supports multiple SASL mechanisms:

```gleam
import franz/sasl

// PLAIN authentication
franz.new(endpoints)
|> franz.with_config(franz.Sasl(sasl.Plain("username", "password")))

// SCRAM-SHA-256
franz.new(endpoints)
|> franz.with_config(franz.Sasl(sasl.ScramSha256("username", "password")))

// SCRAM-SHA-512
franz.new(endpoints)
|> franz.with_config(franz.Sasl(sasl.ScramSha512("username", "password")))
```

### SSL/TLS Configuration

```gleam
import franz

franz.new(endpoints)
|> franz.with_config(franz.SslOptions(
  verify: True,
  cacertfile: Some("/path/to/ca.crt"),
  server_name_indication: Some("kafka.example.com")
))
```

## 📊 Monitoring & Observability

Franz provides detailed error types for comprehensive monitoring:

```gleam
pub fn handle_kafka_result(result: Result(a, franz.FranzError)) {
  case result {
    Ok(value) -> value
    Error(error) -> {
      case error {
        franz.ProducerDown -> {
          // Handle producer failure
          restart_producer()
        }
        franz.RequestTimedOut -> {
          // Handle timeout
          retry_with_backoff()
        }
        franz.MessageTooLarge -> {
          // Handle oversized message
          split_and_retry()
        }
        _ -> {
          // Log and handle other errors
          log_error(error)
        }
      }
    }
  }
}
```

## 🎮 Configuration Reference

### Client Configuration

| Option | Description | Default |
|--------|-------------|---------|
| `AutoStartProducers` | Automatically start producers for topics | `False` |
| `ClientId` | Client identifier for tracking | `"gleam_franz"` |
| `QueryApiVersions` | Query broker API versions | `True` |
| `ReconnectCoolDownSeconds` | Cooldown between reconnection attempts | `1` |

### Producer Configuration

| Option | Description | Default |
|--------|-------------|---------|
| `RequiredAcks` | Number of acknowledgments required | `1` |
| `Compression` | Compression algorithm (None, Gzip, Snappy, Lz4) | `None` |
| `BatchSize` | Maximum batch size in bytes | `16384` |
| `LingerMs` | Time to wait for batching | `0` |
| `MaxRetries` | Maximum number of retries | `2` |

### Consumer Configuration

| Option | Description | Default |
|--------|-------------|---------|
| `MinBytes` | Minimum bytes to fetch | `1` |
| `MaxBytes` | Maximum bytes to fetch | `1048576` |
| `MaxWaitTime` | Maximum wait time in ms | `1000` |
| `BeginOffset` | Starting offset (Latest, Earliest, offset) | `Latest` |

## 🏗️ Architecture

Franz is built on top of the battle-tested [brod](https://github.com/kafka4beam/brod) Erlang client, providing:

- **Connection pooling** for efficient resource usage
- **Automatic reconnection** with configurable backoff
- **Supervised processes** for fault tolerance
- **Backpressure handling** for flow control

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

```sh
# Run tests
gleam test

# Format code
gleam format

# Type check
gleam check
```

## 📜 License

Franz is released under the MIT License. See the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built on [brod](https://github.com/kafka4beam/brod) - the robust Erlang Kafka client
- Inspired by the Gleam community's commitment to type safety and developer experience
- Special thanks to all contributors and users of Franz

---

<div align="center">

**Made with 💜 by the Gleam community**

[Report Bug](https://github.com/renatillas/franz/issues) | [Request Feature](https://github.com/renatillas/franz/issues) | [Join Discord](https://discord.gg/Fm8Pwmy)

</div>
