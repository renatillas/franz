-module(franz_ffi).

-export([produce_no_ack/5, delete_topics/3, list_groups/1, stop_group_subscriber/1,
         fetch/5, produce_cb/6, stop_client/1, produce_sync/5, start_client/3,
         produce_sync_offset/5, create_topic/6, start_topic_subscriber/8, ack/1, commit/1,
         start_group_subscriber/8, start_producer/3, map_error/1]).

-record(franz_client, {name}).

nil_result(Result) ->
  case Result of
    ok ->
      {ok, nil};
    {error, Reason} ->
      {error, map_error(Reason)}
  end.

map_error(Reason) ->
  case Reason of
    % Kafka error atoms
    unknown_server_error -> unknown_error;
    offset_out_of_range -> offset_out_of_range;
    corrupt_message -> corrupt_message;
    unknown_topic_or_partition -> unknown_topic_or_partition;
    invalid_fetch_size -> invalid_fetch_size;
    leader_not_available -> leader_not_available;
    not_leader_or_follower -> not_leader_or_follower;
    request_timed_out -> request_timed_out;
    broker_not_available -> broker_not_available;
    replica_not_available -> replica_not_available;
    message_too_large -> message_too_large;
    stale_controller_epoch -> stale_controller_epoch;
    offset_metadata_too_large -> offset_metadata_too_large;
    network_exception -> network_exception;
    coordinator_load_in_progress -> coordinator_load_in_progress;
    coordinator_not_available -> coordinator_not_available;
    not_coordinator -> not_coordinator;
    invalid_topic_exception -> invalid_topic;
    record_list_too_large -> record_list_too_large;
    not_enough_replicas -> not_enough_replicas;
    not_enough_replicas_after_append -> not_enough_replicas_after_append;
    invalid_required_acks -> invalid_required_acks;
    illegal_generation -> illegal_generation;
    inconsistent_group_protocol -> inconsistent_group_protocol;
    invalid_group_id -> invalid_group_id;
    unknown_member_id -> unknown_member_id;
    invalid_session_timeout -> invalid_session_timeout;
    rebalance_in_progress -> rebalance_in_progress;
    invalid_commit_offset_size -> invalid_commit_offset_size;
    topic_authorization_failed -> topic_authorization_failed;
    group_authorization_failed -> group_authorization_failed;
    cluster_authorization_failed -> cluster_authorization_failed;
    invalid_timestamp -> invalid_timestamp;
    unsupported_sasl_mechanism -> unsupported_sasl_mechanism;
    illegal_sasl_state -> illegal_sasl_state;
    unsupported_version -> unsupported_version;
    topic_already_exists -> topic_already_exists;
    invalid_partitions -> invalid_partitions;
    invalid_replication_factor -> invalid_replication_factor;
    invalid_replica_assignment -> invalid_replica_assignment;
    invalid_config -> invalid_config;
    not_controller -> not_controller;
    % Brod-specific errors
    client_down -> client_down;
    {client_down, _} -> client_down;
    producer_down -> producer_down;
    {producer_down, _} -> producer_down;
    {producer_not_found, Topic} -> {producer_not_found, Topic, 0};
    {producer_not_found, Topic, Partition} -> {producer_not_found, Topic, Partition};
    {consumer_not_found, Topic} -> {consumer_not_found, Topic};
    {consumer_not_found, Topic, _Partition} -> {consumer_not_found, Topic};
    % Handle binary string errors from Kafka
    Error when is_binary(Error) ->
      ErrorStr = binary_to_list(Error),
      % Check for specific error messages
      case string:find(ErrorStr, "already exists") of
        nomatch ->
          case string:find(ErrorStr, "Number of partitions") of
            nomatch ->
              case string:find(ErrorStr, "replication factor") of
                nomatch ->
                  unknown_error;
                _ ->
                  invalid_replication_factor
              end;
            _ ->
              invalid_partitions
          end;
        _ ->
          topic_already_exists
      end;
    _ -> unknown_error
  end.

start_client(Endpoints, ClientConfig, ClientName) ->
  TupleEndpoints =
    lists:map(fun({endpoint, Hostname, Port}) -> {Hostname, Port} end, Endpoints),
  case brod:start_link_client(TupleEndpoints, ClientName, ClientConfig) of
    {ok, Pid} ->
      {ok, Pid};
    {error, Reason} ->
      {error, map_error(Reason)}
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
      {error, map_error(Reason)}
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
  case brod:create_topics(TupleHosts, Topics, #{timeout => Timeout}) of
    ok -> 
      {ok, nil};
    {ok, Results} ->
      % brod:create_topics returns {ok, Results} where Results may contain errors
      handle_create_topics_results(Results, Name);
    {error, Reason} ->
      {error, map_error(Reason)}
  end.

handle_create_topics_results(Results, TopicName) ->
  % Check if there's an error in the results
  case Results of
    #{TopicName := #{error_code := ErrorCode, error_message := ErrorMsg}} when ErrorCode =/= no_error ->
      % Map the error code to our error type
      {error, map_kafka_error_code(ErrorCode, ErrorMsg)};
    _ ->
      % Success or no specific error for our topic
      {ok, nil}
  end.

map_kafka_error_code(ErrorCode, ErrorMsg) ->
  % Map Kafka error codes to our error types
  case ErrorCode of
    topic_already_exists -> topic_already_exists;
    invalid_partitions -> invalid_partitions;
    invalid_replication_factor -> invalid_replication_factor;
    _ when is_binary(ErrorMsg) ->
      % Try to map based on error message
      map_error(ErrorMsg);
    _ ->
      unknown_error
  end.

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
      {error, map_error(Reason)}
  end.

delete_topics(Endpoints, Topics, Timeout) ->
  TupleEndpoints =
    lists:map(fun({endpoint, Hostname, Port}) -> {Hostname, Port} end, Endpoints),
  nil_result(brod:delete_topics(TupleEndpoints, Topics, Timeout)).
