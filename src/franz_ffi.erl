-module(franz_ffi).

-export([stop_group_subscriber/1, fetch/5, produce_cb/6, stop_client/1, produce/5,
         produce_sync/5, start_client/2, produce_sync_offset/5, create_topic/4,
         start_topic_subscriber/8, ack/1, commit/1, start_group_subscriber/8, start_producer/3]).

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
                       CommittedOffsets,
                       MessageType,
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
                                   CommittedOffsets,
                                   MessageType,
                                   CbFun,
                                   CbInit).

ack(Any) ->
  {ok, ack, Any}.

commit(Any) ->
  {ok, commit, Any}.

consumer_config(Options) ->
  lists:map(fun(Option) ->
               case Option of
                 {begin_offset, {message_timestamp, Int}} -> {begin_offset, Int};
                 Rest -> Rest
               end
            end,
            Options).

stop_client(Client) ->
  brod:stop_client(Client#franz_client.name),
  nil.

fetch(Client, Topic, Partition, Offset, OffsetOptions) ->
  brod:fetch(Client#franz_client.name,
             Topic,
             Partition,
             Offset,
             proplists:to_map(OffsetOptions)).

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

-record(cbm_init_data, {cb_fun :: term(), cb_data :: term()}).

start_group_subscriber(Client,
                       GroupId,
                       Topics,
                       ConsumerConfig,
                       GroupConfig,
                       MessageType,
                       CbFun,
                       CbInitialState) ->
  InitData = #cbm_init_data{cb_fun = CbFun, cb_data = CbInitialState},
  Args =
    #{client => Client#franz_client.name,
      group_id => GroupId,
      topics => Topics,
      cb_module => franz_group_subscriber_cb_fun,
      init_data => InitData,
      message_type => MessageType,
      consumer_config => consumer_config(ConsumerConfig),
      group_config => GroupConfig},
  brod_group_subscriber_v2:start_link(Args).

start_producer(Client, Topic, ProducerConfig) ->
  brod:start_producer(Client#franz_client.name, Topic, ProducerConfig).

stop_group_subscriber(Pid) ->
  case brod_group_subscriber_v2:stop(Pid) of
    ok ->
      {ok, nil}
  end.
