-module(franz_ffi).

-export([produce_no_ack/5, delete_topics/3, list_groups/1, stop_group_subscriber/1,
         stop_topic_subscriber/1, fetch/5, produce_cb/6, stop_client/1, produce_sync/5,
         start_client/3, produce_sync_offset/5, create_topic/6, start_topic_subscriber/8,
         group_ack/1, group_commit/1, topic_ack/1, start_group_subscriber/8, start_producer/3,
         identity/1, make_value/2, make_value_with_ts/3]).

%% Identity function for type coercion in Gleam
identity(X) ->
  X.

%% Error mapping for topic administration operations
map_topic_error(Reason) ->
  case Reason of
    topic_already_exists ->
      topic_already_exists;
    unknown_topic_or_partition ->
      topic_not_found;
    invalid_topic_exception ->
      topic_invalid_name;
    invalid_partitions ->
      topic_invalid_partitions;
    invalid_replication_factor ->
      topic_invalid_replication_factor;
    invalid_replica_assignment ->
      topic_invalid_replica_assignment;
    invalid_config ->
      topic_invalid_config;
    topic_authorization_failed ->
      topic_authorization_failed;
    cluster_authorization_failed ->
      topic_authorization_failed;
    request_timed_out ->
      topic_request_timed_out;
    broker_not_available ->
      topic_broker_not_available;
    Error when is_binary(Error) ->
      ErrorStr = binary_to_list(Error),
      case string:find(ErrorStr, "already exists") of
        nomatch ->
          case string:find(ErrorStr, "Number of partitions") of
            nomatch ->
              case string:find(ErrorStr, "replication factor") of
                nomatch ->
                  {topic_unknown_error, Reason};
                _ ->
                  topic_invalid_replication_factor
              end;
            _ ->
              topic_invalid_partitions
          end;
        _ ->
          topic_already_exists
      end;
    _ ->
      {topic_unknown_error, Reason}
  end.

%% Error mapping for produce operations
map_produce_error(Reason) ->
  case Reason of
    {producer_not_found, Topic, Partition} ->
      {producer_not_found, Topic, Partition};
    {producer_not_found, Topic} ->
      {producer_not_found, Topic, 0};
    producer_down ->
      producer_down;
    {producer_down, _} ->
      producer_down;
    client_down ->
      producer_client_down;
    {client_down, _} ->
      producer_client_down;
    leader_not_available ->
      producer_leader_not_available;
    not_leader_or_follower ->
      producer_not_leader_or_follower;
    message_too_large ->
      producer_message_too_large;
    record_list_too_large ->
      producer_record_list_too_large;
    not_enough_replicas ->
      producer_not_enough_replicas;
    not_enough_replicas_after_append ->
      producer_not_enough_replicas_after_append;
    invalid_required_acks ->
      producer_invalid_required_acks;
    topic_authorization_failed ->
      producer_authorization_failed;
    cluster_authorization_failed ->
      producer_authorization_failed;
    request_timed_out ->
      producer_request_timed_out;
    broker_not_available ->
      producer_broker_not_available;
    _ ->
      {producer_unknown_error, Reason}
  end.

%% Error mapping for fetch/consume operations
map_fetch_error(Reason) ->
  case Reason of
    offset_out_of_range ->
      fetch_offset_out_of_range;
    invalid_fetch_size ->
      fetch_invalid_size;
    corrupt_message ->
      fetch_corrupt_message;
    invalid_timestamp ->
      fetch_invalid_timestamp;
    leader_not_available ->
      fetch_leader_not_available;
    not_leader_or_follower ->
      fetch_not_leader_or_follower;
    unknown_topic_or_partition ->
      fetch_topic_not_found;
    {consumer_not_found, Topic, Partition} ->
      {fetch_consumer_not_found, Topic, Partition};
    {consumer_not_found, Topic} ->
      {fetch_consumer_not_found, Topic, 0};
    client_down ->
      fetch_client_down;
    {client_down, _} ->
      fetch_client_down;
    topic_authorization_failed ->
      fetch_authorization_failed;
    cluster_authorization_failed ->
      fetch_authorization_failed;
    request_timed_out ->
      fetch_request_timed_out;
    broker_not_available ->
      fetch_broker_not_available;
    _ ->
      {fetch_unknown_error, Reason}
  end.

%% Error mapping for group operations
map_group_error(Reason) ->
  case Reason of
    coordinator_load_in_progress ->
      group_coordinator_loading;
    coordinator_not_available ->
      group_coordinator_not_available;
    not_coordinator ->
      group_not_coordinator;
    illegal_generation ->
      group_illegal_generation;
    inconsistent_group_protocol ->
      group_inconsistent_protocol;
    invalid_group_id ->
      group_invalid_id;
    unknown_member_id ->
      group_unknown_member;
    invalid_session_timeout ->
      group_invalid_session_timeout;
    rebalance_in_progress ->
      group_rebalance_in_progress;
    invalid_commit_offset_size ->
      group_invalid_commit_offset_size;
    group_authorization_failed ->
      group_authorization_failed;
    cluster_authorization_failed ->
      group_authorization_failed;
    client_down ->
      group_client_down;
    {client_down, _} ->
      group_client_down;
    request_timed_out ->
      group_request_timed_out;
    broker_not_available ->
      group_broker_not_available;
    _ ->
      {group_unknown_error, Reason}
  end.

%% Helper for produce operations returning nil
produce_nil_result(Result) ->
  case Result of
    ok ->
      {ok, nil};
    {error, Reason} ->
      {error, map_produce_error(Reason)}
  end.

%% Helper for topic operations returning nil
topic_nil_result(Result) ->
  case Result of
    ok ->
      {ok, nil};
    {error, Reason} ->
      {error, map_topic_error(Reason)}
  end.

start_client(Endpoints, ClientConfig, ClientName) ->
  %% Convert endpoints from Gleam format {endpoint, Host, Port} to brod format {Host, Port}
  TupleEndpoints =
    lists:map(fun({endpoint, Hostname, Port}) -> {Hostname, Port} end, Endpoints),
  %% ClientConfig is already in brod format (list of {atom, value} tuples)
  %% built by Gleam's client_option_to_brod function
  case brod:start_link_client(TupleEndpoints, ClientName, ClientConfig) of
    {ok, Pid} ->
      {ok, Pid};
    {error, Reason} ->
      {error, map_client_error(Reason)}
  end.

%% Error mapping for client operations
map_client_error(Reason) ->
  case Reason of
    broker_not_available ->
      client_broker_not_available;
    network_exception ->
      client_network_exception;
    request_timed_out ->
      client_request_timed_out;
    {sasl_auth_failed, R} when is_binary(R) ->
      {client_authentication_failed, R};
    {sasl_auth_failed, R} when is_list(R) ->
      {client_authentication_failed, list_to_binary(R)};
    {ssl_error, R} when is_binary(R) ->
      {client_ssl_handshake_failed, R};
    {ssl_error, R} when is_list(R) ->
      {client_ssl_handshake_failed, list_to_binary(R)};
    unsupported_sasl_mechanism ->
      client_unsupported_sasl_mechanism;
    illegal_sasl_state ->
      client_illegal_sasl_state;
    _ ->
      {client_unknown_error, Reason}
  end.

produce_sync_offset(Client, Topic, Partition, Key, Value) ->
  {client, ClientName} = Client,
  case brod:produce_sync_offset(ClientName,
                                Topic,
                                consumer_partition(Partition),
                                Key,
                                Value)
  of
    {ok, Offset} ->
      {ok, Offset};
    {error, Reason} ->
      {error, map_produce_error(Reason)}
  end.

produce_sync(Client, Topic, Partition, Key, Value) ->
  {client, ClientName} = Client,
  produce_nil_result(brod:produce_sync(ClientName,
                                       Topic,
                                       consumer_partition(Partition),
                                       Key,
                                       Value)).

produce_no_ack(Client, Topic, Partition, Key, Value) ->
  {client, ClientName} = Client,
  produce_nil_result(brod:produce_no_ack(ClientName,
                                         Topic,
                                         consumer_partition(Partition),
                                         Key,
                                         Value)).

produce_cb(Client, Topic, Partition, Key, Value, AckCb) ->
  {client, ClientName} = Client,
  case brod:produce_cb(ClientName,
                       Topic,
                       consumer_partition(Partition),
                       Key,
                       Value,
                       fun(P, O) -> AckCb({partition, P}, {offset, O}) end)
  of
    ok ->
      {ok, Partition};
    {ok, P} ->
      {ok, P};
    {error, Reason} ->
      {error, map_produce_error(Reason)}
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
      handle_create_topics_results(Results, Name);
    {error, Reason} ->
      {error, map_topic_error(Reason)}
  end.

handle_create_topics_results(Results, TopicName) ->
  case Results of
    #{TopicName := #{error_code := ErrorCode, error_message := ErrorMsg}}
      when ErrorCode =/= no_error ->
      {error, map_topic_error_code(ErrorCode, ErrorMsg)};
    _ ->
      {ok, nil}
  end.

map_topic_error_code(ErrorCode, ErrorMsg) ->
  case ErrorCode of
    topic_already_exists ->
      topic_already_exists;
    'TOPIC_ALREADY_EXISTS' ->
      topic_already_exists;
    topic_exists ->
      topic_already_exists;
    invalid_partitions ->
      topic_invalid_partitions;
    'INVALID_PARTITIONS' ->
      topic_invalid_partitions;
    invalid_replication_factor ->
      topic_invalid_replication_factor;
    'INVALID_REPLICATION_FACTOR' ->
      topic_invalid_replication_factor;
    unknown_topic_or_partition ->
      topic_not_found;
    'UNKNOWN_TOPIC_OR_PARTITION' ->
      topic_not_found;
    _ ->
      %% Try to match based on error message if error code wasn't recognized
      MappedFromMsg = map_topic_error(ErrorMsg),
      case MappedFromMsg of
        {topic_unknown_error, _} ->
          %% Also try matching error code as string in case it's an unexpected atom
          map_topic_error_from_atom(ErrorCode);
        Other ->
          Other
      end
  end.

%% Try to map from the atom name itself
map_topic_error_from_atom(ErrorCode) when is_atom(ErrorCode) ->
  AtomStr = atom_to_list(ErrorCode),
  LowerStr = string:lowercase(AtomStr),
  case string:find(LowerStr, "already") of
    nomatch ->
      case string:find(LowerStr, "partition") of
        nomatch ->
          case string:find(LowerStr, "replication") of
            nomatch ->
              {topic_unknown_error, ErrorCode};
            _ ->
              topic_invalid_replication_factor
          end;
        _ ->
          topic_invalid_partitions
      end;
    _ ->
      topic_already_exists
  end;
map_topic_error_from_atom(ErrorCode) ->
  {topic_unknown_error, ErrorCode}.

start_topic_subscriber(Client,
                       Topic,
                       Partitions,
                       ConsumerConfig,
                       CommittedOffsets,
                       MessageType,
                       CbFun,
                       CbInit) ->
  P = case Partitions of
        all_partitions ->
          all;
        {partitions, PartitionList} ->
          PartitionList
      end,
  {client, ClientName} = Client,
  %% ConsumerConfig is already in brod format (list of {atom, value} tuples)
  %% built by Gleam's consumer_option_to_brod function
  brod_topic_subscriber:start_link(ClientName,
                                   Topic,
                                   P,
                                   ConsumerConfig,
                                   CommittedOffsets,
                                   message_type(MessageType),
                                   CbFun,
                                   CbInit).

%% Group subscriber callbacks
group_ack(State) ->
  {ok, ack, State}.

group_commit(State) ->
  {ok, commit, State}.

%% Topic subscriber callback
topic_ack(State) ->
  {ok, ack, State}.

%% Convert MessageType to brod format
message_type(single_message) ->
  message;
message_type(message_batch) ->
  message_set.

stop_client(Client) ->
  {client, ClientName} = Client,
  brod:stop_client(ClientName),
  nil.

fetch(Client, Topic, Partition, Offset, Options) ->
  {client, ClientName} = Client,
  %% Options is already in brod format (list of {atom, value} tuples)
  %% built by Gleam's fetch_option_to_brod function. Convert to map for brod:fetch.
  ProcessedOptions = maps:from_list(Options),
  case brod:fetch(ClientName, Topic, Partition, Offset, ProcessedOptions) of
    {ok, {HighWaterOffset, Messages}} ->
      %% Return raw data - next offset calculation happens in Gleam during decode
      {ok, {Offset, {Topic, Partition, HighWaterOffset, Messages}}};
    {error, Reason} ->
      {error, map_fetch_error(Reason)}
  end.

%% Creates a brod-compatible value map without timestamp
make_value(Value, Headers) ->
  #{value => Value, headers => Headers}.

%% Creates a brod-compatible value map with timestamp in milliseconds
make_value_with_ts(Value, TsMs, Headers) ->
  #{value => Value,
    ts => TsMs,
    headers => Headers}.

consumer_partition(Partition) ->
  case Partition of
    {single_partition, Int} ->
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
  {client, ClientName} = Client,
  Args =
    #{client => ClientName,
      group_id => GroupId,
      topics => Topics,
      cb_module => franz_group_subscriber_cb_fun,
      init_data => InitData,
      message_type => message_type(MessageType),
      consumer_config => ConsumerConfig,
      group_config => GroupConfig},
  brod_group_subscriber_v2:start_link(Args).

start_producer(Client, Topic, ProducerConfig) ->
  {client, ClientName} = Client,
  produce_nil_result(brod:start_producer(ClientName, Topic, ProducerConfig)).

stop_group_subscriber(Pid) ->
  case brod_group_subscriber_v2:stop(Pid) of
    ok ->
      {ok, nil};
    {error, Reason} ->
      {error, map_group_error(Reason)}
  end.

stop_topic_subscriber(Pid) ->
  ok = brod_topic_subscriber:stop(Pid),
  {ok, nil}.

list_groups({endpoint, Hostname, Port}) ->
  case brod:list_groups({Hostname, Port}, []) of
    {ok, Groups} ->
      {ok, lists:map(fun({brod_cg, Id, Type}) -> {Id, Type} end, Groups)};
    {error, Reason} ->
      {error, map_group_error(Reason)}
  end.

delete_topics(Endpoints, Topics, Timeout) ->
  TupleEndpoints =
    lists:map(fun({endpoint, Hostname, Port}) -> {Hostname, Port} end, Endpoints),
  topic_nil_result(brod:delete_topics(TupleEndpoints, Topics, Timeout)).
