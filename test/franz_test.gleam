import franz
import franz/consumers
import franz/producers
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
        io.debug(message)
        io.debug(counter)
        consumers.commit_return(counter + 1)
      },
      counter,
    )
  process.sleep(1000)
}
