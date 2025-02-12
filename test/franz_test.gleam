import franz
import franz/consumer_config
import franz/group_config
import franz/group_subscriber
import franz/isolation_level
import franz/message_type
import franz/partitions
import franz/producer
import franz/topic_subscriber
import gleam/erlang/process
import gleam/io
import gleeunit

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn happy_path_test() {
  let topic = "gleamy_topic"
  let endpoint = #("localhost", 9092)
  let assert Ok(connection) =
    franz.new_client([endpoint])
    |> franz.with_config(franz.AutoStartProducers(True))
    |> franz.start()

  //let assert Ok(Nil) = franz.create_topic([endpoint], topic, 1, 1)

  // let assert Ok(Nil) =
  //   producer.produce_sync(
  //     connection,
  //     topic,
  //     producer.Partitioner(producer.Random),
  //     <<"gracias">>,
  //     producer.Value(<<"bitte">>, [#("meta", "data")]),
  //   )
  //
  // let counter = 0
  // let assert Ok(_pid) =
  //   group_subscriber.new(
  //     connection,
  //     "group",
  //     [topic],
  //     message_type.Message,
  //     fn(message, counter) {
  //       io.debug(message)
  //       io.debug(counter)
  //       group_subscriber.commit(counter + 1)
  //     },
  //     counter,
  //   )
  //   |> group_subscriber.with_group_config(
  //     group_config.OffsetCommitIntervalSeconds(10),
  //   )
  //   |> group_subscriber.with_consumer_config(consumer_config.BeginOffset(
  //     consumer_config.Earliest,
  //   ))
  //   |> group_subscriber.start()
  //
  // let assert Ok(_pid) =
  //   topic_subscriber.new(
  //     connection,
  //     topic,
  //     partitions.All,
  //     message_type.Message,
  //     fn(_, message, state) {
  //       io.debug(message)
  //       topic_subscriber.ack(state)
  //     },
  //     Nil,
  //   )
  //   |> topic_subscriber.with_config(consumer_config.BeginOffset(
  //     consumer_config.Earliest,
  //   ))
  //   |> topic_subscriber.start()

  franz.fetch(connection, topic, 0, 0, [
    franz.IsolationLevel(isolation_level.ReadUncommitted),
    franz.MinBytes(0),
    franz.MaxBytes(1000),
  ])
  |> io.debug
  process.sleep(1000)
}
