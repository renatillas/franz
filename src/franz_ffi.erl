-module(franz_ffi).

-export([produce_sync/5, start_client/2, produce_sync_offset/5, create_topic/4,
         start_topic_subscriber/4, ack/1, start_consumer/3]).

-record(franz_client, {name}).

start_client(KafkaBootstrapEndpoints, ClientConfig) ->
  Id = integer_to_list(erlang:unique_integer([positive])),
  ClientName = list_to_atom("client" ++ Id),
  case brod:start_client(KafkaBootstrapEndpoints, ClientName, ClientConfig) of
    ok ->
      {ok, #franz_client{name = ClientName}};
    {error, Reason} ->
      {error, Reason}
  end.

produce_sync_offset(Client, Topic, Partition, Key, Value) ->
  case brod:produce_sync_offset(Client#franz_client.name, Topic, Partition, Key, Value) of
    {ok, Offset} ->
      {ok, Offset};
    {error, Reason} ->
      {error, Reason}
  end.

produce_sync(Client, Topic, Partition, Key, Value) ->
  case brod:produce_sync(Client#franz_client.name, Topic, Partition, Key, Value) of
    ok ->
      {ok, nil};
    {error, Reason} ->
      {error, Reason}
  end.

create_topic(Hosts, Name, Partitions, ReplicationFactor) ->
  Topics =
    [#{name => Name,
       num_partitions => Partitions,
       replication_factor => ReplicationFactor,
       assignments => [],
       configs => []}],
  case brod:create_topics(Hosts, Topics, #{timeout => 1000}) of
    ok ->
      {ok, nil};
    {error, Reason} ->
      {error, Reason}
  end.

start_topic_subscriber(Client, Topic, Partitions, CbFun) ->
  brod_topic_subscriber:start_link(Client#franz_client.name,
                                   Topic,
                                   Partitions,
                                   [{begin_partition, 0}],
                                   [],
                                   message,
                                   CbFun,
                                   self()).

ack(Pid) ->
  {ok, ack, Pid}.

start_consumer(Client, Topic, ConsumerConfig) ->
  case brod:start_consumer(Client#franz_client.name, Topic, consumer_config(ConsumerConfig))
  of
    ok ->
      {ok, nil};
    {error, Reason} ->
      {error, Reason}
  end.

consumer_config(Options) ->
  lists:map(fun(Option) ->
               case Option of
                 {begin_offset, message_timestamp, Int} -> {begin_offset, Int};
                 Rest -> Rest
               end
            end,
            Options).
