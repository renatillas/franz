import franz
import gleam/erlang/process
import gleam/io
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn happy_path_test() {
  let topic = "new-topic"
  let connection =
    franz.start_client([#("localhost", 9092)], [franz.AutoStartProducers(True)])
    |> should.be_ok()

  //  let assert Ok(Nil) = create_topic([#("127.0.0.1", 9092)], topic, 1, 1)

  franz.start_topic_subscriber(
    connection,
    topic,
    franz.All,
    [franz.BeginOffset(franz.MessageTimestamp(1))],
    [#(0, 0)],
    franz.MessageSet,
    fn(_, message, _) {
      io.debug(message)
      franz.ack_return(Nil)
    },
    Nil,
  )
  process.sleep(1000)

  franz.start_group_subscriber(
    connection,
    "group",
    [topic],
    [franz.BeginOffset(franz.MessageTimestamp(1))],
    [franz.OffsetCommitIntervalSeconds(5)],
    franz.Message,
    fn(message, _) {
      io.debug(message)
      franz.ack_return(Nil)
    },
    Nil,
  )
  |> io.debug
  process.sleep(1000)
}
