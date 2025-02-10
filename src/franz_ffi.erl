-module(franz_ffi).

-export([fetch/4, produce_cb/6, stop_client/1, produce/5, produce_sync/5,
         start_client/2, produce_sync_offset/5, create_topic/4, start_topic_subscriber/7,
         ack_return/1, start_consumer/3]).

-record(franz_client, {name}).

nil_result(Result) ->
  case Result of
    ok ->
      {ok, nil};
    {error, Reason} ->
      {error, Reason}
  end.

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
  brod:produce_sync_offset(Client#franz_client.name,
                           Topic,
                           consumer_partition(Partition),
                           Key,
                           value(Value)).

produce_sync(Client, Topic, Partition, Key, Value) ->
  nil_result(brod:produce_sync(Client#franz_client.name,
                               Topic,
                               consumer_partition(Partition),
                               Key,
                               value(Value))).

produce(Client, Topic, Partition, Key, Value) ->
  case brod:produce(Client#franz_client.name,
                    Topic,
                    consumer_partition(Partition),
                    Key,
                    value(Value))
  of
    {ok, _} ->
      {ok, nil};
    {error, Reason} ->
      {error, Reason}
  end.

produce_cb(Client, Topic, Partition, Key, Value, AckCb) ->
  case brod:produce(Client#franz_client.name,
                    Topic,
                    consumer_partition(Partition),
                    Key,
                    value(Value),
                    AckCb)
  of
    ok ->
      {ok, Partition};
    {ok, P} ->
      {ok, P};
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
  nil_result(brod:create_topics(Hosts, Topics, #{timeout => 1000})).

start_topic_subscriber(Client,
                       Topic,
                       Partitions,
                       ConsumerConfig,
                       CommitedOffsets,
                       CbFun,
                       CbInit) ->
  P = case Partitions of
        all ->
          all;
        {list, PartitionList} ->
          PartitionList
      end,
  brod_topic_subscriber:start_link(Client#franz_client.name,
                                   Topic,
                                   P,
                                   ConsumerConfig,
                                   CommitedOffsets,
                                   message,
                                   CbFun,
                                   CbInit).

ack_return(Any) ->
  {ok, ack, Any}.

start_consumer(Client, Topic, ConsumerConfig) ->
  nil_result(brod:start_consumer(Client#franz_client.name,
                                 Topic,
                                 consumer_config(ConsumerConfig))).

consumer_config(Options) ->
  lists:map(fun(Option) ->
               case Option of
                 {begin_offset, message_timestamp, Int} -> {begin_offset, Int};
                 Rest -> Rest
               end
            end,
            Options).

stop_client(Client) ->
  brod:stop_client(Client#franz_client.name),
  nil.

fetch(Client, Topic, Partition, Offset) ->
  brod:fetch(Client#franz_client.name, Topic, Partition, Offset).

value(Value) ->
  case Value of
    {value, V, H} ->
      #{value => V, headers => H};
    {value_with_timestamp, V, Ts, H} ->
      #{ts => Ts,
        value => V,
        headers => H}
  end.

consumer_partition(Partition) ->
  case Partition of
    {partition, Int} ->
      Int;
    {partitioner, random} ->
      random;
    {partitioner, hash} ->
      hash;
    {partitioner, {partition_fun, F}} ->
      F
  end.
