-module(franz_ffi).

-export([produce_no_ack/5, delete_topics/3, list_groups/1, stop_group_subscriber/1,
         fetch/5, produce_cb/6, stop_client/1, produce_sync/5, start_client/3,
         produce_sync_offset/5, create_topic/6, start_topic_subscriber/8, ack/1, commit/1,
         start_group_subscriber/8, start_producer/3]).

-record(franz_client, {name}).

nil_result(Result) ->
  case Result of
    ok ->
      {ok, nil};
    {error, Reason} ->
      {error, Reason}
  end.

start_client(Endpoints, ClientConfig, ClientName) ->
  TupleEndpoints =
    lists:map(fun({endpoint, Hostname, Port}) -> {Hostname, Port} end, Endpoints),
  case brod:start_link_client(TupleEndpoints, ClientName, ClientConfig) of
    {ok, Pid} ->
      {ok, Pid};
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

produce_no_ack(Client, Topic, Partition, Key, Value) ->
  nil_result(brod:produce_no_ack(Client#franz_client.name,
                                 Topic,
                                 consumer_partition(Partition),
                                 Key,
                                 value(Value))).

produce_cb(Client, Topic, Partition, Key, Value, AckCb) ->
  case brod:produce_cb(Client#franz_client.name,
                       Topic,
                       consumer_partition(Partition),
                       Key,
                       value(Value),
                       fun(P, O) -> AckCb({cb_partition, P}, {cb_offset, O}) end)
  of
    ok ->
      {ok, Partition};
    {ok, P} ->
      {ok, P};
    {error, Reason} ->
      {error, Reason}
  end.

create_topic(Hosts, Name, Partitions, ReplicationFactor, Configs, Timeout) ->
  MapConfigs =
    lists:map(fun(Config) -> case Config of {Key, Value} -> #{name => Key, value => Value} end
              end,
              Configs),
  TupleHosts = lists:map(fun({endpoint, Hostname, Port}) -> {Hostname, Port} end, Hosts),
  Topics =
    [#{name => Name,
       num_partitions => Partitions,
       replication_factor => ReplicationFactor,
       assignments => [],
       configs => MapConfigs}],
  nil_result(brod:create_topics(TupleHosts, Topics, #{timeout => Timeout})).

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
        {partitions, PartitionList} ->
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
  nil_result(brod:start_producer(Client#franz_client.name, Topic, ProducerConfig)).

stop_group_subscriber(Pid) ->
  case brod_group_subscriber_v2:stop(Pid) of
    ok ->
      {ok, nil}
  end.

list_groups({endpoint, Hostname, Port}) ->
  case brod:list_groups({Hostname, Port}, []) of
    {ok, Groups} ->
      {ok, lists:map(fun({brod_cg, Id, Type}) -> {consumer_group, Id, Type} end, Groups)};
    {error, Reason} ->
      {error, Reason}
  end.

delete_topics(Endpoints, Topics, Timeout) ->
  TupleEndpoints =
    lists:map(fun({endpoint, Hostname, Port}) -> {Hostname, Port} end, Endpoints),
  nil_result(brod:delete_topics(TupleEndpoints, Topics, Timeout)).
