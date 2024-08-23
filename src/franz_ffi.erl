-module(franz_ffi).

-export([start_client/2, start_producer/1, produce_sync_offset/4, produce_sync/4, start_consumer/1, subscribe/4]).

start_client(Endpoint, Port) ->
  case brod:start_client([{Endpoint, Port}]) of
    ok ->
      {ok, nil};
    {error, Error} ->
      {error, Error}
  end.

start_producer(TopicName) ->
  case brod:start_producer(brod_default_client, TopicName, []) of
    ok ->
      {ok, nil};
    {error, Error} ->
      {error, Error}
  end.

produce_sync_offset(TopicName, Partition, Key, Value) ->
  brod:produce_sync_offset(brod_default_client, TopicName, Partition, Key, Value).

produce_sync(TopicName, Partition, Key, Value) ->
  case brod:produce_sync(brod_default_client, TopicName, Partition, Key, Value) of
    ok ->
      {ok, nil};
    {error, Error} ->
      {error, Error}
  end.

start_consumer(Topic) -> 
  brod:start_consumer(brod_default_client, Topic, []).

subscribe(SubscriberPid, Topic, Partition, Options) ->
  brod:subscribe(brod_default_client, SubscriberPid, Topic, Partition, Options).
