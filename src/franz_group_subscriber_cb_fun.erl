-module(franz_group_subscriber_cb_fun).

-behavior(brod_group_subscriber_v2).

-record(cbm_init_data, {cb_fun :: brod_topic_subscriber:cb_fun(), cb_data :: term()}).

-export([init/2, handle_message/2]).

%% @private This is needed to implement backward-consistent `cb_fun'
%% interface.
init(_InitInfo, #cbm_init_data{cb_fun = CbFun, cb_data = CbState}) ->
  {ok, {CbFun, CbState}}.

handle_message(Msg, {CbFun, CbState0}) ->
  %% Convert brod message to Gleam format before calling the callback
  ConvertedMsg = case Msg of
    {kafka_message, _, _, _, _, _, _} ->
      franz_ffi:convert_kafka_message(Msg);
    {kafka_message_set, Topic, Partition, HighWmOffset, Messages} ->
      franz_ffi:convert_message_set(Topic, Partition, HighWmOffset, Messages)
  end,
  case CbFun(ConvertedMsg, CbState0) of
    {ok, ack, CbState} ->
      {ok, ack, {CbFun, CbState}};
    {ok, commit, CbState} ->
      {ok, commit, {CbFun, CbState}};
    {ok, CbState} ->
      {ok, {CbFun, CbState}}
  end.
