-module(franz_ffi).

-export([produce_no_ack/5, delete_topics/3, list_groups/1, stop_group_subscriber/1,
         fetch/5, produce_cb/6, stop_client/1, produce_sync/5, start_client/3,
         produce_sync_offset/5, create_topic/6, start_topic_subscriber/8, ack/1, commit/1,
         start_group_subscriber/8, start_producer/3]).

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
                  topic_unknown_error;
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
      topic_unknown_error
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
      producer_unknown_error
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
      fetch_unknown_error
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
      group_unknown_error
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

%% Process client config options
process_client_config(Options) ->
  lists:flatmap(fun process_client_option/1, Options).

process_client_option({sasl, SaslConfig}) ->
  [{sasl, process_sasl_config(SaslConfig)}];
process_client_option({ssl, SslConfig}) ->
  [{ssl, process_ssl_config(SslConfig)}];
process_client_option({connect_timeout, Timeout}) ->
  [{connect_timeout, Timeout}];
process_client_option({request_timeout, Timeout}) ->
  [{request_timeout, Timeout}];
process_client_option({restart_delay_seconds, Seconds}) ->
  [{restart_delay_seconds, Seconds}];
process_client_option({reconnect_cool_down_seconds, Seconds}) ->
  [{reconnect_cool_down_seconds, Seconds}];
process_client_option({allow_topic_auto_creation, Bool}) ->
  [{allow_topic_auto_creation, Bool}];
process_client_option({auto_start_producers, Bool}) ->
  [{auto_start_producers, Bool}];
process_client_option({default_producer_config, Config}) ->
  [{default_producer_config, process_producer_config(Config)}];
process_client_option({unknown_topic_cache_ttl, Ttl}) ->
  [{topic_metadata_refresh_interval_seconds, Ttl div 1000}];
process_client_option(Other) ->
  [Other].

%% SASL configuration
process_sasl_config({sasl_credentials, Mechanism, Username, Password}) ->
  {process_sasl_mechanism(Mechanism), Username, Password}.

process_sasl_mechanism(plain) ->
  plain;
process_sasl_mechanism(scram_sha_256) ->
  scram_sha_256;
process_sasl_mechanism(scram_sha_512) ->
  scram_sha_512.

%% SSL configuration
process_ssl_config(ssl_enabled) ->
  true;
process_ssl_config({ssl_with_options, CaCertFile, CertFile, KeyFile, Verify}) ->
  Options0 = [],
  Options1 = maybe_add_option(cacertfile, CaCertFile, Options0),
  Options2 = maybe_add_option(certfile, CertFile, Options1),
  Options3 = maybe_add_option(keyfile, KeyFile, Options2),
  Options4 = add_verify_option(Verify, Options3),
  Options4.

maybe_add_option(_Key, none, Options) ->
  Options;
maybe_add_option(Key, {some, Value}, Options) ->
  [{Key, Value} | Options].

add_verify_option(verify_peer, Options) ->
  [{verify, verify_peer} | Options];
add_verify_option(verify_none, Options) ->
  [{verify, verify_none} | Options].

%% Producer configuration
process_producer_config(Options) ->
  lists:map(fun process_producer_option/1, Options).

process_producer_option({compression, Compression}) ->
  {compression, process_compression(Compression)};
process_producer_option({partition_on_wire_limit, Limit}) ->
  {partition_onwire_limit, Limit};
process_producer_option(Other) ->
  Other.

process_compression(no_compression) ->
  no_compression;
process_compression(gzip) ->
  gzip;
process_compression(snappy) ->
  snappy;
process_compression(lz4) ->
  lz4.

start_client(Endpoints, ClientConfig, ClientName) ->
  TupleEndpoints =
    lists:map(fun({endpoint, Hostname, Port}) -> {Hostname, Port} end, Endpoints),
  ProcessedConfig = process_client_config(ClientConfig),
  case brod:start_link_client(TupleEndpoints, ClientName, ProcessedConfig) of
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
      client_unknown_error
  end.

produce_sync_offset(Client, Topic, Partition, Key, Value) ->
  {client, ClientName} = Client,
  case brod:produce_sync_offset(ClientName,
                                Topic,
                                consumer_partition(Partition),
                                Key,
                                value(Value))
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
                                       value(Value))).

produce_no_ack(Client, Topic, Partition, Key, Value) ->
  {client, ClientName} = Client,
  produce_nil_result(brod:produce_no_ack(ClientName,
                                         Topic,
                                         consumer_partition(Partition),
                                         Key,
                                         value(Value))).

produce_cb(Client, Topic, Partition, Key, Value, AckCb) ->
  {client, ClientName} = Client,
  case brod:produce_cb(ClientName,
                       Topic,
                       consumer_partition(Partition),
                       Key,
                       value(Value),
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
        topic_unknown_error ->
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
              topic_unknown_error;
            _ ->
              topic_invalid_replication_factor
          end;
        _ ->
          topic_invalid_partitions
      end;
    _ ->
      topic_already_exists
  end;
map_topic_error_from_atom(_) ->
  topic_unknown_error.

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
  brod_topic_subscriber:start_link(ClientName,
                                   Topic,
                                   P,
                                   consumer_config(ConsumerConfig),
                                   CommittedOffsets,
                                   message_type(MessageType),
                                   CbFun,
                                   CbInit).

ack(Any) ->
  {ok, ack, Any}.

commit(Any) ->
  {ok, commit, Any}.

%% Convert MessageType to brod format
message_type(single_message) ->
  message;
message_type(message_batch) ->
  message_set.

%% Convert consumer config options to brod format
consumer_config(Options) ->
  lists:map(fun process_consumer_option/1, Options).

process_consumer_option({begin_offset, Offset}) ->
  {begin_offset, process_offset(Offset)};
process_consumer_option({consumer_isolation_level, Level}) ->
  {isolation_level, process_isolation_level(Level)};
process_consumer_option({offset_reset_policy, Policy}) ->
  {offset_reset_policy, process_offset_reset_policy(Policy)};
process_consumer_option(Other) ->
  Other.

process_offset(latest) ->
  latest;
process_offset(earliest) ->
  earliest;
process_offset({at_timestamp, Timestamp}) ->
  Timestamp;
process_offset({at_offset, Offset}) ->
  Offset.

process_isolation_level(read_committed) ->
  read_committed;
process_isolation_level(read_uncommitted) ->
  read_uncommitted.

process_offset_reset_policy(reset_by_subscriber) ->
  reset_by_subscriber;
process_offset_reset_policy(reset_to_earliest) ->
  reset_to_earliest;
process_offset_reset_policy(reset_to_latest) ->
  reset_to_latest.

stop_client(Client) ->
  {client, ClientName} = Client,
  brod:stop_client(ClientName),
  nil.

fetch(Client, Topic, Partition, Offset, OffsetOptions) ->
  {client, ClientName} = Client,
  ProcessedOptions = process_fetch_options(OffsetOptions),
  case brod:fetch(ClientName, Topic, Partition, Offset, ProcessedOptions) of
    {ok, Result} ->
      {ok, Result};
    {error, Reason} ->
      {error, map_fetch_error(Reason)}
  end.

process_fetch_options(Options) ->
  lists:foldl(fun process_fetch_option/2, #{}, Options).

process_fetch_option({fetch_max_wait_time, Time}, Acc) ->
  Acc#{max_wait_time => Time};
process_fetch_option({fetch_min_bytes, Bytes}, Acc) ->
  Acc#{min_bytes => Bytes};
process_fetch_option({fetch_max_bytes, Bytes}, Acc) ->
  Acc#{max_bytes => Bytes};
process_fetch_option({fetch_isolation_level, Level}, Acc) ->
  Acc#{isolation_level => process_isolation_level(Level)}.

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
      consumer_config => consumer_config(ConsumerConfig),
      group_config => process_group_config(GroupConfig)},
  brod_group_subscriber_v2:start_link(Args).

%% Convert group config options to brod format
process_group_config(Options) ->
  lists:map(fun process_group_option/1, Options).

process_group_option({session_timeout_seconds, Seconds}) ->
  {session_timeout_seconds, Seconds};
process_group_option({rebalance_timeout_seconds, Seconds}) ->
  {rebalance_timeout_seconds, Seconds};
process_group_option({heartbeat_rate_seconds, Seconds}) ->
  {heartbeat_rate_seconds, Seconds};
process_group_option({max_rejoin_attempts, Attempts}) ->
  {max_rejoin_attempts, Attempts};
process_group_option({rejoin_delay_seconds, Seconds}) ->
  {rejoin_delay_seconds, Seconds};
process_group_option({offset_commit_interval_seconds, Seconds}) ->
  {offset_commit_interval_seconds, Seconds};
process_group_option({offset_retention_seconds, Seconds}) ->
  {offset_retention_seconds, Seconds};
process_group_option(Other) ->
  Other.

start_producer(Client, Topic, ProducerConfig) ->
  {client, ClientName} = Client,
  produce_nil_result(brod:start_producer(ClientName,
                                         Topic,
                                         process_producer_config(ProducerConfig))).

stop_group_subscriber(Pid) ->
  case brod_group_subscriber_v2:stop(Pid) of
    ok ->
      {ok, nil};
    {error, Reason} ->
      {error, map_group_error(Reason)}
  end.

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
