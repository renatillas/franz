import franz
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

  let pid =
    franz.start_topic_subscriber(
      connection,
      topic,
      franz.All,
      [],
      [#(0, 0)],
      fn(_, message, _) { franz.ack_return(Nil) },
      Nil,
    )
}
